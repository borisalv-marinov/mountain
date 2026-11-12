# Mountain v5 (extended): "Black glass, better than Windows" master prompt

**Owner's ruling (2026-11-12): all of this is part of v5, not a later round.** Work on branch `mountain-v5`.
- It already holds the v5 fixes: drag-icon backport, login-screen picture, "File Explorer" title, cloud gaming in X11 mode, phase 27.
- Its image build passed. Its VM test (run 43223461715) may still be running: read its report first and fix anything red.
- **Do not merge v5** until every item below is built, tested in vm-test with screenshots, reviewed and green. Then open the v5 PR and merge it.

**The owner's aim:** a Linux that looks and feels like a **better OS than Windows**, while staying familiar to Windows people. (The owner wrote "unfamiliar" below and meant "familiar".) Think as big as possible, and install or load whatever skills help: UI design, QA, accessibility, testing.

Use superpowers: brainstorming, then writing-plans, then subagent-driven-development, then verification-before-completion. Use ponytail full: the smallest change that fully works, and name what you skipped.

Use the design skills for every visual piece: frontend-design, design-critique and accessibility-review (contrast).

Model choice:
- Cheap subagent models for tasks whose full code is in the plan.
- Mid-tier for reviews.
- The most capable model for the visual-design tasks and the final review.

Do not stop to ask between tasks. Make rulings and log them. The owner is non-technical. Always show the live task list and a status table (⏳ working, 🕓 waiting, ✅ done, 🔍 reviewing, 🔧 fixing, ☁️ cloud). Keep messages short and plain.

## Goal

Keep Mountain's current layout and give it a **glossy black-glass look**: futuristic, cool, premium. It should feel incredibly good to use and be **snappy everywhere**. Two more must-haves:
- **When Mountain starts, it must show a proper Windows 11-style lock screen.**
- The desktop must look close to the owner's own Windows desktop.

## Where things are (read before planning)

- **Repo:** `C:\Users\marin\Desktop\mountain`. Branch `mountain-v5` (see the top).
  - BlueBuild on Bazzite stable, KDE Plasma 6.8, Fedora 45.
  - Recipe: `recipes/common.yml`.
  - Files: `files/system/...`.
  - Build scripts: `files/scripts/*.sh`.
- **Checks:** `tests/check-image.sh` uses cumulative phases (v5 ends at `MOUNTAIN_PHASE=27`). Add new phases and never weaken old ones.
- **CI:**
  - `build.yml`: build and image checks.
  - `vm-test.yml`: QEMU real-use test with screenshots. It has the `QM` helper (`key`, `type`, `click`, `dclick`, `drag`, `hold`/`up`) and a KWin-script window probe (`console.warn("WIN|…")` read from the journal). Pass `-f tag=latest` to test main's image without building.
  - `try-mountain.yml`: the owner's browser desktop through noVNC and cloudflared.
- **Plans so far:** `docs/superpowers/plans/2026-11-11-mountain-v3-windows-polish.md` and `2026-11-12-mountain-v4.md`. v5 is in the git log.
  - v5 added: KDE drag-icon fix backport (`desktop-drag-fix.sh`), login-screen picture (`mountain-avatars`), "File Explorer" title (`explorer-title.sh`), web apps in X11 mode.
- **What the look is built from today:**
  - Kvantum theme `GlassDark` (`files/scripts/kvantum-glass.sh`).
  - Look-and-feel `org.mountain.desktop` with layout.js: bottom dock and optional top bar (`mountain-topbar`).
  - Start menu: Menu 11 Enhanced (vendored).
  - We10X icons, KWin blur, lite mode (`mountain-lite-mode` turns blur off on weak PCs).
  - Wallpaper: thin-line peaks (`/usr/share/mountain/wallpaper.svg`/`.png`).
