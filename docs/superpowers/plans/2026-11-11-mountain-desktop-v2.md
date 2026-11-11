# Mountain Desktop v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Use ponytail (lite) while implementing: smallest change that passes the task's check.

**Goal:** Make Mountain faster (especially on weak PCs and in Try Mountain), make it look like macOS with Windows-style controls (top bar + bottom taskbar), give every app a familiar icon, sort apps into folders, add AI coding agents, and make copy/paste work in Try Mountain.

**Architecture:** Everything ships as files and build scripts in the existing BlueBuild image (`recipes/common.yml`, `files/`). Each task adds its own `check_phase13..19` to `tests/check-image.sh` (run in CI by `build.yml`). Desktop results are checked by `vm-test.yml` screenshots. Try Mountain changes live in `.github/workflows/try-mountain.yml` and a new `try/` folder.

**Tech Stack:** BlueBuild, Bazzite stable (KDE Plasma 6, Fedora 45), Plasma layout.js, XDG menus, bash, QEMU + noVNC.

**Spec:** the owner's feedback after testing Try Mountain (2026-11-11), summarised in "Spec" below. Research notes: `C:\Users\marin\Desktop\Operating System\VM\cloud-test\research.md`. Speed measurements (when ready): `...\cloud-test\perf-findings.md`.

**Run order:** 1, 2, 4, 3, 5, 6, 7, 8 (Task 3's AI folder needs Task 4's launchers). Push Tasks 1–5 as one CI batch, 6–7 as a second, to save CI time.

## Spec (owner's words, condensed)

1. Desktop: macOS look, Windows feel. A **top bar showing system info** (CPU, RAM, network, tray, clock) and a **bottom taskbar showing everything** (start button with the Mountain logo, pinned + running apps). Window close/minimize/maximize buttons **on the right, like Windows**.
2. **Fast** on weak machines, including the slow Try Mountain cloud VM. Gaming-first, all drivers (Bazzite already provides them).
3. **Copy/paste must work** in Try Mountain.
4. Icons: GeForce NOW, Xbox Cloud Gaming and Boosteroid use their normal app icons where one is already installed on the system; otherwise draw one. Draw folder icons that don't exist. Draw a **Mountain logo: two mountains, one in front of the other**, white/black with some colour.
5. **App folders** (start menu and desktop): Cloud Gaming, Games, Game Launchers, Browsers, Coding, AI, Office, Chat. All apps installed.
6. **AI agents** (Claude Code, Codex, Gemini CLI, GitHub Copilot CLI): installed the first time they are clicked.
7. Steam: login is remembered on a real install (no work); make first start as fast as possible.
8. System Settings and icons should feel familiar to Windows users.
9. Keep: Bazzite Portal, Bazaar, Konsole (do not remove).

## Global Constraints

- Base image: Bazzite **stable** only. Never `testing`/`unstable` tags.
- Packages: Fedora repos (dnf) or Flathub only. No downloading third-party themes/binaries at build time.
- Brand logos: never draw or copy them. Use icons already installed by Fedora packages (Papirus) or draw original ones.
- Idle RAM target with desktop open: **≤ 1.5 GB** (`free -m` "used"). Last measured: 1744 MB.
- Never remove accessibility (Orca autostart stays).
- Do not remove Bazzite Portal, Bazaar or Konsole.
- Never push to `main`; work on `mountain-phases`, the owner merges.
- One CI check per pushed batch; check CI at most every 10 minutes; never `gh run watch`; on failure read `gh run view <id> --log-failed | tail -80`; max 2 fix attempts per failure.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `MOUNTAIN_PHASE` in `.github/workflows/build.yml` is bumped to the highest phase that exists.

## Review Focus

