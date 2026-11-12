# Mountain v6: "Windows-familiar, better than Windows, my daily OS" master prompt

> **This file replaces the v5.1 master prompt and the v5.1 addendum as the single brief for this round.**
> Put it in the repo as `docs/superpowers/prompts/2026-11-12-mountain-v6-master-prompt.md` and commit it. Keep the older two files for history.
> This round is **version 6** (renamed from v5.1 by the owner). Branch `mountain-v6`, PR "Mountain v6".
> Everything below is in scope. Brainstorm and research first, using open-source community solutions before building our own. Measure, test every item in vm-test with screenshots, review, and merge only when everything is green.

Process: superpowers (brainstorming → writing-plans → subagent-driven-development → verification-before-completion). The design skills frontend-design, design-critique and accessibility-review apply to every visual piece. Model use:
- Cheap subagent models for mechanical tasks.
- Mid-tier for reviews.
- The most capable model for design, security architecture and the final review.

Don't stop between tasks; make rulings and log them. The owner is non-technical: always show a live task list and a status table (⏳ 🕓 ✅ 🔍 🔧 ☁️), short and plain. One `gh run watch` per run; never poll the GitHub API in tight loops (the rate limit was hit once).

---

## Part A. Who it's for and what "done" feels like

### A1. The owner's vision (verbatim, latest first)

> Let's say they want the getting. It feels familiar to Windows. It's not like they step in a different category. It's the same thing as Windows. The Windows looks the same. It's just a different template. And you can customize it more that you like it or it's better on games. It runs smoother than Windows. The protection is better than Windows. You actually [find] threats. Most games work on it. Cloud gaming works on it. The programmer can use it. That's what I want to make. Something for me personally, not something global. I want something secure, fast, and bootable that I can use every single day.

> It doesn't look like Windows. It doesn't feel like Linux. Like it's something very the shit in between. You understand me? It should look good like Windows. It should be black themed, like glass themed, but it should look like a Windows still, so people will be familiar with it.

> I need it to be real operating system [...] what it still should be done to be better than Windows actually. Fucking better than Windows.

> [Quick settings:] ADD BRIGHTNESS. ITS NOT SMOOTH EXPERIENCE SWITCHING, OPENING FILES DOESN'T FEEL LIKE WINDOWS OR MAC. MAKE SURE IT RUNS SMOOTH. NOT SO MUCH [see-through], YOU NEED TO ADD MORE CONTRAST [so I can tell things apart]. The UI doesn't feel sharp on my screen. There is no task manager. I need a pure task manager like a built-in system one that gives info, and a protection against threats, open source or not. I want a nearly unbreakable system too, that is going to hold to any attack.

> [Start menu:] look at the win menu, how blank it is, fix that.

### A2. Product definition

- **Personal daily driver for one person** (the owner): gaming, cloud gaming and coding. It is not a distro for everyone. Tune it for the owner's apps and use; drop anything that only "everyone" would need.
- **Windows 11 at first glance:** same layout, positions, sizes, names, shortcuts and habits. Only the skin differs: **black glass**.
- **Better than Windows** where it counts. Each point below must be *visible* to the owner, not only true:

| Better than Windows | How the owner sees it |
|---|---|
| **Smoother** | Instant menus, fast file opening, no stutter, a light background |
| **Safer** | It actually finds threats; firewall closed; hard to break; one-click roll back |
| **Never bricks** | A bad update rolls back; the previous version is always one click away |
| **No ads, no forced updates, no telemetry** | Updates only when the owner presses Update |
| **Better for games** | CS2 and War Thunder native; Proton for the rest; cloud gaming one click away; an FPS overlay |
| **More customizable** | Theme, taskbar, start menu, top bar and accent, all in Settings like Windows Personalization, but with more options |
| **Ready for coding** | VS Code, terminal, Git, Python, Node and the AI CLIs, one click each |

- **Not this round:** an installer or a real-PC install (the owner said "it's not time"). Everything must be polished and working in Try Mountain and vm-test. Design so that the real install later needs no redesign.

### A3. The owner's games (researched 2026-11-12)

| Game | Status on Linux | What Mountain does |
|---|---|---|
| **CS2** | ✅ Native Linux build; VAC works | Pin it or show it in Games; make sure Steam and the Vulkan drivers are ready; test-launch if possible |
| **War Thunder** | ✅ Native Linux client | Same |
| **GTA V story mode** | ✅ Proton | Steam with Proton set up |
| **GTA Online** | ❌ Rockstar blocks Linux in BattlEye on purpose (their choice, not technical). Players are kicked as of 2026. | See the dual-boot ruling |
| **FiveM** | ❌ Launches under Proton, but real servers reject it: its anti-cheat doesn't run on Linux. A launcher PR for Wine detection was still unmerged in mid-2026. | See the dual-boot ruling |