- **Owner reference images:** `C:\Users\marin\Desktop\Operating System\mountain-v6-refs\` (look at every one before designing):
  - `owner-desktop.webp`: the owner's real Windows 11 desktop. This is the target feel.
  - `owner-wallpaper-wavy-black-white.jpg`: the owner's wallpaper (soft silk waves, white fading to black). Unknown license: **never commit it**. Use it only as a style reference.
  - `glossy-black-chrome-shapes.png`: black panels with a thin bright chrome/silver rim, a highlight on the top edge, a deep black inner gradient, rounded corners and pill toggles.
  - `glassmorphism-black.png`: frosted dark-glass panel over black, thin light border, soft blur.
  - `dark-glass-dialog.png`: dark glass settings dialog with rounded corners, a subtle border, a pill switch and two calm buttons.
  - `windows-settings-home.png`: Windows 11 Settings Home, the target structure for Settings:
    - a sidebar with the account at the top and colored category icons
    - the search box on top
    - a Home page with a device card (wallpaper thumbnail, PC name, Rename), Recommended settings, Bluetooth devices with an on/off pill, and Personalize (wallpaper/theme tiles, Color mode)
  - `windows-quick-settings.png`: the Windows 11 quick-settings flyout (tray click):
    - tiles: Wi-Fi, Bluetooth, Airplane mode, Accessibility, Energy saver, Live captions
    - brightness and volume sliders
    - battery % and a settings gear
  - Older refs are in `mountain-v3-refs\` (Explorer, logo sketches).

## What to build (all of it)

### 0. Leftovers the owner named again: each must be done AND proven with a vm-test screenshot

1. **Drag-icon bug** (icons vanish or blink while dragged on the desktop):
   - v5 backports KDE's fix (plasma-desktop MR 4141/4159) in `files/scripts/desktop-drag-fix.sh`. Confirm it applied in the build log and in phase 27.
   - Add a vm-test that does a fast drag right after selecting, and screenshots mid-drag and on drop.
   - If icons still blink on drop (KDE bug 514333, 3 invisible frames), find and backport the upstream fix, or fix it in the shipped QML.
2. **"Dolphin" in title bars:** v5 ships an `en@mountain` catalog plus `/etc/xdg/plasma-workspace/env/mountain-names.sh`.
   - Check the vm-test check "title bar says File Explorer" and look at a screenshot of the title bar.
   - If it fails, find another way that changes the title.
3. **Details pane:** the owner wants it. Overrule the old "Windows has it off" ruling.
   - Open File Explorer with the Information/Details panel visible on the right by default for new users, in black glass, like the Windows 11 Details pane.
   - Research how Dolphin stores panel state (`dolphinrc` / the `State=` key / `dolphinui.rc`) and ship a skel default.
4. **Login avatar:** v5 ships `mountain-avatars` (AccountsService picture).
   - Prove it with a screenshot of the login screen showing the Mountain logo picture, and of the lock screen.
5. **Lock greeting "Hello, <name>":** part of section 1. It must say **Hello, <display name>** above the password box on both login and lock.

### 1. Lock screen at start (owner: "a big problem to me")

**Today:** Try Mountain auto-logs in and has no lock screen, so the owner never sees one. The shipped image shows the stock login greeter.

**Target:** like Windows 11.
- On boot, a **lock screen**: the blurred wallpaper, a big clock and date, and nothing else.
- A click or key slides up to **"Hello, <name>"**: the account picture (Mountain logo by default), a password field and a power button.
- The same design appears on **lock** (Win+L, idle) and after sleep.

**Research first and cite sources in the plan.** Decide which of these Plasma 6.8 still allows:
- A custom Plasma Login Manager theme.
- Switching the image to SDDM with our own QML theme (SDDM themes are plain QML and fully customizable).
- Overriding the kscreenlocker greeter QML. It moved out of look-and-feel packages; check whether `contents/lockscreen` is still honoured, or whether the greeter loads a theme path.

Pick the option that gives the same design for both login and lock with the least fragile code. Bazzite's own choices count: check what it ships and why.

**Try Mountain:**
- Show the lock screen and login (no autologin). Desktop password stays `123`, typed by the owner.
- Keep the lock screen on.
- Keep passwordless sudo and polkit in the Try VM only.
- Update `docs/TRY-MOUNTAIN.md` and the noVNC hint text.

**vm-test:** screenshots of the boot lock screen, the "Hello" step, a wrong password, a correct password reaching the desktop, then Win+L and unlock.

### 2. Glossy black-glass UI (keep the current layout)

One design language everywhere, taken from the refs:
- near-black translucent glass with real blur behind it
- a 1 px light/chrome rim with a brighter top-edge highlight
- a subtle vertical gloss gradient
- rounded corners (taskbar pill, menus 12 px, windows 10 px)
- soft deep shadows
- pill toggles
- white text, calm accent

Apply it to:
- **Taskbar/dock:** a floating glass pill like the refs, clear hover and active glow, the running-app indicator, and the tray and clock on the right. Two-line time and date like the owner's taskbar. A weather widget on the left only if a Plasma one is installed; don't add network bloat.
- **Start menu, search, top bar** (optional; it stays toggleable), **system tray popups, calendar, volume/network/battery popups, notifications, OSD (volume and brightness), tooltips, context menus, Alt+Tab.**
- **Window decorations:**
  - glass title bars
  - Windows-style buttons (minimize, maximize, close; red close hover)
  - rounded corners
  - the active window with a slightly brighter rim
  - Use KDE's own means: an Aurorae SVG theme we ship, Breeze settings, or the KWin rounded-corner support Plasma 6.8 has. No COPR.
- **Apps (Kvantum):** replace or extend `GlassDark` into a "Mountain Glass" SVG with chrome rims on buttons, fields, tabs, scrollbars, pill switches, menus, dialogs and the Dolphin/File Explorer toolbar.
- **Plasma theme:** our own desktop theme (panel, dialog and tooltip SVGs with blur masks) so Plasma surfaces match Kvantum apps.
- **Colors:** a matching color scheme. Check accessibility contrast on every text/background pair (WCAG AA).
- **Lite mode** (weak PCs and VMs without GPU): the same look with blur off, falling back to solid glossy black, never ugly.

Measure, don't guess: render each surface in vm-test and compare it side by side with the refs, then run design-critique on the screenshots. Iterate until it reads as "black glass" at a glance.

### 3. Desktop close to the owner's own (see `owner-desktop.webp`)

- **The owner's own wallpaper:** "I like my actual background on my PC. So if you can get it, it will be nice." It is a downloaded stock image of unknown license and the repo is public, so it can't be committed or shipped. Ruling: ship an original look-alike as the default, and document in `docs/OWNER-GUIDE.md` how to set their own file in one step (right-click the desktop → Change wallpaper).
- **New default wallpaper, our own original work:** soft silk/fabric waves, white/grey fading into deep black, in the style of the owner's wallpaper. Never copy it. Generate it ourselves: a scripted render (for example Python with numpy, layered sine-wave height field and soft shading) or SVG gradients. Make it crisp at 1080p, 1440p and 4K, with a dark variant.
  - Use it for the desktop, lock and login (blurred there).
  - Keep the thin-line peaks wallpaper as a second choice.
- **Desktop icons** in Windows order: columns starting top-left, readable labels with a soft text shadow (they must stay readable on the light part of the wallpaper), Windows-like folder icons, Recycle Bin.
- Keep our desktop folders (Cloud Gaming, Games, Coding, AI and the rest) and "This PC".

### 3a. Settings like Windows 11, in black glass

The owner: "the settings is just clean as fuck. Just make them glossy."

**One Settings app** with the Windows 11 structure and names from `windows-settings-home.png`:
- a sidebar with the account picture and name on top
- colored category icons in the Windows order: System, Bluetooth & devices, Network & internet, Personalization, Apps, Accounts, Time & language, Gaming, Accessibility, Privacy & security, Updates
- the search box on top
- a **Home** page with:
  - the device card: wallpaper thumbnail, PC name, Rename
  - Recommended settings
  - Bluetooth devices with an on/off pill
  - Personalize: wallpaper and theme tiles, Color mode

**Updates** stands in for Windows Update and runs the existing Updates app (uupd, manual only).

**Research first** and cite sources. Pick the least fragile route and log the ruling. Options:
- Reorganize KDE System Settings: sidebar categories, the landing page `kcm_landingpage`, renamed and hidden modules.
- A small Kirigami/QML "Mountain Settings" shell that opens the real KDE modules (KCMUtils) for each page.

Rules:
- Every Windows category must reach a working KDE page.
- Nothing advanced appears on the first level.
- Black-glass styling: cards with chrome rims, pill switches and calm buttons, like `dark-glass-dialog.png`.

**vm-test:** open Settings, screenshot Home and every category, search "bluetooth" and "wallpaper", and check that every page opens.

### 3b. Quick settings flyout like Windows 11

Clicking the network/volume/battery area of the tray opens **one** glass flyout, like `windows-quick-settings.png`:
- **Tiles:** Wi-Fi (› to pick a network), Bluetooth (›), Airplane mode, Energy saver (power profile), Accessibility, Night light.
- **Sliders:** brightness (when the hardware has it) and volume (with an output picker).
- **Bottom row:** battery % and a gear that opens Settings.

Build it:
- Use Plasma's own backends and models: NetworkManager, BlueZ, PowerDevil and PipeWire.
- Ship it as our plasmoid in the tray, replacing the separate icons; keep the old applets reachable.
- It must open in under 150 ms, and every tile must really toggle.

**vm-test:** whatever the VM allows (volume, airplane, energy profile), with screenshots.

### 3c. An optimized UI ("It's not only about the looks")

The new surfaces (glass theme, Settings, quick settings, lock screen) must be light:
- no heavy QML effects or per-frame shaders
- blur only where KWin already does it
- SVG themes, not large images

Measure plasmashell and kwin CPU and RAM, idle and while menus and flyouts open, before and after:
- Keep them at or below today's numbers (RAM at desktop is about 1520 MB in vm-test).
- Fail vm-test if idle CPU or RAM regress by more than 10 %.

### 4. Snappy as a whole

The owner wants it "more snappy as an OS: open things fast, snappy as all".
- Measure in vm-test, before and after, with numbers in `docs/TESTING.md`:
  - cold and warm open time of File Explorer, Settings, Konsole, VS Code and Steam
  - start-menu open time
  - Alt+Tab
  - login to desktop
  - RAM at desktop
  - boot time
- Tune:
  - KWin animation speed (snappy, not none)
  - effects that cost frames
  - plasmashell start time
  - Baloo and background services
  - app preload only if measured worth it
  - LAVD settings
  - I/O scheduler and zram (Bazzite defaults first)
- Set budgets: start menu < 150 ms, Dolphin warm open < 400 ms, login to desktop ≤ 2 s. Fail vm-test on regressions over 20 %.

## Owner's own words (verbatim, for fidelity)

> And also when I launch it, I don't see the love screen, which is a big problem to me. And I need a glossy UI. Add that to the prompt, make it a big ass prompt. I'm gonna add you a glossy UI idea of one I want to be. Keep the current layout, it's not too bad, but add a glossy UI. Like, I'm gonna give a few photos. The first one is gonna be of my actual desktop, and I need something like it because that's what I like. I have made it in Windows, but you will get the general idea. I want the template to be close to it. [...] I'm gonna give you what I mean by black glassy UI. That just looks futuristic and cool. Taskbar, things, that just feel incredibly well to use, and they are snappy. Also, I would love it to be a little bit more snappy as an OS to do to open system fast and just be snappy as all. That's pretty much it. And fix the lock screen. Fix the lock screen.

("love screen" means lock screen.)

> It's not only about the looks too. I need the optimized UI, the UI of the OS should be optimized to run it. I want to have like settings like Windows. I'm gonna give you a photo of some things I like about Windows, and I want to make like it. But with the glossy texture, like the settings is just clean as fuck. Just make them glossy. I like my actual background on my PC. So if you can get it, it will be nice. So I want Linux that is looks like a better OS than Windows, but it's unfamiliar to Windows people. Use the biggest possible thinking you can do. Add skills that you need, like designing UI, QA, everything you need. In before we do V5, I want you to add these things to V5 and then test it, and then after it's tested, everything, every single thing, then it pushes it and it becomes part of V5.

## Testing (every task, plus a full pass at the end)

- TDD where possible; image checks in a new phase 28+; push, let CI build and run vm-test; read the report and look at every screenshot yourself.
- Visual QA:
  - Screenshot every surface listed in section 2 and the lock and login flow.
  - Put each next to the matching ref, then run design-critique and accessibility-review.
  - Fix and repeat. Check at 1280×800 and 1920×1080, and in lite mode.
- Keep every existing vm-test check green: files open, drag and drop, start menu, Steam, AI CLIs, web apps, hardening, reboot.
- At the end, the full real-use pass:
  - start Try Mountain from `main`
  - open the link in the built-in browser and confirm the page loads (never type passwords on the public link)
  - give the owner the link and a short "what to try" list, with the lock screen first

## Constraints (hard rules)

- **Secrets and the public repo:**
  - Never commit cosign.key, ISOs, VM disks or the owner's wallpaper/photos.
  - The repo stays public.
  - Never print the Try Mountain browser password in the repo or logs.
- **Downloads and brands:**
  - No third-party downloads at build time, except Fedora repos, repos already in the recipe, Flathub, or vendored GPL/MIT code with its license kept.
  - Never draw or copy brand logos. Use the apps' installed icons. The Mountain logo is ours.
- **Passwords:** the desktop password `123` and passwordless admin exist in the Try VM only, never in the shipped image. The shipped image keeps the lock screen and a real password.
- **CI lessons:**
  - Azure apt mirror outages: use archive.ubuntu.com with retries.
  - ghcr 429: wait 5 minutes and rerun the failed jobs.
  - `build.yml` cancels in-progress builds on the same ref.
  - Try Mountain needs `actions/checkout`.
  - Edit YAML with Python exact-string replacement, never sed with `\|` (it is alternation in GNU sed and corrupted vm-test.yml once).
- **Git:**
  - Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - PR bodies end with the Claude Code line.
  - The owner authorized merging to main when CI and vm-test are green.
- **Usage:** save it. Use cheap models for mechanical work, no repeated waiting, and background waits instead of polling.

## Done means

- Settings (3a) and quick settings (3b) work like Windows 11 in black glass, with screenshots of every page and tile.
- The UI-cost numbers (3c) are measured and at or below today's.
- The lock screen shows at start and on lock in Try Mountain, with the screenshots in vm-test.
- Every surface in section 2 has been reworked into black glass, and each one is shown in vm-test screenshots and compared with the refs.
- The new original wallpaper is the default.
- The snappiness numbers are measured and improved.
- All checks are green and the work is merged to main.
- The owner has a fresh Try Mountain link (checked), a "what to try" list and a list of rulings.