1. **Plasma panel script silently failing** (KDE bug 512005: `addWidget` in layout templates after Plasma 6.5) → empty or missing panels. Expect: both panels visible in vm-test `desk1.png`. Pinned by Task 5 Step 5 (screenshot review) and the plasmoid-exists checks.
2. **Lite mode switching off effects on a real GPU** (false positive) → a gamer loses the glass look. Expect: only `llvmpipe`/`softpipe`/`swrast` renderers or < 4 GB RAM trigger it. Pinned by Task 1's `test-lite-mode.sh` cases.
3. **AI agent clicked with no internet** → half-installed tool. Expect: clear message "No internet — connect and click again", nothing left behind, window stays open. Pinned by Task 4's offline test.
4. **Pasting non-English text** (ä, ö, €, emoji, newlines) in Try Mountain → wrong characters. Expect: Latin-1 and Unicode typed correctly, `\n` becomes Enter. Pinned by Task 7's `keysym.test.mjs`.
5. **Existing users don't get the new layout** (layout.js only runs for new users). Expect: documented in `docs/TESTING.md`; fresh users (Try Mountain, new installs) get it. Pinned by Task 5 Step 6 note.

---

### Task 1: Speed pack (all PCs) + Lite mode (weak PCs)

**Files:**
- Create: `files/system/etc/xdg/baloofilerc`
- Create: `files/system/etc/xdg/autostart/org.kde.kdeconnect.daemon.desktop`, `geoclue-demo-agent.desktop`, `org.kde.kunifiedpush-distributor.desktop` (each: `[Desktop Entry]`, `Hidden=true`)
- Create: `files/system/usr/libexec/mountain-lite-mode`
- Create: `files/system/etc/xdg/autostart/mountain-lite-mode.desktop`
- Create: `tests/test-lite-mode.sh`
- Modify: `tests/check-image.sh` (add `check_phase13`), `.github/workflows/build.yml` (run `bash tests/test-lite-mode.sh` in the lint job)

**Interfaces:**
- Produces: `mountain-lite-mode [--dry-run]`; env overrides for tests: `MOUNTAIN_RENDERER` (renderer string instead of running `eglinfo -B`), `MOUNTAIN_MEM_KB` (instead of `/proc/meminfo` MemTotal). Prints `lite: on (<reason>)` or `lite: off`.

- [ ] **Step 1: Write the failing test** `tests/test-lite-mode.sh` with cases (each runs `MOUNTAIN_RENDERER=... MOUNTAIN_MEM_KB=... files/system/usr/libexec/mountain-lite-mode --dry-run` and greps):
  - `llvmpipe (LLVM 19.1, 256 bits)`, 16000000 → `lite: on (software rendering)`
  - `AMD Radeon Graphics (radeonsi, renoir)`, 16000000 → `lite: off`
  - `NVIDIA GeForce RTX 3060`, 3500000 → `lite: on (low memory)`
  - `Mesa Intel(R) UHD Graphics 620`, 8000000 → `lite: off`
  - empty renderer (eglinfo missing), 8000000 → `lite: off`
- [ ] **Step 2: Run** `bash tests/test-lite-mode.sh` → FAIL (script missing).
- [ ] **Step 3: Implement** `mountain-lite-mode`: renderer matches `llvmpipe|softpipe|swrast` (case-insensitive) → software rendering; MemTotal < 4194304 kB → low memory. When on and not `--dry-run`: `kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false`, same for `contrastEnabled`, `kwriteconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor 0`, then `qdbus6 org.kde.KWin /KWin reconfigure || true`. Writes only to the user's `~/.config`. The autostart `.desktop` runs it once per login (`X-KDE-autostart-phase=1`).
- [ ] **Step 4: Run** `bash tests/test-lite-mode.sh` → all PASS.
- [ ] **Step 5:** `/etc/xdg/baloofilerc`:
  ```
  [Basic Settings]
  Indexing-Enabled=false
  ```
  `check_phase13`: assert the 3 Hidden autostart files contain `Hidden=true`, `baloofilerc` has `Indexing-Enabled=false`, `mountain-lite-mode` is executable, `command -v eglinfo` (if missing, add package `egl-utils` to `recipes/common.yml` dnf list).
