#!/usr/bin/env python3
"""User-view checks on vm-test screenshots: read the screen like a person (OCR) and look at window colours.

uxcheck.py SHOTS_DIR RULES_JSON  -> one markdown report row per check on stdout; exit 1 if any FAIL.
Needs Pillow and the tesseract command.
"""
import difflib, json, os, re, subprocess, sys, tempfile
from PIL import Image, ImageOps


def ocr(img, tsv=False):
    g = ImageOps.grayscale(img)
    if sum(g.resize((64, 64)).getdata()) / 4096 < 128:  # light text on dark UI: tesseract reads dark on light best
        g = ImageOps.invert(g)
    g = g.resize((g.width * 2, g.height * 2), Image.LANCZOS)
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        g.save(f.name)
    try:
        out = subprocess.run(["tesseract", f.name, "stdout", "--psm", "11"] + (["tsv"] if tsv else []),
                             capture_output=True, text=True, timeout=120).stdout
    finally:
        os.unlink(f.name)
    return out


def norm(s):
    return re.sub(r"\s+", " ", s.lower()).strip()


def found(text, phrase, need):
    """phrase in text, allowing OCR slips: best window of the same length scores >= need (0..1)"""
    t, p = norm(text), norm(phrase)
    if p in t or p.replace(" ", "") in t.replace(" ", ""):  # OCR drops spaces: "0 B free" reads "0b free"
        return True
    n = len(p)
    return any(difflib.SequenceMatcher(None, t[i:i + n], p).ratio() >= need for i in range(0, max(1, len(t) - n + 1)))


def luminance(img):
    g = ImageOps.grayscale(img)
    v = sorted(g.getdata())
    return v[len(v) // 2] / 255  # median: text and icons do not move it


def run(shots, rules):
    rows, fails = [], 0
    for f in sorted(os.listdir(shots)):
        if not f.endswith(".png"):
            continue
        name = re.sub(r"^\d+-", "", f[:-4])
        for pat, checks in rules.items():
            if pat.startswith("_") or not re.fullmatch(pat, name):
                continue
            img = Image.open(os.path.join(shots, f)).convert("RGB")
            text = None
            for phrase in checks.get("must_read", []):
                text = text if text is not None else ocr(img)
                ok = found(text, phrase, 0.85)
                rows.append(("reads '%s' on %s" % (phrase, name), "PASS" if ok else "FAIL", norm(text)[:70]))
                fails += not ok
            for phrase in checks.get("must_not_read", []):
                text = text if text is not None else ocr(img)
                bad = found(text, phrase, 0.9)
                rows.append(("no '%s' on %s" % (phrase, name), "FAIL" if bad else "PASS", norm(text)[:70]))
                fails += bad
            if checks.get("dark_window"):
                meta = os.path.join(shots, f[:-4] + ".json")
                geo = json.load(open(meta)).get("geom") if os.path.exists(meta) else None
                if not geo:
                    rows.append(("window is dark: %s" % name, "INFO", "no window geometry (app opened no window?)"))
                else:
                    x, y, w, h = geo
                    box = (max(0, x + 8), max(0, y + 40), min(img.width, x + w - 8), min(img.height, y + h - 8))
                    if box[2] - box[0] < 40 or box[3] - box[1] < 40:
                        rows.append(("window is dark: %s" % name, "INFO", "window too small %s" % geo))
                    else:
                        lum = luminance(img.crop(box))
                        ok = lum <= 0.30
                        rows.append(("window is dark: %s" % name, "PASS" if ok else "FAIL", "median luminance %.2f (<= 0.30) %s" % (lum, json.load(open(meta)).get("class", ""))))
                        fails += not ok
            if checks.get("ocr_quality"):
                words = [l.split("\t") for l in ocr(img, tsv=True).splitlines()[1:]]
                words = [(float(w[10]), w[11]) for w in words if len(w) > 11 and len(w[11].strip()) >= 3]
                low = sum(c < 40 for c, _ in words)
                rows.append(("readable text on %s" % name, "INFO", "%d words, %d unreadable" % (len(words), low)))
    return rows, fails


if __name__ == "__main__":
    rows, fails = run(sys.argv[1], json.load(open(sys.argv[2])))
    for check, result, ev in rows:
        print("| ux: %s | %s | `%s` |" % (check, result, ev.replace("|", "/").replace("`", "'")))
    sys.exit(1 if fails else 0)
