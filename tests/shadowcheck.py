import glob, re, sys
# Every theme SVG with shadow-* corners must have them sized to the shadow padding hints. Usage: shadowcheck.py THEME_DIR
n = 0
for f in glob.glob(sys.argv[1] + '/**/*.svg', recursive=True):
    s = open(f, encoding='utf-8').read()
    if 'shadow-topleft' not in s: continue
    g = lambda n: [float(v) for v in re.search(r'<g id="%s"><rect x="[\d.]+" y="[\d.]+" width="([\d.]+)" height="([\d.]+)"' % n, s).groups()]
    l, t, r, b = g('shadow-hint-left-margin')[0], g('shadow-hint-top-margin')[1], g('shadow-hint-right-margin')[0], g('shadow-hint-bottom-margin')[1]
    want = {'topleft': [l, t], 'topright': [r, t], 'bottomleft': [l, b], 'bottomright': [r, b]}
    for k, v in want.items():
        assert g('shadow-' + k) == v, (f, k, g('shadow-' + k), v)
    n += 1
assert n, 'no SVG with shadow corners under ' + sys.argv[1]
print('shadow corners match padding in', n, 'files')