Sources: [GamingOnLinux](https://www.gamingonlinux.com/2024/09/grand-theft-auto-v-gets-battleye-anti-cheat-breaks-online-play-on-steam-deck-linux/), [ProtonDB GTA V](https://www.protondb.com/app/271590), [cfx.re forum](https://forum.cfx.re/t/native-linux-support-for-fivem-it-s-time/5330614/79), [izmystic FiveM on Linux](https://izmystic.dev/blog/fivem-on-linux).

**Ruling (proposed to the owner, who did not object): dual boot plus cloud as a backup.**
- Windows stays on the owner's PC next to Mountain for GTA Online and FiveM.
- Mountain gets a **Mountain-styled boot menu** and a **"Restart into Windows"** entry in the start menu power menu and in Settings → System → Recovery. It is shown only when a Windows boot entry exists (EFI boot entries via `efibootmgr`/`bootctl`), and it uses a one-time boot (`BootNext`) back to Windows.
- vm-test proves it with a fake EFI entry (or a second test disk), and proves the item is hidden when no Windows entry exists.
- In Games, put a short, friendly note on GTA Online and FiveM: "GTA Online and FiveM block Linux. Use Restart into Windows or cloud gaming." Link Restart into Windows.
- Cloud gaming (GeForce NOW, Boosteroid, Xbox Cloud) stays one click away as the backup.
- A small "Check game support" link opens ProtonDB/areweanticheatyet for a game. Read-only, nothing in the background.

---

## Part B. Look: Windows 11 shapes, black glass material, real contrast

### B1. North star and method

1. Screenshot every Mountain surface and put it next to the matching Windows 11 surface. Surfaces:
   - taskbar
   - start menu
   - File Explorer
   - Settings
   - quick settings
   - notification center
   - context menus
   - dialogs
   - title bars
   - Alt+Tab and Task view
   - lock and login screens
   - Task Manager
   - Security
2. List every difference in shape, spacing, size, font, icon, naming and behaviour.
3. Close the gaps while keeping black glass as the material.
4. Run design-critique on each surface until the verdict is "looks like Windows 11 in black glass", not "a Linux theme".

### B2. Design tokens (one set, used by Kvantum, the Plasma theme, the window decoration, QML apps and the color scheme)

| Token | Value |
|---|---|
| Font | A Segoe-like open font: Selawik (MIT, Microsoft's open Segoe UI fallback) or Inter or Noto Sans; log the ruling. 9–10 pt UI, crisp hinting, whole-pixel sizes. |
| Radii | Windows 11: windows 8 px, menus and flyouts 8 px, buttons 4 px, the taskbar flat full-width or a pill (match the owner's desktop: full-width, centered icons) |
| Sizes | Taskbar 48 px; start menu about 640×720; title bar 32 px; the Windows button and caption sizes |
| Icons | Fluent-style (an open Fluent icon theme within its license), consistent everywhere |
| States | Windows hover, press, selection and focus visuals; a visible keyboard focus ring |

### B3. Contrast and readability ("so I can tell things apart")

- **Glass is an accent, not a fog.**
  - Windows, app content, File Explorer, Settings and Task Manager are **near-opaque** (≥ 90 % opacity), so content behind never reads through. The v5 screenshot showed "Sign in" bleeding through File Explorer.
  - Real translucency with blur only on the taskbar, start menu, flyouts, notifications and the lock screen.
- **Text:** WCAG AA minimum everywhere, AAA for body text where possible.
- **Surfaces:** a visible step between sidebar, content, toolbar, cards and the selected item (a different shade plus a 1 px rim). Selection uses a solid accent.
- **Disabled vs enabled:** obvious at a glance.
- Run accessibility-review on every screenshot. Check light and dark wallpapers.

### B4. Sharpness

- Font hinting and grayscale/subpixel antialiasing.
- No fractional-pixel SVG elements; icons at whole sizes.
- Check 1280×800 and 1920×1080, at 100 % and 125 % scale.
- **Try Mountain view:**
  - noVNC without blurry downscaling (`resizeSession` or a VM resolution matching the browser window; `scaleViewport` only when needed).
  - Quality and compression tuned for crisp text.
  - Explain in `docs/TRY-MOUNTAIN.md` what is soft only because of the remote view.

### B5. Surfaces, one by one

**Taskbar** (match the owner's Windows desktop):
- Full width, centered icons, the start button first.
- Weather on the left, only if it costs no background traffic; otherwise leave it out.
- Tray on the right: ^ overflow, language "ENG/БЪЛ", the quick-settings group (network, volume, battery), a two-line clock and date, a notification badge, and a show-desktop sliver at the far right.
- Running-app indicator, hover previews, jump lists, Pin/Unpin.
- Right-click the taskbar for Taskbar settings and Task Manager.

**Start menu** (it was "blank"):
- Search on top: apps, settings, files and calculations.
- **Pinned:** 18 pins in 3 rows, with a page indicator.
- **Recommended:** recent files and new apps, never empty. Turn recent-files tracking on for new users. When there is truly nothing yet, show one calm hint line like Windows.
- **All apps:** A–Z with letter headers.
- Bottom: the account menu (Change account settings, Lock, Sign out) and the power menu (Sleep, Shut down, Restart, Restart into Windows when available).
- No dead space.
- Names: "VS Code", not "Visual Studio". "Welcome" goes out of the default pins.

**File Explorer:**
- The Windows 11 layout: tabs in the title row (or hidden with a single tab), address bar and search, command bar, Home/Gallery-style home, sidebar, Details pane.
- No truncated labels in the sidebar or status bar.
- Folder icons Windows-like.

**Settings:** the Windows 11 structure from v5, made opaque and contrasty, and every page reachable.

**Quick settings:**
- Tiles: Wi-Fi, Bluetooth, Airplane, Energy saver, Accessibility, Night light.
- **Brightness slider:** the real backlight or DDC/CI; when no control exists, disabled with "Not available on this display".
- Volume slider with output picker, battery %, and a gear to Settings.
- **Win+A must work** (it failed in v5).

**Notification center (Win+N):** the Windows 11 look, with the calendar below the notifications, opened by clicking the clock, and Do Not Disturb.

**Widgets (Win+W, optional):** weather, calendar and system stats, only if light.

**Title bars:** Windows caption buttons, the active-window rim, red close hover, Windows sizes.

**Context menus and dialogs:** Windows 11 spacing, icons and order; no developer jargon on the first level.

**Lock and login:** keep v5's "Hello, name" and clock. Make the sign-in step slide up like Windows if it is cheap; otherwise keep the fade.

**Desktop:** v5's Mountain Silk wallpaper. Icons in columns from the top-left, readable labels with a soft shadow, Recycle Bin, This PC.

**Customization (better than Windows):** in Settings → Personalization:
- accent color
- glass strength (with an "Off" for weak PCs)
- taskbar alignment
- top bar on/off
- icon theme
- start-menu layout (more pins or more recommended)
- wallpaper, including the owner's own file

All of it applies live.

---

## Part C. Smooth, fast, light ("it runs smoother than Windows")

1. **Measure first in vm-test,** with numbers in `docs/TESTING.md` before and after:
   - double-click → window for a folder, photo, PDF, text file and app (cold and warm)
   - folder navigation
   - Alt+Tab
   - start menu, quick settings and Task Manager open times
   - window drag frame pacing
   - login → desktop
   - boot time
   - RAM and CPU of plasmashell and kwin, idle and busy
2. **Fix the causes:**
   - Windows-like animations: open and close 150–200 ms, eased, no slow fades.
   - Effects that cost frames removed.
   - Blur only where needed.
   - File Explorer thumbnail and Information-panel cost (debounce or lighter).
   - Preload or keep-alive only where measured.
   - Background services audited again; no indexer by default.
   - LAVD scheduler kept.
3. **Budgets** (fail vm-test on a regression over 20 %):

| Measure | Budget |
|---|---|
| Start menu | ≤ 150 ms |
| Quick settings | ≤ 150 ms |
| Folder navigation | ≤ 150 ms |
| Warm double-click → window | ≤ 500 ms |
| Task Manager warm | ≤ 500 ms |
| Alt+Tab | ≤ 100 ms |
| Login → desktop | ≤ 2 s |
| Idle RAM | ≤ v5's ~1490 MB |

4. **Owner's question answered in the docs:** Try Mountain runs without a GPU (software rendering) and is viewed through noVNC over the internet. Both add lag and blur, so the real PC will be smoother. Mountain-side slowness still gets fixed here.

---

## Part D. Protection: "it actually finds threats"; nearly unbreakable

### D1. Threat model first (written in the plan)

Cover:
- remote attack
- a malicious download or app
- a malicious USB device
- a stolen laptop
- a broken update
- user mistakes
- ransomware
- a compromised browser/web app

For each one, state the layer that stops it and how vm-test proves it.

### D2. Windows Security-style "Security" page (in Settings and in the start menu)

Each area shows a green, yellow or red status with one-click fixes:

1. **Virus & threat protection** (brainstorm, then rule):
   - ClamAV: clamd + clamscan, with quick, full and custom scans, Scan now, scan history and quarantine with restore/delete.
   - Right-click "Scan with Mountain Security" in File Explorer.
   - Downloads folder scanned on new files (a light fanotify/inotify watcher on `~/Downloads` only; never Steam or Proton paths). Measure the RAM: clamd is about 1 GB with signatures, so weigh on-demand vs resident. If resident costs too much, a scan-on-download helper that starts clamd only when needed.
   - Signature updates **only when the owner presses Update or Scan now** (no background downloads, the owner's rule); say so in the UI.
   - Closed-source options are allowed if clearly better and free for personal use: weigh them and log the ruling.
2. **Firewall & network protection:**
   - firewalld zone `mountain`: no incoming ports open, except what v4 allowed (DHCP, mDNS, Samba client, Steam Remote Play).
   - Show the zone and on/off, plus an "Allow an app" list like Windows: Steam Remote Play and others, each a toggle that opens or closes the needed firewalld service.
   - Show "Blocked recently" from the firewalld log if cheap.
   - Public and Home network profiles like Windows, mapped to zones.
3. **App & browser protection:**
   - Flatpak sandbox status, with a per-app permissions view (Flatseal-like, or link Flatseal).
   - Warn on apps with full home or filesystem access.
   - Edge web apps run with their own profiles.
4. **Device security:**
   - Secure Boot (on/off and how to enable it with Bazzite's MOK)
   - TPM present
   - SELinux enforcing
   - kernel lockdown status
   - disk encryption (LUKS) status
   - USB protection (USBGuard is opt-in, with "allow currently connected devices" so gaming peripherals keep working)
5. **Account protection:** password set, screen lock on, auto-lock timer, sudo asks for a password, and no passwordless admin in the shipped image.
6. **Updates & recovery:** last update, image signature verified (cosign policy), the previous version kept, Go back, Reset this PC.

### D3. Nearly unbreakable (layers; each with an undo step in `docs/OWNER-GUIDE.md`)

- **Immutable system:** read-only `/usr`, image-based (bootc/ostree), signed images verified on update, and the previous image always kept with automatic rollback if boot fails.
- **Go back:** Settings → Recovery and the boot menu.
- **File History:** Btrfs snapshots of `/home` (snapper or a timer, hourly or daily with retention). Restore through File Explorer right-click → "Restore previous versions". This is the ransomware and mistake shield.
- **Reset this PC:** keep my files, or remove everything. Document what it does on an image-based system.
- **Hardening** (all gaming-safe; measure Steam, Proton and the web apps afterwards):
  - SELinux enforcing
  - the v4 sysctls and kernel args
  - firewall
  - Flatpak defaults tightened
  - kernel lockdown=integrity if gaming-safe
  - core dumps off
  - no SSH server running
- **vm-test proves:**
  - Go back works
  - a deleted file is restored from a snapshot
  - an incoming port is blocked
  - a Flatpak can't read `~/Documents` without permission
  - an EICAR test file is detected and quarantined
  - Steam, Proton and the web apps still work

---

## Part E. Complete everyday OS (Windows-familiar)

### E1. Task Manager (Ctrl+Shift+Esc, start menu, taskbar right-click)

- **Brainstorm first:** Plasma System Monitor (renamed, our own pages), Mission Center, Resources, or an own app. Pick the most native, light and reliable option and log the ruling.
- **Tabs like Windows 11:**
  - Processes: apps vs background, with CPU, RAM, disk, network and GPU per process, and End task.
  - Performance: CPU, RAM, disk, network and GPU graphs with model names.
  - App history.
  - Startup apps: real enable/disable.
  - Users.
  - Details.
  - Services: systemd, with an admin prompt.
- Black glass, opaque content, ≤ 500 ms warm.

### E2. Windows shortcuts (all must work, each tested in vm-test)

| Shortcut | Action |
|---|---|
| Win | Start |
| Win+E | File Explorer |
| Win+I | Settings |
| Win+A | Quick settings |
| Win+N | Notifications |
| Win+D | Desktop |
| Win+L | Lock |
| Win+Tab | Task view |
| Win+Shift+S | Snip region to the clipboard, with a notification |
| PrtSc | Full screenshot |
| Win+V | Clipboard history |
| Win+. | Emoji |
| Win+Z | Snap layouts |
| Win+Arrows | Snap |
| Alt+Tab | Switch windows |
| Ctrl+Shift+Esc | Task Manager |
| Alt+F4 | Close; on the desktop, the shut down dialog |
| Win+R | Run |
| Win+X | Power-user menu |
| Win+G | Game overlay |
| Win+Space / Alt+Shift | Switch language |

### E3. Everyday apps (Windows names, the right icons, file associations, black glass)

| App | Built from |
|---|---|
| Notepad | KWrite or Kate simple mode; VS Code stays for code |
| Calculator | |
| Photos | Gwenview |
| Media Player | Haruna |
| Camera | |
| Clock | KClock |
| Snipping Tool | Spectacle |
| Paint | KolourPaint |
| Sound Recorder | |

Use Fedora packages or Flathub, renamed through `.desktop` overrides. Nothing runs in the background unless opened.

### E4. Languages

- Bulgarian keyboards (BG phonetic and BDS), switching and a taskbar indicator.
- Cyrillic correct everywhere: files, menus, lock.
- English UI by default, with Bulgarian selectable in Settings → Time & language. The "File Explorer" title keeps working.

### E5. Devices and connections

- **Phone Link:** KDE Connect, named and on demand.
- **Cloud drives:** OneDrive and Google Drive in File Explorer through online accounts, when they work without paid services.
- **Printing and scanning:** driverless (IPP Everywhere) printers and scanners, shown in Settings → Bluetooth & devices.
- **Displays and sound:** brightness and DDC/CI, Night light, HDR and VRR switches in Settings → Display, and output switching.

### E6. Gaming extras

- **Controllers:** Xbox, PlayStation and Switch pads, shown in Settings → Gaming.
- **Game overlay:** MangoHud, toggled with Win+G.
- **Game mode:** on for Steam games.
- **Steam and Heroic:** ready, with Proton set.
- **Cloud gaming:** web apps with their own taskbar entries (v5).
- **Restart into Windows** (A3).

### E7. Coding

Already present: VS Code, terminal, Git, Python, Node and the AI CLIs with one-click install.
- Check that each still works.
- Make the "Coding" folder and start-menu entries Windows-clear.
- Terminal named "Terminal".

---

## Part F. Testing, final polish, done

- **Each task:** TDD where possible, a new image-check phase (never weaken old ones), and vm-test with screenshots. Look at every screenshot yourself and compare it with Windows 11 and the owner's refs.
  - Refs: `Desktop\Operating System\mountain-v6-refs\` and `mountain-v51-refs\`, including the owner's v5 screenshots of quick settings, File Explorer and the start menu.
- **Final polish pass:** walk the whole OS as a Windows user.
  - boot and lock screen, desktop
  - start menu: open every pin
  - File Explorer tasks
  - every Settings page
  - every shortcut
  - Task Manager
  - Security: Scan now and EICAR
  - Firewall "Allow an app"
  - Go back
  - File History restore
  - Games, Restart into Windows (hidden in the VM unless faked)
  - cloud gaming
  - coding
  - Bulgarian typing
  - lock, sleep, restart

  Screenshot every step, run design-critique and accessibility-review, and fix everything "in between" or Linux-ish.
- **All v5 checks stay green:** lock screen, Hello, Settings, quick settings, File Explorer title and Details pane, drag icons, files open, Steam, AI CLIs, web apps, reboot.
- **Done:**
  - everything above green in CI and vm-test with screenshots
  - budgets met and numbers in `docs/TESTING.md`
  - `docs/OWNER-GUIDE.md` updated (security, recovery, Restart into Windows, customization)
  - merged to main
  - Try Mountain started from main and its link checked in the built-in browser (never type passwords there)
  - the owner given the link, a "what to try" list in plain words and the rulings

## Constraints (unchanged from v5, plus)

- **Secrets and the public repo:**
  - Never commit secrets, cosign.key, ISOs, VM disks or the owner's photos/wallpaper.
  - The repo stays public.
  - Never print the Try Mountain browser password.
- **Downloads:** no third-party build-time downloads beyond the Fedora repos, repos already in the recipe, Flathub, or vendored GPL/MIT code with its license.
- **Brands:** never copy brand logos; use the apps' own installed icons.
- **Try Mountain only:** desktop password `123` and passwordless admin live in `try-mountain.yml`, never in the shipped image.
- **Gaming:** security changes must not break it. Anything risky is opt-in with a clear switch.
- **Editing:** edit YAML with Python exact-string replacement, never sed with `\|`.
- **Git:**
  - Commit trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; PR bodies end with the Claude Code line.
  - The owner authorized merging to main once everything is green.