- [ ] **Step 6: Commit** `feat: speed pack (no indexer/kdeconnect/geoclue at login) + lite mode for weak PCs`.

### Task 2: Mountain logo, Boosteroid icon, folder icons

**Files:**
- Create: `files/system/usr/share/icons/hicolor/scalable/apps/mountain-logo.svg`
- Create: `files/system/usr/share/icons/hicolor/scalable/apps/mountain-boosteroid.svg`
- Create: `files/system/usr/share/icons/hicolor/scalable/places/mountain-folder-{cloudgaming,games,launchers,browsers,coding,ai,office,chat}.svg`
- Modify: `files/system/usr/share/applications/mountain-{geforcenow,xboxcloud,boosteroid}.desktop`, matching `files/system/etc/skel/Desktop/*.desktop`
- Modify: `tests/check-image.sh` (`check_phase14`), `recipes/common.yml` (add `libxml2` only if `xmllint` is missing)

**Interfaces:**
- Produces icon names: `mountain-logo`, `mountain-boosteroid`, `mountain-folder-<name>` (names above). Used by Tasks 3, 5.

- [ ] **Step 1: Write `check_phase14`** first: for each SVG `xmllint --noout <file>`; for every `.desktop` under `/usr/share/applications/mountain-*` and `/etc/skel/Desktop/**`, resolve `Icon=`: absolute path must exist, otherwise a file named `<icon>.svg|png` must exist under `/usr/share/icons/{hicolor,Papirus,Papirus-Dark}` or `/var/lib/flatpak/exports/share/icons` (skip flatpak IDs, which arrive at first boot: names starting with `com.`/`org.`/`dev.`/`io.`).
- [ ] **Step 2:** push later with Task 3 (CI is the runner). Locally run `bash -n tests/check-image.sh`.
- [ ] **Step 3: Draw `mountain-logo.svg`** (viewBox 0 0 128 128, original art): rounded square background `#0f172a`; back mountain triangle (x 8–92, peak at 50,30) in `#475569`; front mountain (x 36–120, peak at 82,22) in white→`#cbd5e1` vertical gradient; front snowcap accent `#38bdf8` stripe below the peak. No text.
- [ ] **Step 4: Draw `mountain-boosteroid.svg`**: original, not the brand mark: rounded square `#ff6a00` → `#ff9a3c` gradient, white rocket/arrow shape pointing up-right. Folder icons: one shared rounded-folder shape (`#334155` body, `#475569` tab) with a white glyph per folder (cloud, gamepad, rocket, globe, `</>`, sparkle, document, speech bubble).
- [ ] **Step 5: Icons in launchers:** GeForce NOW `Icon=/usr/share/icons/Papirus/64x64/apps/geforcenow.svg`; Xbox Cloud `Icon=/usr/share/icons/Papirus/64x64/apps/xbox.svg`; Boosteroid `Icon=mountain-boosteroid`. (Absolute Papirus paths keep working if the icon theme changes in Task 6. Verify both files exist in the image in CI; if a path differs, use the path `find /usr/share/icons/Papirus -name geforcenow.svg | head -1` prints.)
- [ ] **Step 6: Commit** `feat: Mountain logo, Boosteroid and folder icons, real icons for cloud gaming launchers`.

### Task 3: App folders (start menu + desktop)

**Files:**
- Create: `files/system/etc/xdg/menus/applications-merged/mountain.menu`
- Create: `files/system/usr/share/desktop-directories/mountain-<name>.directory` (8 files, `Icon=mountain-folder-<name>`)
- Modify: move `files/system/etc/skel/Desktop/*.desktop` into `files/system/etc/skel/Desktop/<Folder Name>/` subfolders; each subfolder gets a `.directory` file with `[Desktop Entry]` `Icon=mountain-folder-<name>`
- Modify: `tests/check-image.sh` (`check_phase15`)

