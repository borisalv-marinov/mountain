# Mountain v3 — Windows-like polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Mountain look, behave and respond like Windows (logo, start menu, File Explorer, file opening, wallpaper, no confusing prompts), make it fast in the Try VM, secure by default, and prove every item with real-use vm-test screenshots.

**Architecture:** Same BlueBuild recipe (`recipes/common.yml`): static config under `files/system/...`, build scripts under `files/scripts/`, image checks in `tests/check-image.sh` (new phases 19–24, old phases untouched), real-use desktop tests in `.github/workflows/vm-test.yml` driven by QMP mouse/keyboard events. The Try VM and vm-test run QEMU from a Fedora container (newer QEMU, `virtio-vga` with a cursor that noVNC draws locally).

**Tech Stack:** Bazzite stable (Fedora 45, KDE Plasma 6), bash, XDG menu/mimeapps/xbel, rsvg-convert, Python 3 (wallpaper generator, run once locally; output committed), QEMU + QMP, noVNC.

**Spec:** `docs/superpowers/prompts/2026-11-11-windows-polish-master-prompt.md` (owner's request; it is the approved design — rulings below fill gaps).

## Global Constraints

- Never commit cosign.key, ISOs or VM disks; never print the Try Mountain browser password; never type passwords on public sites.
- No third-party downloads at build time except Fedora repos, existing recipe repos, or Flathub.
- Never draw or copy brand logos (Windows, NVIDIA, Xbox…); the Mountain logo is ours.
- Try Mountain only: desktop password `123`, no lock screen, passwordless admin, wallet off — in `try-mountain.yml`, never in the shipped image.
- `tests/check-image.sh`: add phases, never weaken old ones; bump `MOUNTAIN_PHASE` in `build.yml`. No hard-coded "Mountain" in `/usr/share/applications` or `/etc/xdg` (phase 10).
- Keep Bazzite Portal, Bazaar, Konsole, Steam.
- Commit trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; PR body ends with the Claude Code line.

## Research (what to do / what not to do)

| Source | Lesson | Applied in |
|---|---|---|
| Zorin OS ([The Register, Zorin 18 beta](https://www.theregister.com/2025/09/24/zorin_os_18_beta/), [Zorin forum: feedback as a Windows user](https://forum.zorin.com/t/feedback-as-a-windows-user/58560)) | Bottom taskbar, launcher lower-left/centre, tray+clock right; Windows users miss a compact Explorer-like list and get confused by extra concepts | Task 3, 4 |
| Linux Mint / Nemo ([ubuntubuzz Nemo guide](https://ubuntubuzz.com/2015/10/basic-guide-for-nemo-file-manager.html)) | Explorer feel = sidebar of standard folders + drives, simple context menu | Task 4 |
| KDE folder view vs Dolphin ([KDE bug 447617](https://bugs.kde.org/show_bug.cgi?id=447617), [discuss.kde.org](https://discuss.kde.org/t/is-it-possible-to-show-desktop-files-in-dolphin-under-its-application-name)) | Dolphin shows `.desktop` file names everywhere except under `desktop:/`, which reads `Name=` | Task 4 (Desktop place = `desktop:/`) |
| KDE drop menu ([bug 423356](https://bugs.kde.org/show_bug.cgi?id=423356)) | No setting removes the Move/Copy drop menu; Shift/Ctrl skip it | Ruling: keep, document |
| KFilePlacesModel source ([kio](https://invent.kde.org/frameworks/kio/-/blob/master/src/filewidgets/kfileplacesmodel.cpp)) | `user-places.xbel`, `kde_places_version`=4 stops re-seeding; `GroupState-<Group>-IsHidden` on root metadata; hrefs are absolute | Task 4 |
| Qt icon cache ([woboq: QIcon reads GTK cache](https://woboq.com/blog/qicon-reads-gtk-icon-cache-in-qt57.html), [Fedora icon-cache scriptlets](https://fedoraproject.org/wiki/Archive:PackagingDrafts/ScriptletSnippets/iconcache)) | Qt trusts `icon-theme.cache` when its mtime ≥ dir mtime; ostree flattens mtimes, so icons added after the cache was built can be invisible | Task 1 (rebuild caches last) |
| KWallet ([Arch wiki](https://wiki.archlinux.org/title/KWallet)) | Autologin cannot unlock the wallet → prompts; `[Wallet] Enabled=false` stops it but breaks saved browser passwords | Ruling: real image keeps PAM auto-unlock; Try VM disables wallet |
| QEMU display ([kraxel: display devices](https://www.kraxel.org/blog/2019/09/display-devices-in-qemu/), [qemu-devel cursor](https://lists.endsoftwarepatents.org/archive/html/qemu-devel/2018-11/msg04119.html), [RHEL-21570](https://issues.redhat.com/browse/RHEL-21570)) | std VGA has no HW cursor (guest draws it, every move = a remote frame); virtio-gpu sends the cursor to the VNC client (local cursor); QEMU 8.2 (Ubuntu 24.04) has a virtio VNC cursor regression | Task 5 (Fedora QEMU + virtio-vga) |
| Plasma 6 layout scripts (KDE bug 512005; applets as `qt6/plugins/plasma/applets/*.so`) | Guard optional applets; verify panels via screenshot | Task 3 keeps `opt()` |
| BlueBuild initramfs ([module docs](https://blue-build.org/reference/modules/initramfs/)) | Plymouth theme lives in the initramfs; regenerate with `type: initramfs` as one of the last modules | Task 1 |
| elementary / polish | Consistent icon set, one font, few panels, no duplicate entries | Task 3, 7 |

Baseline (vm-test run 43083205572, main, 2026-11-11): desktop RAM 1535 MB used; boot 23.2 s to graphical; plasmashell 650 MB, kwin 308 MB, input-remapper 89 MB, kdeconnectd 79 MB (D-Bus activated despite hidden autostart), kunifiedpush 29 MB.

## Rulings (logged for the owner)

1. "Windows logo" = We10X's purple 4-square icons (`applications-all*`, `start-here*`, `distributor-logo*`) shown in the start menu; replace them with the Mountain logo / Breeze equivalents.
2. KWallet: shipped image keeps the wallet with PAM auto-unlock at password login; Try VM turns the wallet off (autologin can't unlock it).
3. Drop menu (Move/Copy/Link) stays — KDE has no option; Shift = move, Ctrl = copy.
4. Kvantum GlassDark and the top bar stay (earlier owner choices, protected by phases 11/17); the top bar loses the macOS-style global menu, window title and network graph.
5. System partitions (EFI, boot, root) are hidden from File Explorer; USB/extra drives show with their labels.
6. Desktop "Files" becomes "This PC". Windows names: Settings, File Explorer, Task Manager, Terminal, System Information.
7. Menu: Utilities → "Accessories", System → "System Tools", Help and Waydroid folders removed from browsing (apps still found by search).
8. Double-click interval 500 ms (Windows default); 800 ms in the Try VM (remote latency).
9. KWin QPainter backend not used (risk); speed comes from the display path, lite mode and fewer services.

## Review Focus

1. A brand-new user's first login (no `~/.config`, no `~/.local/share/user-places.xbel`) gets every default — test with a fresh `looktest` user in vm-test.
2. A file type whose default app is a Flatpak not yet installed (OnlyOffice during first boot) — `xdg-open` must not hang; vm-test opens a .docx after flatpaks finish.
3. Paths with spaces (`Cloud Gaming`, `Game Launchers`) in `desktop:/` URLs and places — vm-test opens `desktop:/Cloud Gaming`.
4. Existing users upgrading (already have kickoff/places configs) — the logo/name fixes must not need a reset; the icon/name fixes are system-wide, layout changes apply to new users only (documented in `docs/TESTING.md`).
5. 1440p/4K screens — wallpaper package ships 1920×1080, 2560×1440, 3840×2160 PNGs; phase 20 checks all three.

---

### Task 0: Probe the current image (done before the plan was finalised)

Branch `probe-v3`, workflow `probe.yml` (deleted afterwards). Findings (image `mountain:latest`, 2026-11-11):
- No image viewer, PDF viewer, video or music player installed (gwenview, okular, haruna, elisa all missing) → photos/PDF/video "do nothing". Kate, KWrite, Ark present.
- `/usr/share/applications/mimeapps.list` sends office files to LibreOffice and mail to Thunderbird (neither installed).
- VS Code's desktop id is `com.microsoft.VSCode.desktop`; the dock pins `code.desktop` → "?" icon.
- `/etc/xdg/kcm-about-distrorc` = Bazzite logo/name; os-release `LOGO=bazzite-logo`, `BOOTLOADER_NAME="Bazzite Stable (…)"`.
- Plymouth theme `bgrt` uses `/usr/share/plymouth/themes/spinner/watermark.png` (Bazzite's); initramfs at `/usr/lib/modules/*/initramfs.img`.
- hicolor icon cache already contains our icons (cache theory ruled out); We10X ships `start-here*.svg` (Windows-style) in `status/*`.
- `/usr/share/wallpapers/Mountain` already exists (KDE's own) → our package is `/usr/share/wallpapers/mountain-peaks`.
- PAM `plasmalogin` and `plasmalogin-autologin` both load pam_kwallet; no `/etc/sudoers.d`; firewalld enabled; `kunifiedpush-distributor.service` wanted by graphical-session.target; kio workers `desktop`, `applications` present.

### Task 1: Mountain logo everywhere

**Files:**
- Create: `files/scripts/icons-finalize.sh` (runs last in the script list), `files/system/etc/xdg/kcm-about-distrorc`
- Modify: `files/scripts/branding.sh`, `recipes/common.yml` (scripts list + `type: initramfs` as last module before `signing`), `tests/check-image.sh` (phase 19), `.github/workflows/build.yml` (`MOUNTAIN_PHASE: 24` at the end of the plan)

- [ ] Step 1: phase 19 test:
  - `/usr/lib/os-release` has `LOGO=mountain-logo`
  - kcm-about-distrorc (profile dir) has `LogoPath=/usr/share/icons/hicolor/scalable/apps/mountain-logo.svg`
  - every `start-here*`/`distributor-logo*`/`applications-all*` file under `/usr/share/icons/We10X*` is a symlink to `mountain-logo.svg` or a Breeze icon (`readlink -f`)
  - `grep -aq mountain-logo /usr/share/icons/hicolor/icon-theme.cache`
  - the plymouth watermark (`/usr/share/plymouth/themes/spinner/watermark.png`) and the copy inside `initramfs.img` (`lsinitrd -f`) have the same md5 as `/usr/share/mountain/watermark.png`
- [ ] Step 2: `branding.sh`: append/replace `LOGO=mountain-logo` in os-release; render `watermark.png` (logo 96 px, `rsvg-convert`) to `/usr/share/mountain/` and copy over the spinner watermark.
- [ ] Step 3: `icons-finalize.sh`: link the We10X icons listed in Step 1 (svg → our logo; png variants removed); `gtk-update-icon-cache -f -t` for hicolor and every We10X* dir.
- [ ] Step 4: `recipes/common.yml`: `icons-finalize.sh` after `app-icons.sh`; `- type: initramfs` before `signing`.
- [ ] Step 5: commit `feat: Mountain logo on start button, menu, About and boot`.

### Task 2: Line-art mountain wallpaper (dark + light), login and lock screen

**Files:**
- Create: `tools/wallpaper.py` (generator, not used at build), `files/system/usr/share/wallpapers/mountain-peaks/metadata.json`, `.../contents/images/mountain-dark.svg` is NOT shipped — the build renders PNGs from `files/system/usr/share/mountain/wallpaper.svg` (dark) and `wallpaper-light.svg`
- Modify: `files/system/usr/share/mountain/wallpaper.svg`, `files/scripts/sddm-background.sh` (render 1920×1080, 2560×1440, 3840×2160 into `contents/images/` from light and `contents/images_dark/` from dark; keep `/usr/share/mountain/wallpaper.png` = dark 1920), layout.js (`Image` = `file:///usr/share/wallpapers/mountain-peaks/`), create `files/system/etc/xdg/kscreenlockerrc` (`[Greeter][Wallpaper][org.kde.image][General] Image=file:///usr/share/wallpapers/mountain-peaks/`, `[Daemon] Autolock=true Timeout=10 LockOnResume=true`)

- [ ] Step 1: phase 20 test: the 6 PNGs exist with the right sizes (`file` output), `metadata.json` valid JSON with `"Id": "mountain-peaks"`, kscreenlockerrc lines, layout.js points at the package, phases 10/12 still pass.
- [ ] Step 2: design (frontend-design skill): only thin lines — 40–70 stacked ridgelines forming peaks, each occluding the ones behind, a central twin peak echoing the logo; dark: deep navy → indigo background, lines pale cyan/white at 1.2–2 px (4K units) with depth fade; light: mist white background, slate lines. Generator prints the SVG; commit both SVGs (< 300 KB each).
- [ ] Step 3: render + view the PNGs locally; commit `feat: line-art mountain wallpaper (dark/light), login and lock screen`.

### Task 3: Windows-like start menu, names and top bar

**Files:**
- Modify: layout.js (kickoff favorites + config; drop appmenu, window title, net graph), `files/system/etc/xdg/menus/plasma-applications-merged/mountain.menu` and `applications-merged/mountain.menu` (Utilities/System directory overrides, Help/Waydroid `<Deleted/>`)
- Create: `files/system/usr/share/desktop-directories/mountain-accessories.directory`, `mountain-systemtools.directory`, `files/scripts/windows-names.sh` (sed `^Name=` in the listed desktop files: systemsettings → Settings, org.kde.dolphin → File Explorer, org.kde.konsole → Terminal, org.kde.plasma-systemmonitor → Task Manager, org.kde.kinfocenter → System Information; `NoDisplay=true` for kwalletmanager, kvantummanager, khelpcenter, input-remapper; skip missing files, fail if systemsettings/dolphin missing)

- [ ] Step 1: phase 21 test: the renamed `Name=` lines, NoDisplay lines, both menus valid XML containing `mountain-accessories.directory` and `<Deleted/>`, layout.js has `favorites` and no `appmenu`/`systemmonitor.net`.
- [ ] Step 2: kickoff favorites in layout.js: `preferred://browser`, Edge, File Explorer, Steam, Settings, Terminal, VS Code, OnlyOffice, Discord, Bazaar (IDs from the probe); `showActionButtonCaptions=true`; `systemFavorites` = `lock-screen,logout,suspend,reboot,shutdown`.
- [ ] Step 3: commit `feat: Windows-like start menu, app names and cleaner top bar`.

### Task 4: File Explorer feel and files that open on double-click

**Files:**
- Create: `files/system/etc/xdg/mimeapps.list` (images → Gwenview, PDF → Okular, text → KWrite, video/audio → Haruna, archives → Ark, office → OnlyOffice, folders → Dolphin), `files/system/usr/libexec/mountain-user-setup` (first-login: writes `~/.local/share/user-places.xbel` from the template if missing), `files/system/usr/share/mountain/user-places.xbel.in`, `files/system/etc/xdg/autostart/mountain-user-setup.desktop`, `files/system/etc/xdg/dolphinrc`, `files/system/etc/xdg/kservicemenurc`, `files/system/usr/lib/udev/rules.d/90-mountain-hide-system.rules`, `tests/test-user-setup.sh`
- Modify: `recipes/common.yml` (dnf: gwenview okular kwrite haruna ark if the probe shows them missing), `files/system/etc/skel/Desktop/files.desktop` (Name=This PC, Icon=computer), `files/system/etc/xdg/kdeglobals` (`DoubleClickInterval=500`), `build.yml` lint job (run test-user-setup.sh)

- [ ] Step 1: `tests/test-user-setup.sh` (runs in CI lint, HOME=tmpdir): after `mountain-user-setup`, xbel exists, is valid XML (`python3 -c xml.dom.minidom.parse`), has `kde_places_version>4<`, `GroupState-Remote-IsHidden>true<`, hrefs `file://$HOME/Documents` etc. and `desktop:/`; a second run leaves a user-edited file unchanged.
- [ ] Step 2: phase 22 test: every `Default Applications` value in mimeapps.list exists in `/usr/share/applications` (or is a Flathub id from the recipe), the udev rule file, dolphinrc, This PC.
- [ ] Step 3: implement; commit `feat: File Explorer places, This PC, files open in the right app`.

### Task 5: Fast Try VM and fast desktop

**Files:**
- Modify: `.github/workflows/try-mountain.yml` (QEMU from a Fedora container, `virtio-vga`, wallet off, double-click 800 ms), `try/mountain.html` (noVNC quality 6 / compression 2 kept, `showDotCursor` off), `files/system/usr/share/plasma/.../layout.js` (from Task 3), `recipes/common.yml` (`systemd`: disable `input-remapper.service`; user mask `kunifiedpush-distributor.service`), `files/scripts/branding.sh` (remove kdeconnect D-Bus activation file)

- [ ] Step 1: phase 23 test: `systemctl is-enabled input-remapper.service` → disabled, kunifiedpush user unit masked, no `org.kde.kdeconnect.service` D-Bus file, `firewalld` enabled, no `NOPASSWD` in `/etc/sudoers*`, kscreenlockerrc `Autolock=true` (security item 10 lives here too).
- [ ] Step 2: implement; vm-test (Task 6) measures RAM/boot/login/open times against the baseline.
- [ ] Step 3: commit `perf: faster Try VM display path and fewer background services`.

### Task 6: vm-test exercises real use

**Files:**
- Modify: `.github/workflows/vm-test.yml` (same Fedora-container QEMU as Task 5; `-qmp`; usb-tablet; branch `mountain-phases` kept)
- Modify: `docs/TESTING.md` (trend table)

Steps (each screenshots `NN-name.png`; core checks fail the run):
- [ ] login-to-desktop seconds (display-manager restart → `plasmashell` D-Bus up) and desktop RAM
- [ ] start menu: Meta → screenshot; type `settings` → screenshot; Enter → `systemsettings` process within 15 s
- [ ] File Explorer: `dolphin` opens; `dolphin "desktop:/Cloud Gaming"` screenshot (no `.desktop` endings)
- [ ] files: copy a PNG/PDF/TXT/MP4-less test set into `~looktest/Pictures|Documents`, `xdg-open` each as looktest → expected process (gwenview/okular/kwrite) within 20 s; close it
- [ ] drag: QMP drag of a desktop text file onto the Documents place in Dolphin (INFO; screenshot)
- [ ] Steam launches (process within 60 s, screenshot); GeForce NOW launcher opens Edge
- [ ] AI launchers: `MOUNTAIN_AI_DRYRUN=1` for all four (core), one real `codex` install in Konsole (INFO, screenshot)
- [ ] latency: Meta key → first changed frame (ms, 3 tries, median)
- [ ] logout via `qdbus6 org.kde.Shutdown /Shutdown logout` → session gone; then two clean reboots (existing)
- [ ] commit `test: vm-test clicks through real use with screenshots`

### Task 7: AI launcher feedback and final polish

**Files:** `files/system/usr/libexec/mountain-ai`, `tests/test-mountain-ai.sh`
- [ ] Step 1: test: offline message unchanged; dry-run prints `Installing … (first time only, about a minute)`; after a successful install it prints `Ready — starting …`.
- [ ] Step 2: implement; commit `feat: clearer AI launcher install messages`.

### Task 8: Ship

- [ ] `MOUNTAIN_PHASE: 24`; push `mountain-phases`; build + vm-test green; read report + every screenshot (design-critique on the screenshots, fix findings).
- [ ] PR to main, merge; wait for the main build; start Try Mountain on main; open the link in the built-in browser (page loads, password box shows — do not log in); give the owner the link + what-to-try list + rulings.
