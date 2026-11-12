#!/usr/bin/env bash
# Title bars say "Home — Dolphin" because Qt appends the app's display name. Ship a tiny English
# catalog ("en@mountain", used before en_US by the session script below) that renames only "Dolphin".
set -euo pipefail
src=$(find /usr/share/locale -path '*/LC_MESSAGES/dolphin.mo' -print -quit)
[[ -n $src ]] || { echo "explorer-title: no dolphin.mo to read the source strings from"; exit 1; }
out=/usr/share/locale/en@mountain/LC_MESSAGES/dolphin.mo
mkdir -p "${out%/*}"
python3 - "$src" "$out" <<'PY'
import gettext, struct, sys
keys = sorted(k for k in gettext.GNUTranslations(open(sys.argv[1], 'rb'))._catalog if isinstance(k, str) and k.split('\x04')[-1] == 'Dolphin')
assert keys, 'no "Dolphin" msgid in ' + sys.argv[1]
ids = [k.encode() for k in keys]; strs = [b'File Explorer'] * len(ids)
n = len(ids); o = 28 + 16 * n; tab_i, tab_s, data = [], [], b''
for b in ids: tab_i.append((len(b), o + len(data))); data += b + b'\0'
for b in strs: tab_s.append((len(b), o + len(data))); data += b + b'\0'
mo = struct.pack('<7I', 0x950412de, 0, n, 28, 28 + 8 * n, 0, o)
mo += b''.join(struct.pack('<2I', *t) for t in tab_i + tab_s) + data
open(sys.argv[2], 'wb').write(mo)
t = gettext.GNUTranslations(open(sys.argv[2], 'rb'))  # self-check: the file we wrote reads back
assert all(t._catalog[k] == 'File Explorer' for k in keys), 'catalog does not read back'
print('explorer-title:', len(keys), 'string(s):', [k.replace('\x04', ' | ') for k in keys])
PY
