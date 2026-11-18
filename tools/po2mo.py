#!/usr/bin/env python3
"""Compile Mountain's translations: i18n/<lang>/<pluginId>.po  ->  <plasmoid>/contents/locale/<lang>/LC_MESSAGES/plasma_applet_<pluginId>.mo

Plasma (libplasma PluginLoader + KPackage "translations" = contents/locale) reads exactly that path and domain name.
No gettext in the build, so this is a tiny msgfmt. Run it after editing a .po, commit both files.
  tools/po2mo.py            write the .mo files
  tools/po2mo.py --check    fail if a .mo is stale, a .po has an empty msgstr, or a QML i18n() string has no entry (CI: tests/test-i18n.sh)
Pure Python 3, no dependencies."""
import glob, os, re, struct, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLASMOIDS = os.path.join(ROOT, 'files/system/usr/share/plasma/plasmoids')
STR = r'"((?:[^"\\]|\\.)*)"'


def unq(s):  # PO / QML string escapes -> text
    return re.sub(r'\\(.)', lambda m: {'n': '\n', 't': '\t'}.get(m[1], m[1]), s)


def q(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\t', '\\t') + '"'


def parse_po(path):
    """-> {(msgctxt or None, msgid): msgstr}, [(line, msgid)] of entries with an empty msgstr"""
    cat, empty, cur, field = {}, [], {}, None

    def flush():
        if 'msgid' in cur:
            key = (cur.get('msgctxt'), cur['msgid'])
            cat[key] = cur.get('msgstr', '')
            if key[1] and not cat[key]:
                empty.append(key[1])
        cur.clear()
    for line in open(path, encoding='utf-8').read().split('\n'):
        line = line.strip()
        if line.startswith('#') or not line:
            if not line:
                flush()
            continue
        m = re.match(r'(msgctxt|msgid|msgstr)\s+' + STR + '$', line)
        if m:
            if m[1] == 'msgctxt' and 'msgid' in cur:
                flush()
            field = m[1]; cur[field] = unq(m[2])
        else:
            m = re.match(STR + '$', line)
            assert m and field, f'{path}: cannot parse: {line}'
            cur[field] += unq(m[1])
    flush()
    return cat, empty


def write_mo(cat, out):
    cat = dict(cat)
    cat[(None, '')] = 'Content-Type: text/plain; charset=UTF-8\nLanguage: bg\nPlural-Forms: nplurals=2; plural=(n != 1);\n'
    items = sorted(((c + '\x04' + i if c else i).encode(), s.encode()) for (c, i), s in cat.items() if s or not i)
    n = len(items); o = 28 + 16 * n; ti, ts, data = [], [], b''
    for k, _ in items:
        ti.append((len(k), o + len(data))); data += k + b'\0'
    for _, v in items:
        ts.append((len(v), o + len(data))); data += v + b'\0'
    mo = struct.pack('<7I', 0x950412de, 0, n, 28, 28 + 8 * n, 0, o)
    mo += b''.join(struct.pack('<2I', *t) for t in ti + ts) + data
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, 'wb').write(mo)
    return mo


def read_mo(path):
    d = open(path, 'rb').read()
    n, ot, tt = struct.unpack('<3I', d[8:20])
    out = {}
    for i in range(n):
        l, off = struct.unpack('<2I', d[ot + 8 * i:ot + 8 * i + 8]); k = d[off:off + l].decode()
        l, off = struct.unpack('<2I', d[tt + 8 * i:tt + 8 * i + 8]); out[k] = d[off:off + l].decode()
    return out


def qml_msgids(plasmoid_dir):
    """{(ctxt|None, msgid)} from i18n("...") and i18nc("ctx", "...") calls in the plasmoid's QML"""
    ids = set()
    for f in glob.glob(plasmoid_dir + '/**/*.qml', recursive=True):
        t = open(f, encoding='utf-8').read()
        for m in re.finditer(r'\bi18n\(\s*' + STR, t):
            ids.add((None, unq(m[1])))
        for m in re.finditer(r'\bi18nc\(\s*' + STR + r'\s*,\s*' + STR, t):
            ids.add((unq(m[1]), unq(m[2])))
    return ids


def main():
    check = '--check' in sys.argv
    bad = 0
    for po in sorted(glob.glob(os.path.join(ROOT, 'i18n/*/*.po'))):
        lang, pid = os.path.basename(os.path.dirname(po)), os.path.basename(po)[:-3]
        pdir = os.path.join(PLASMOIDS, pid)
        out = os.path.join(pdir, 'contents/locale', lang, 'LC_MESSAGES', f'plasma_applet_{pid}.mo')
        cat, empty = parse_po(po)
        if empty:
            print(f'FAIL {po}: {len(empty)} empty msgstr, e.g. {empty[0]!r}'); bad += 1
        if check:
            missing = sorted(i for c, i in qml_msgids(pdir) if (c, i) not in cat)
            if missing:
                print(f'FAIL {pid}: {len(missing)} QML string(s) not in {lang}.po, e.g. {missing[0]!r}'); bad += 1
            want = {(c + '\x04' + i if c else i): s for (c, i), s in cat.items() if i}
            have = {k: v for k, v in read_mo(out).items() if k} if os.path.exists(out) else None
            if have != want:
                print(f'FAIL {out}: missing or stale, run tools/po2mo.py'); bad += 1
        else:
            write_mo(cat, out)
            print(f'{lang}/{pid}: {len(cat)} strings')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
