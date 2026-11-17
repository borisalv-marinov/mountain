#!/usr/bin/env bash
# File Explorer said "0 B free": on this boot layout (composefs root) the kernel's statmount() answers with an empty
# mount point, and KIO 6.32 (KMountPoint::currentMountPointForPath) trusts it, so Dolphin measures "/", the read-only
# system image. A tiny library, loaded only into Dolphin, makes statmount() look unsupported (ENOSYS): KIO then reads
# the mount table, which is right (VM probe: /var, 13 GB free). It takes itself out of the environment at once, so apps
# opened from File Explorer never get it. Drop this script once KIO no longer uses an empty statmount() mount point.
set -euo pipefail
real=/usr/libexec/mountain-dolphin/dolphin lib=/usr/lib64/mountain-nostatmount.so
[[ -x /usr/bin/dolphin ]] || { echo "explorer-free-space: /usr/bin/dolphin not found"; exit 1; }
src=$(mktemp -d)
cat > "$src/nostatmount.c" <<'C'
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdarg.h>
#include <stdlib.h>
#ifndef SYS_statmount
#define SYS_statmount 457 /* x86_64 */
#endif
__attribute__((constructor)) static void restore_env(void)
{
    const char *orig = getenv("MOUNTAIN_ORIG_LD_PRELOAD");
    if (orig && *orig) setenv("LD_PRELOAD", orig, 1); else unsetenv("LD_PRELOAD");
    unsetenv("MOUNTAIN_ORIG_LD_PRELOAD");
}
long syscall(long n, ...)
{
    static long (*real)(long, ...);
    va_list ap;
    va_start(ap, n);
    long a = va_arg(ap, long), b = va_arg(ap, long), c = va_arg(ap, long), d = va_arg(ap, long), e = va_arg(ap, long), f = va_arg(ap, long);
    va_end(ap);
    if (n == SYS_statmount) { errno = ENOSYS; return -1; }
    if (!real) real = (long (*)(long, ...))dlsym(RTLD_NEXT, "syscall");
    return real(n, a, b, c, d, e, f);
}
C
had_gcc=$(command -v gcc || true)
[[ -n $had_gcc ]] || dnf -y -q install --setopt=install_weak_deps=False gcc >/dev/null
gcc -O2 -Wall -Werror -shared -fPIC -o "$lib" "$src/nostatmount.c" -ldl
[[ -n $had_gcc ]] || dnf -y -q remove gcc >/dev/null
rm -rf "$src"; chmod 755 "$lib"
# the real binary keeps its name (process "dolphin"); /usr/bin/dolphin, which the menu, Open folder and D-Bus all start, loads the library
mkdir -p "${real%/*}"; mv /usr/bin/dolphin "$real"
cat > /usr/bin/dolphin <<SH
#!/bin/sh
# File Explorer with the free-space fix (see /usr/lib64/mountain-nostatmount.so, files/scripts/explorer-free-space.sh)
MOUNTAIN_ORIG_LD_PRELOAD=\${LD_PRELOAD:-} LD_PRELOAD=$lib\${LD_PRELOAD:+:\$LD_PRELOAD} exec $real "\$@"
SH
chmod 755 /usr/bin/dolphin
# self-check: the library answers ENOSYS for statmount and passes every other call through
python3 - "$lib" <<'PY'
import ctypes, sys
ctypes.CDLL('libc.so.6')
lib = ctypes.CDLL(sys.argv[1], use_errno=True)
assert lib.syscall(457, 0, 0, 0, 0) == -1 and ctypes.get_errno() == 38, 'statmount not refused'
assert lib.syscall(39) > 0, 'getpid did not pass through'
PY
echo "explorer-free-space: applied"
