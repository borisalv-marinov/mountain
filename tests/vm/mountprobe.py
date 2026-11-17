#!/usr/bin/env python3
"""File Explorer's free-space lookup, step by step (KIO 6.32 KMountPoint::currentMountPointForPath, x86_64):
statx(STATX_MNT_ID_UNIQUE) -> statmount(mount point) -> statvfs. Also the table fallback (statx of every mountinfo target)."""
import ctypes, os, struct, sys

libc = ctypes.CDLL(None, use_errno=True)
AT_FDCWD, AT_SYMLINK_NOFOLLOW, AT_NO_AUTOMOUNT, AT_STATX_DONT_SYNC = -100, 0x100, 0x800, 0x4000
STATX_MNT_ID_UNIQUE = 0x4000
SB_BASIC, MNT_BASIC, MNT_ROOT, MNT_POINT, FS_TYPE = 0x1, 0x2, 0x4, 0x8, 0x20


def statx(path, flags):
    buf = ctypes.create_string_buffer(256)
    if libc.syscall(332, AT_FDCWD, path.encode(), flags | AT_STATX_DONT_SYNC | AT_NO_AUTOMOUNT, STATX_MNT_ID_UNIQUE, buf):
        return None, os.strerror(ctypes.get_errno())
    mask, = struct.unpack_from('<I', buf, 0)
    mnt, = struct.unpack_from('<Q', buf, 144)
    return (mnt if mask & STATX_MNT_ID_UNIQUE else None), 'mask=%#x' % mask


def statmount(mid):
    req = struct.pack('<IIQQ', 24, 0, mid, SB_BASIC | MNT_BASIC | MNT_ROOT | MNT_POINT | FS_TYPE)
    buf = ctypes.create_string_buffer(8192)
    if libc.syscall(457, req, buf, 8192, 0):
        return 'statmount error: ' + os.strerror(ctypes.get_errno())
    raw = buf.raw
    mask, = struct.unpack_from('<Q', raw, 8)
    fs_type, = struct.unpack_from('<I', raw, 36)
    root, point = struct.unpack_from('<II', raw, 104)
    s = lambda off: raw[512 + off:raw.index(b'\0', 512 + off)].decode(errors='replace')
    return 'mask=%#x point=%r root=%r type=%r' % (mask, s(point), s(root), s(fs_type))


def free(p):
    try:
        v = os.statvfs(p)
        return 'total=%dMB avail=%dMB' % (v.f_blocks * v.f_frsize >> 20, v.f_bavail * v.f_frsize >> 20)
    except OSError as e:
        return str(e)


for path in sys.argv[1:] or [os.path.expanduser('~'), '/home/' + os.environ.get('USER', ''), '/var/home']:
    mid, note = statx(path, AT_SYMLINK_NOFOLLOW)
    print('%s: unique mount id=%s (%s) -> %s; statvfs here: %s' % (path, mid, note, statmount(mid) if mid else '-', free(path)))

# the table fallback: mountinfo targets newest first, each target's own unique id (KMountPoint::currentMountPoints)
targets = [l.split()[4] for l in open('/proc/self/mountinfo')]
for t in reversed(targets):
    t = t.encode().decode('unicode_escape')
    mid, _ = statx(t, 0)
    print('table %s id=%s %s' % (t, mid, free(t)))
