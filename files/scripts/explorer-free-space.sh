#!/usr/bin/env bash
# File Explorer said "0 B free": Dolphin asks Solid for the drive under a folder, and on this boot layout the drive
# (the btrfs partition) answers with the mount point "/", the read-only system image (composefs), which always has
# 0 bytes free. Dolphin's file worker (a thread in Dolphin) then runs statvfs("/"). A tiny library, loaded only into
# Dolphin, answers statvfs() on that read-only image with the writable partition's numbers (/var: the same disk that
# holds home and apps), like Windows shows C:'s free space. It takes itself out of the environment at once, so apps
# opened from File Explorer never get it. Drop this script once Solid/Dolphin stop measuring "/" on an image-based root.
set -euo pipefail
real=/usr/libexec/mountain-dolphin/dolphin lib=/usr/lib64/mountain-freespace.so
[[ -x /usr/bin/dolphin ]] || { echo "explorer-free-space: /usr/bin/dolphin not found"; exit 1; }
src=$(mktemp -d)
cat > "$src/freespace.c" <<'C'
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdlib.h>
#include <sys/statvfs.h>
__attribute__((constructor)) static void restore_env(void)
{
    const char *orig = getenv("MOUNTAIN_ORIG_LD_PRELOAD");
    if (orig && *orig) setenv("LD_PRELOAD", orig, 1); else unsetenv("LD_PRELOAD");
    unsetenv("MOUNTAIN_ORIG_LD_PRELOAD");
}
typedef int (*statvfs_fn)(const char *, struct statvfs *);
/* a path on the read-only system image (same filesystem as "/", nothing free) reports the writable partition */
static int answer(statvfs_fn real, const char *path, struct statvfs *buf)
{
    int r = real(path, buf);
    struct statvfs root;
    if (r == 0 && buf->f_bavail == 0 && (buf->f_flag & ST_RDONLY) && real("/", &root) == 0 && root.f_fsid == buf->f_fsid) {
        struct statvfs var;
        if (real("/var", &var) == 0) *buf = var;
    }
    return r;
}
int statvfs(const char *path, struct statvfs *buf)
{
    static statvfs_fn real;
    if (!real) real = (statvfs_fn)dlsym(RTLD_NEXT, "statvfs");
    return answer(real, path, buf);
}
int statvfs64(const char *path, struct statvfs64 *buf) /* same layout as struct statvfs on x86_64 */
{
    static statvfs_fn real;
    if (!real) real = (statvfs_fn)dlsym(RTLD_NEXT, "statvfs64");
    return answer(real, path, (struct statvfs *)buf);
}
C
had_gcc=$(command -v gcc || true)
[[ -n $had_gcc ]] || dnf -y -q install --setopt=install_weak_deps=False gcc >/dev/null
gcc -O2 -Wall -Werror -shared -fPIC -o "$lib" "$src/freespace.c" -ldl
[[ -n $had_gcc ]] || dnf -y -q remove gcc >/dev/null
rm -rf "$src"; chmod 755 "$lib"
# the real binary keeps its name (process "dolphin"); /usr/bin/dolphin, which the menu, Open folder and D-Bus all start, loads the library
mkdir -p "${real%/*}"; mv /usr/bin/dolphin "$real"
cat > /usr/bin/dolphin <<SH
#!/bin/sh
# File Explorer with the free-space fix (see /usr/lib64/mountain-freespace.so, files/scripts/explorer-free-space.sh)
MOUNTAIN_ORIG_LD_PRELOAD=\${LD_PRELOAD:-} LD_PRELOAD=$lib\${LD_PRELOAD:+:\$LD_PRELOAD} exec $real "\$@"
SH
chmod 755 /usr/bin/dolphin
# self-check: statvfs on a writable folder passes through unchanged (the read-only image only exists on the booted system)
python3 - "$lib" <<'PY'
import ctypes, os, sys
lib = ctypes.CDLL(sys.argv[1], use_errno=True)
for name in ('statvfs', 'statvfs64'):
    buf = ctypes.create_string_buffer(256)
    assert getattr(lib, name)(b'/tmp', buf) == 0, name + ' failed'
    assert ctypes.c_ulong.from_buffer(buf, 16).value == os.statvfs('/tmp').f_blocks, name + ' changed a writable folder'
PY
echo "explorer-free-space: applied"
