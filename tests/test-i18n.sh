#!/usr/bin/env bash
# Mountain's own windows must speak Bulgarian (the owner's language) and stay English-identical in English.
# 1) tools/po2mo.py --check: every i18n() string in the org.mountain.* / menu plasmoids has a Bulgarian entry, no empty msgstr,
#    the committed .mo files match the .po files.
# 2) No visible English text in those QML files is left outside i18n(): a quoted text:/title:/label:... value with letters
#    is a failure unless it is on the allow-list below (file names, shell commands, proper names, key names).
# Pure bash + python3, runs on CI without the image.
set -uo pipefail
cd "$(dirname "$0")/.."
rc=0
python3 tools/po2mo.py --check || rc=1
python3 -I - <<'PY' || rc=1
import glob, re, sys
S = re.compile(r'"((?:[^"\\]|\\.)*)"')
KEY = re.compile(r'(?<![\w.])(text|title|subtitle|description|details|label|tech|placeholderText|toolTipMainText|toolTipSubText|Accessible\.name|Accessible\.description|displayText)\s*:')
# literal values that are not words for a person: access keys, symbols, product names that are not translated
ALLOW = re.compile(r'^(?:[^A-Za-z]*| to |ENG|HDR|VPN|Wi-Fi|Bluetooth|Ethernet|Steam|Paint|TPM|Mountain Silk|Mountain Peaks|PDF|OK)$')
bad = []
files = glob.glob('files/system/usr/share/plasma/plasmoids/org.mountain.*/**/*.qml', recursive=True)
for f in sorted(files):
    for n, line in enumerate(open(f, encoding='utf-8'), 1):
        if line.lstrip().startswith(('//', '*', '/*')):
            continue
        line = line.split(' // ')[0]
        # drop everything already inside i18n()/i18nc() calls first, then read each `key: value` up to its ; , } boundary
        line = re.sub(r'\bi18nc?\((?:[^()"]|"(?:[^"\\]|\\.)*"|\([^()]*\))*\)', '', line)
        for m in KEY.finditer(line):
            val = re.split(r';|\s\}|,\s*[A-Za-z.]+:\s', line[m.end():])[0]
            for s in S.findall(val):
                if re.search(r'[A-Za-z]{2}', s) and not ALLOW.match(s) and not re.search(r'[/$\\]|^[a-z0-9_.-]+$', s) and not s.startswith('#'):
                    bad.append(f'{f}:{n}: {m[1]}: "{s}"')
for b in bad:
    print('FAIL English text not in i18n():', b)
print(f'test-i18n: {len(files)} QML files checked,', 'FAIL' if bad else 'ok')
sys.exit(1 if bad else 0)
PY
exit $rc
