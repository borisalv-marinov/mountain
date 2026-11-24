#!/usr/bin/env python3
"""Self-test for uxcheck.py on drawn screenshots (needs tesseract and a TrueType font; skips without them)."""
import json, os, shutil, sys, tempfile
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import uxcheck

font = next((ImageFont.truetype(p, 18) for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "C:/Windows/Fonts/arial.ttf") if os.path.exists(p)), None)
if not font:
    print("SKIP: no TrueType font"); sys.exit(0)
has_ocr = bool(shutil.which("tesseract"))
d = tempfile.mkdtemp(); rc = 0


def shot(name, text, bg=(18, 18, 18), fg=(255, 255, 255)):
    im = Image.new("RGB", (640, 400), bg); dr = ImageDraw.Draw(im)
    for i, t in enumerate(text):
        dr.text((40, 40 + 40 * i), t, font=font, fill=fg)
    im.save(os.path.join(d, name + ".png"))


def expect(rule, name, want):
    global rc
    for f in os.listdir(d): os.remove(os.path.join(d, f))
    name()
    rows, fails = uxcheck.run(d, rule)
    ok = (fails > 0) == want
    print(("ok: " if ok else "FAIL: ") + str(rows)); rc |= not ok


if not has_ocr:
    print("SKIP: OCR checks (no tesseract)")
else:
  expect({"dialog-shutdown": {"must_read": ["Shut down"]}}, lambda: shot("01-dialog-shutdown", ["What do you want the computer to do?", "Shut down"]), False)
  expect({"dialog-shutdown": {"must_read": ["Shut down"]}}, lambda: shot("01-dialog-shutdown", ["What do you want the computer to do?", ""]), True)
  expect({"file-explorer": {"must_not_read": ["0 B free"]}}, lambda: shot("02-file-explorer", ["11 folders", "0 B free"]), True)
  expect({"file-explorer": {"must_not_read": ["0 B free"]}}, lambda: shot("02-file-explorer", ["11 folders", "41.2 GB free"]), False)
  expect({"_must_not_read_everywhere": ["Traceback", "Permission denied"]}, lambda: shot("04-anything", ["Settings", "Permission denied"]), True)
  expect({"_must_not_read_everywhere": ["Traceback", "Permission denied"]}, lambda: shot("04-anything", ["Settings", "All is well"]), False)


def app(bg):
    shot("03-every-x", ["Title"], bg=bg, fg=(0, 0, 0) if bg[0] > 128 else (255, 255, 255))
    json.dump({"geom": [100, 50, 400, 300], "class": "x"}, open(os.path.join(d, "03-every-x.json"), "w"))


expect({"every-.*": {"dark_window": True}}, lambda: app((18, 18, 18)), False)
expect({"every-.*": {"dark_window": True}}, lambda: app((245, 245, 245)), True)
# a sleeping screen (all black) must fail, not pass as "dark"
expect({"every-.*": {"dark_window": True}}, lambda: (app((18, 18, 18)), Image.new("RGB", (1280, 800)).save(os.path.join(d, "03-every-x.png"))), True)
# GTK apps: libadwaita grey (#2d) is too light, Mountain dark (#121212) passes
expect({"every-.*": {"dark_window": 0.12}}, lambda: app((45, 45, 45)), True)
expect({"every-.*": {"dark_window": 0.12}}, lambda: app((18, 18, 18)), False)
# the shipped rules: a cloud-gaming web app shows the vendor's site (white when its CSS fails to load in CI), so only Mountain's own apps are judged dark
import re
real = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "ux-rules.json"), encoding="utf-8"))
dark = [p for p, c in real.items() if not p.startswith("_") and c.get("dark_window")]
for name, want in [("every-mountain-xboxcloud", False), ("every-mountain-geforcenow", False), ("every-mountain-boosteroid", False),
                   ("every-com.brave.Browser", False), ("every-org.kde.dolphin", True), ("every-mountain-python", True)]:
    got = any(re.fullmatch(p, name) for p in dark)
    if got != want: print("FAIL: dark_window rule for %s: %s, want %s" % (name, got, want)); rc = 1
shutil.rmtree(d); sys.exit(rc)