**Interfaces:**
- Consumes: icon names from Task 2. Launcher names from Task 4 (`mountain-ai-*.desktop`).
- Produces: folder → apps map (single source of truth, used by menu and desktop):
  - Cloud Gaming: `mountain-geforcenow`, `mountain-xboxcloud`, `mountain-boosteroid`
  - Games: `steam`
  - Game Launchers: `com.heroicgameslauncher.hgl`, `steam`
  - Browsers: `org.mozilla.firefox`, `com.microsoft.Edge`
  - Coding: `code`, `org.kde.konsole`, Projects folder link
  - AI: `mountain-ai-claude`, `mountain-ai-codex`, `mountain-ai-gemini`, `mountain-ai-copilot`
  - Office: `org.onlyoffice.desktopeditors`
  - Chat: `com.discordapp.Discord`, `dev.vencord.Vesktop`
  - Top level of the desktop (not in a folder): Files (`org.kde.dolphin`), Projects.

- [ ] **Step 1: Write `check_phase15`**: `xmllint --noout` the menu; each of the 8 `.directory` files exists; each Desktop subfolder exists and contains ≥ 1 `.desktop`; every `.desktop` in skel is executable (`-x`).
- [ ] **Step 2:** `mountain.menu`: one `<Menu><Name>…</Name><Directory>mountain-<name>.directory</Directory><Include><Filename>…desktop</Filename>…</Include></Menu>` per folder, inside `<Menu><Name>Applications</Name>`; use `<Filename>` (works for Flatpak .desktop files we can't edit).
- [ ] **Step 3: Desktop subfolders**: names exactly `Cloud Gaming`, `Games`, `Game Launchers`, `Browsers`, `Coding`, `AI`, `Office`, `Chat`. Flatpak apps get a small launcher (`Exec=flatpak run <id>`, `Icon=<id>`).
- [ ] **Step 4: Commit** `feat: app folders in start menu and on the desktop`.

### Task 4: AI agents, installed on first click

**Files:**
- Create: `files/system/usr/libexec/mountain-ai`
- Create: `files/system/usr/share/applications/mountain-ai-{claude,codex,gemini,copilot}.desktop` (`Exec=konsole --hold -e /usr/libexec/mountain-ai <name>`, `Icon=mountain-folder-ai`, `Categories=Development;`)
- Create: `tests/test-mountain-ai.sh`
- Modify: `recipes/common.yml` (dnf: `nodejs`, `npm`), `tests/check-image.sh` (`check_phase16`), `.github/workflows/build.yml` lint job runs the test

**Interfaces:**
- Produces: `mountain-ai <claude|codex|gemini|copilot>`. Env for tests: `MOUNTAIN_AI_DRYRUN=1` (print the install command instead of running it), `MOUNTAIN_AI_OFFLINE=1` (pretend no network).
- Install commands (per user, no root):
  - claude → `curl -fsSL https://claude.ai/install.sh | bash` (installs to `~/.local/bin/claude`)
  - codex → `npm install -g --prefix "$HOME/.local" @openai/codex`
  - gemini → `npm install -g --prefix "$HOME/.local" @google/gemini-cli`
  - copilot → `npm install -g --prefix "$HOME/.local" @github/copilot`
  - Commands after install: `claude`, `codex`, `gemini`, `copilot` in `~/.local/bin`.

- [ ] **Step 1: Write the failing test** `tests/test-mountain-ai.sh` (PATH stripped of the tools, HOME=temp dir):
  - `MOUNTAIN_AI_DRYRUN=1 mountain-ai codex` prints `npm install -g --prefix` and `@openai/codex`
  - `MOUNTAIN_AI_DRYRUN=1 mountain-ai claude` prints `https://claude.ai/install.sh`
  - with a fake `codex` script on PATH, `mountain-ai codex` runs it (prints its marker), no install
  - `MOUNTAIN_AI_OFFLINE=1 mountain-ai gemini` exits 1, prints `No internet — connect and click again`, creates nothing in `$HOME/.local`
  - `mountain-ai unknown` exits 2 with usage
- [ ] **Step 2: Run** `bash tests/test-mountain-ai.sh` → FAIL.
- [ ] **Step 3: Implement** `mountain-ai`: put `$HOME/.local/bin` first in PATH; if the command exists → `exec` it; else check network (`curl -sfI https://registry.npmjs.org >/dev/null`, or the OFFLINE override) → install → `exec` the command. Echo one plain line before installing: `Installing <Name> (first time only)…`.
- [ ] **Step 4: Run** the test → PASS. `check_phase16`: `command -v node npm konsole`, the 4 launchers exist, `mountain-ai` executable.
- [ ] **Step 5: Commit** `feat: AI agents (Claude Code, Codex, Gemini, Copilot) install on first click`.

### Task 5: Top bar (system info) + bottom taskbar, Windows controls

**Files:**
- Modify: `files/system/usr/share/plasma/look-and-feel/org.mountain.desktop/contents/layouts/org.kde.plasma.desktop-layout.js`
- Modify: `recipes/common.yml` (dnf: `appmenu-gtk3-module` if `dnf info` finds it in Fedora 45; skip otherwise)
- Modify: `tests/check-image.sh` (`check_phase17`)

**Interfaces:**
- Consumes: `mountain-logo` (Task 2).
- Produces: panel layout. Top panel: `location="top"`, `lengthMode="fill"`, `floating=false`, `opacity="translucent"`, height `Math.round(gridUnit * 1.6)`. Widgets left→right: `org.kde.plasma.appmenu`, `org.kde.plasma.panelspacer`, `org.kde.plasma.windowtitle` (skip if not installed), `org.kde.plasma.panelspacer`, system monitor CPU, memory, network (use the IDs present in `/usr/share/plasma/plasmoids/` matching `org.kde.plasma.systemmonitor.*`), `org.kde.plasma.systemtray`, `org.kde.plasma.digitalclock`. Bottom panel: today's dock minus tray/clock; kickoff first with `icon=mountain-logo` (config group `General`, key `icon`); then `org.kde.plasma.icontasks` (same pins + `org.kde.konsole.desktop`); then `org.kde.plasma.trash` if installed.

- [ ] **Step 1: Write `check_phase17`**: for every plugin ID used in the layout file (grep `addWidget("...")`), assert `/usr/share/plasma/plasmoids/<id>` exists. Also `ButtonsOnRight=IAX` in `/etc/xdg/kwinrc`.
- [ ] **Step 2:** edit layout.js as above; keep the wallpaper loop.
- [ ] **Step 3: Windows-like System Settings:** `files/system/etc/xdg/systemsettingsrc` `[Main] ActiveView=systemsettings_sidebar_mode`; `kdeglobals` `[KDE] SingleClick=false` (double-click to open, like Windows).
- [ ] **Step 4: Commit + push Tasks 1–5 as one batch.** Check CI once (every 10 min max).
- [ ] **Step 5: Screenshot review:** wait for vm-test, download `vm-test-report`; `desk1.png` must show a top bar with CPU/RAM/network + clock and a bottom taskbar with the Mountain logo; desktop shows the 8 folders. If panels are missing (Review Focus 1), switch to applying the layout via `plasma-apply-lookandfeel` in a first-login autostart, max 2 attempts.
- [ ] **Step 6:** add to `docs/TESTING.md` Notes: "New layout applies to new users; existing users: System Settings → Global Theme → Mountain → apply with 'Desktop and window layout' ticked."

### Task 6: Windows-familiar icon theme

**Files:**
- Modify: `recipes/common.yml` (dnf: the We10X package — name from `dnf search we10x` in the build log; Fedora page lists `We10X-icon-theme`)
- Modify: `files/system/etc/xdg/kdeglobals` `[Icons] Theme=We10X-dark` (use the exact dark theme dir name in `/usr/share/icons/`)
- Modify: `tests/check-image.sh` (`check_phase18`: theme dir exists and contains `index.theme`)

- [ ] **Step 1:** If the package is not in Fedora 45 repos, keep Papirus-Dark, note it in TESTING.md and stop this task (constraint: no third-party downloads).
- [ ] **Step 2: Commit** `feat: Windows-like icon theme`.

### Task 7: Try Mountain — faster + copy/paste

**Files:**
- Modify: `.github/workflows/try-mountain.yml`
- Create: `try/mountain.html`, `try/keysym.mjs`, `try/keysym.test.mjs`
- Modify: `docs/TRY-MOUNTAIN.md`

**Interfaces:**
- Produces: `charToKeysym(ch: string) -> number` in `try/keysym.mjs`: `\n` → `0xff0d`, `\t` → `0xff09`, code points 0x20–0x7e and 0xa0–0xff → the code point, others → `0x01000000 + codePoint`.
- Link posted: `<tunnel>/mountain.html` (status context "Mountain link", unchanged).

- [ ] **Step 1: Write the failing test** `try/keysym.test.mjs` (node, `assert`): `a`→0x61, `A`→0x41, `\n`→0xff0d, `ä`→0xe4, `€`→0x010020ac, `😀`→0x0101f600 (iterate by code point, not UTF-16 unit).
- [ ] **Step 2: Run** `node try/keysym.test.mjs` → FAIL. Add it to `build.yml` lint job.
- [ ] **Step 3: Implement** `charToKeysym`; run the test → PASS.
- [ ] **Step 4: `mountain.html`**: full-screen noVNC canvas using noVNC's `core/rfb.js` (module from the same folder), password prompt via `credentialsrequired` event, `scaleViewport=true`, `qualityLevel=6`, `compressionLevel=2`; a small "Paste" button (top-right, translucent) opening a textbox; on send: `rfb.clipboardPasteFrom(text)` (real clipboard via vdagent) **and** type it with `rfb.sendKey(charToKeysym(ch))` per code point (guaranteed path). Guest → you: show text from the `clipboard` event in the same box with a Copy button.
- [ ] **Step 5: Workflow:** copy `/usr/share/novnc` to `$HOME/web`, add `try/*.mjs|html`, serve `$HOME/web` with websockify. QEMU: add `-chardev qemu-vdagent,id=vdagent,name=vdagent,clipboard=on -device virtio-serial-pci -device virtserialport,chardev=vdagent,name=com.redhat.spice.0`; `-smp $(nproc)`; `-m 10240`. Derived image: ensure `spice-vdagent` (rpm -q; already in Bazzite) and enable `spice-vdagentd`.
- [ ] **Step 6: Ready signal:** derived image adds `mountain-try-ready.service` (After=graphical.target) running a loop (max 25 min) until `flatpak list --app` has all 6 default apps, then `echo MOUNTAIN-READY > /dev/ttyS0`. Workflow adds `-serial file:serial.log` (already) and waits for `MOUNTAIN-READY` in `serial.log` (max 25 min, then post anyway) before posting the link — so the owner never opens a half-ready, slow desktop.
- [ ] **Step 7: Commit + push**, dispatch on the branch is impossible (workflow_dispatch needs main): verify by opening a PR; owner merges; run once; open the link in the built-in browser and confirm the page and password prompt load.

### Task 8: Final check and hand-over

- [ ] **Step 1:** All CI green on `mountain-phases`; vm-test report: 0 FAIL, RAM used (desktop) ≤ 1500 MB (if above, list the top 5 RAM users from `perf/*.txt` and hide any that are unnecessary, one more round max).
- [ ] **Step 2:** Review screenshots (desk1–3) against the Spec list; tick items in `docs/TESTING.md` Progress.
- [ ] **Step 3:** PR to main, owner merges, start Try Mountain, open the link, give it to the owner.

## Not in this plan (and why)

- Steam login inside Try Mountain: every run is a fresh VM; storing Steam logins in a public repo is unsafe. On a real install Steam remembers the login.
- Steam first-start update (~300 MB): downloaded into the user's home by Steam itself; cannot be pre-baked into the image.
- Drivers: Bazzite already ships gaming drivers (Mesa, NVIDIA image variant, Wi-Fi firmware); no work.
