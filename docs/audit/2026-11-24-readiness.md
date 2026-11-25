# Mountain readiness audit — 24 Nov 2026

Read-only audit of `main` at **af6f1d7** (v7.5 merged). Nothing was changed, built or merged.
Question: **how far is Mountain from a real OS that runs well on every system?**

**Update 25 Nov:** most gaps below are fixed and proven in the VM; see section 9. New average 2.46 (2.54 once the installer ISO is proven on main).

**Short answer (24 Nov): about 2.4 out of 5.** Mountain is a well-tested Windows 11 look on top of Bazzite. The desktop you see in the VM is solid (838 checks pass, 0 fail). It is not yet a full OS: there is no installer, browsers never update themselves, the nightly security suite on `main` is red, and nothing about real hardware (GPUs, sleep, battery, Wi-Fi chips, tearing) has been proven.

| Run / source | What | Result | Time (local) |
|---|---|---|---|
| vm-test 45345700383 (main, af6f1d7) | full suite, 341 shots | 838 PASS, 0 FAIL | 07:08–09:08 |
| vm-test 45385211772 (main, nightly) | security + attack + rollback + greenboot | **4 FAIL**, 218 PASS | 11:33–12:37 |
| vm-test 45414130278 (main, af6f1d7) | fresh full run for this audit | 838 PASS, 0 FAIL | 16:26–18:27 |
| Try Mountain 45414136379 (main) | live desktop link | link posted as commit status "Mountain link" | started 16:26 |
| Screens judged by hand | all 291 screenshots of run 45345700383, 3×3 contact sheets, zoom crops on every finding | 22 findings | 16:40–17:20 |

---

## 1. Architecture map (one page)

```
 Bazzite stable (ghcr.io/ublue-os/bazzite, Fedora 45 Atomic, KDE Plasma 6.5 Wayland, kernel 7.3 ogc)
   │   └─ bazzite-nvidia variant → recipes/recipe-nvidia.yml
   ▼
 recipes/common.yml (BlueBuild, one module list for both images)
   1 files        files/system → /   (configs, helpers, plasmoids, units, polkit)
   2 scripts      branding, kde-defaults
   3 dnf          ~30 packages: VS Code, greenboot, clamav, usbguard, orca …
   4 scripts      kvantum-glass, sddm-background, app-icons, windows-names, explorer-*,
                  desktop-drag-fix, lock-screen, process-table, desktop-labels,
                  icons-finalize, hardening, protection
   5 flatpaks     Firefox, Edge, Brave, Discord, Vesktop, OnlyOffice, Heroic, PikaBackup
   6 systemd      enable/disable/mask list (see Updates)
   7 initramfs, signing (cosign, SIGNING_SECRET)
   8 check-image.sh  (build fails if any image check fails)
   ▼
 ghcr.io/borisalv-marinov/mountain[:latest] and mountain-nvidia  — signed OCI images
```

**What Mountain adds**

| Layer | Pieces |
|---|---|
| Own windows (plasmoids, `org.mountain.*`) | Settings (multi-page QML), Run, Quick Settings, Win+X, Shut Down, taskbar space, Show desktop strip, keyboard-layout button; Start menu is `menu.11.enhanced` |
| Helpers (`/usr/libexec/mountain-*`, 31) | security, protect, protect-admin, protect-guard, snapshot, previous-versions, firewall, usbguard, flatpak-policy, app-permissions, accessibility, background, personalize, topbar, lite-mode, gamemode, gpu-check, taskmanager(+startup), run, winx, explorer, webapp, ai, phonelink, avatars, shortcuts, signed-origin, windows-boot, user-setup, settings-open |
| System units | snapshot.timer (hourly home snapshots), virus-definitions(-auto).timer, protect-guard (root), flatpak-policy, signed-origin, gpu-check, avatars(.path) |
| User units | mountain-protect (Active Protection watcher), mountain-gamemode, shutdown-dialog |
| Re-skinned KDE apps | Dolphin → File Explorer, plasma-systemmonitor → Task Manager, KWrite → Notepad, Gwenview → Photos, Okular → PDF Reader, Haruna → Media Player, Spectacle → Snipping Tool, KDE Connect → Phone Link |

**How Settings works.** One plasmoid (`org.mountain.settings/contents/ui/main.qml`). Each row runs a shell command through an executable data source (`run()` main.qml:157, `sh()` main.qml:162). Rows either call a `mountain-*` helper or write KDE config directly with `kwriteconfig6` / `qdbus6` (Night light, Lock screen, Notifications, Mouse, Default apps). Admin actions go through `pkexec` (polkit actions `org.mountain.protect`, `org.mountain.windows-boot`; firewall and USB guard use pkexec without their own policy file).

**How updates and rollback work.**
- System: `rpm-ostreed-automatic.timer` with `AutomaticUpdatePolicy=stage` (files/system/etc/rpm-ostreed.conf:3) downloads the new signed image in the background; it applies at the next restart. `uupd.timer` (Bazzite's updater, which also updates Flatpaks) is **disabled** (common.yml:101).
- Apps: **no automatic Flatpak updates at all**. vm-test even asserts that no `flatpak-*-update` timer exists (vm-test.yml:210).
- Signing: cosign key; `mountain-signed-origin` switches a rebase-installed PC to a signature-enforced origin.
- Rollback: Settings → Updates → "Go back to the previous version" runs `rpm-ostree rollback` (mountain-security:236); "Reset this PC" runs `rpm-ostree reset`. Greenboot rolls back after failed boots, but has **one** health check only (`10-mountain-signin.sh`).
- Files: hourly read-only Btrfs snapshots of home (24 + daily for 7 days) behind "Previous versions".

**How CI proves things.**

| Workflow | Trigger | Proves |
|---|---|---|
| build.yml | push, PR, daily 06:00 UTC | lint + unit tests, builds both images, `check-image.sh` inside the build, cosign signing |
| vm-test.yml | after main build, manual, nightly 01:30 UTC (security parts) | boots the real image in QEMU; 398 `chk` rows across parts gui, apps, taskmgr, security, attack, hardware (simulated Wi-Fi/BT/printer/controller), startapps, redraw, session, rollback, greenboot; OCR + colour rules (`tests/vm/uxcheck.py`), every window (`census.js`), screenshots |
| try-mountain.yml | manual | builds a qcow2 with bootc-image-builder and serves a live desktop over a Cloudflare tunnel |
| dependabot | weekly | GitHub Action pins |

**Install path.** There is no Mountain ISO or installer. The only way in is to install Bazzite (or another Fedora Atomic) and `rpm-ostree rebase`. The README's rebase commands point at `ghcr.io/blue-build/template:latest`, the BlueBuild template, not Mountain (README.md:16, :24).

---

## 2. What I saw, screen by screen

All proof is from run 45345700383 (`main`, 1280×800 unless noted). Shot names are in `shots/` of that run's `vm-test-report` artifact.

**Works well (checked, not assumed):** sign-in and lock screens (01–11), Start menu and search (12–20, 199–206), Settings pages incl. the new Accessibility page (21–64), Quick Settings (68–69), notifications (74–78), Run and Win+X (81–82, 114–117), snap flyout (83), clipboard (85–87), Explorer views (124–129, 131), Task Manager tabs (159–171), Security and Active Protection pages (182–189), Previous versions (191), simulated Wi-Fi / Bluetooth / printer / controller (193–198), Bulgarian Start menu and Shut Down (284, 287). Dark theme held on every Mountain window; uxcheck median luminance ≤ 0.30.

**Problems found (each with proof):**

| # | Screen | What is wrong | Proof |
|---|---|---|---|
| S1 | Settings → Network | "2.0 GB since you t…" spills out of the card and over the chevron | 25-settings-network, 34, 35, 193 (zoom crop) |
| S2 | Bulgarian | Task Manager titled "Мониториране на системата" (KDE name), columns and "End task" in English; Explorer titled "… — Dolphin"; sidebar "Recycle Bin / Versions / This PC" untranslated | 289-bg-taskmanager, 290-bg-file-explorer |
| S3 | Bulgarian | Labels cut off: "Самолетен ре…", "Икономия на …", "Нощна светли…", "Преглед н…", "Актуализациите са ръчни. Изпълнявайте ги, к…" | 285-bg-quick-settings, 288-bg-settings-home |
| S4 | File Explorer | Shows the Linux root (`bin boot dev etc …`) when "This PC" opens `/`; breadcrumbs `/ › home › looktest`; `remote:/` in the address bar; raw `.desktop` file names | 130-explorer-thispc, 133, 154, 135, 134, 142 |
| S5 | Task Manager | "Apps" list empty while apps are open; in other shots it lists only itself | 160, 169, 240, 289 vs 159, 168 |
| S6 | Task Manager | Users tab shows `root`; Services tab shows raw systemd text ("Merge System Extension Images into /usr/ and /opt/") | 164, 166 |
| S7 | Discord | Discord's window (class `com.discordapp.Discord`, 1280×720) shows a Firefox logo on a blank page | 251-every-com.discordapp.Discord (+ .json) |
| S8 | Branding | "Bazzite Portal", "Read the Bazzite Docs", "Manage Bazzite"; separate "Bazzite Updater"; About says "Mountain (based on Bazzite)" with no version; Info Center says "Mountain 45" | 211, 210, 55, 230 |
| S9 | Updates wording | Settings says "Updates are manual. Run them when you choose." but the system stages updates automatically | 22, 33, 90; rpm-ostreed.conf:3 |
| S10 | Remote desktop | KDE Desktop Sharing asks to allow "an unidentifiable application" remote control with **"don't ask next time" pre-ticked** | 236-every-org.kde.krfb |
| S11 | Btrfs Assistant | Start-menu app asks for **root's** password ("Authenticating as root"), which a normal user never has | 207-every-btrfs-assistant |
| S12 | Small screens | At 640×480 the taskbar app icons shrink to ~8 px dots (tray stays full size) | 177–180 (zoom crop) |
| S13 | Notepad | KWrite status bar "INSERT · en_US · Soft Tabs: 4 · UTF-8 · Normal" — not Windows Notepad | 103, 139, 237 |
| S14 | Clock | Time-zone label "UTC+00:00:01" (an extra second) | 14, 98, 227 |
| S15 | Settings layout | Night light sits under Accessibility, Typing under Bluetooth & devices (Windows: Display, Time & language) | 48, 50 |
| S16 | Accounts | Only "Your info" and "Sign-in options"; no add user, no family/other users | 28, 63 |
| S17 | Snipping Tool, Scanner, KFind, Kate, Info Center, Bazaar, Pika Backup | Plain KDE / GNOME layouts and wording, not Windows 11 | 92, 102, 229, 225, 230, 209, 255 |

**Things that looked wrong but are not product bugs (checked):**
- "Lock my screen after: Never" (59) — the test itself turns Autolock off (vm-test.yml:427); the image default is 5 minutes (`/etc/xdg/kscreenlockerrc`), and row "lock after 5 idle minutes" passes.
- Blue desktop in 40–67 — the test sets a solid-colour wallpaper.

**Test-quality findings (the tests pass but do not prove the thing):**

| # | Check | Why it proves less than it says | Proof |
|---|---|---|---|
| T1 | "shortcut Win+Left (snap)" PASS | Only measures time to the first redraw (`first=51 settle=73`), not where the window ends up | report row; 88-shortcut-yinaneft-(snap) |
| T2 | "shortcut Win+Tab (task view)" PASS | Shot "80-task-view-windows" shows "No Windows" | 79, 80 |
| T3 | Window census | Spectacle's overlay and earlier windows stay open across later census shots, so those shots judge a polluted screen | 244, 247–249, 254–255, 280–281 |
| T4 | Network page | 838 PASS while S1 overflow is visible on four shots: no rule checks text inside its card | 25, 34, 35, 193 |
| T5 | Nightly security suite | Marked "never counts for a merge", so it has been red on `main` without blocking anything | run 45385211772 row 1 |

---

## 3. Fresh run 45414130278

Started 16:26, finished 18:27, `main` af6f1d7, full suite.

| Result | Value |
|---|---|
| Rows | **838 PASS, 0 FAIL** (same as this morning's run) |
| Sign-in to desktop | 2 s |
| Start menu opens | 166 ms (median of 3) |
| plasmashell idle RAM | 972 MB (this morning 960 MB) |
| Archive and definitions rows | all PASS in the full suite; they fail only in the slower security-only suite (see B3) |
| Network page overflow (S1) | still there: "2.2 GB since you t…" outside the card — reproducible, not a one-off |

So the full suite is stable on `main`, and every screen finding above still stands.

---

## 4. Mountain against real operating systems

| Area | Windows 11 | Fedora KDE | Ubuntu 24.04+ | SteamOS 3 | Mountain today |
|---|---|---|---|---|---|
| Install and first boot | USB installer, OOBE, drivers via Windows Update | Anaconda ISO, live session, first-boot setup | Subiquity/Flutter ISO, live session | Recovery image for Steam Deck; desktop PCs unofficial | **No ISO.** Install Bazzite, then rebase; README points at the wrong image. First-login setup exists. Sign-in to desktop 3 s (VM) |
| Hardware (GPU, laptop, Wi-Fi, BT, printers, sleep, battery) | OEM drivers for almost everything, Modern Standby | Upstream kernel + Mesa; NVIDIA via RPM Fusion | Upstream + "additional drivers" for NVIDIA | Tuned for one device | Inherits Bazzite (good gaming kernel, NVIDIA image, gpu-check offers the right image). **VM proves only virtio**; Wi-Fi/BT/printer/controller only simulated (hwsim) |
| Updates and rollback | Monthly + feature updates, limited rollback (10 days) | dnf updates, no image rollback | apt + snaps auto-update | A/B image, automatic | Atomic signed image, staged automatically, one-click rollback, greenboot. **Flatpak apps (all browsers) never auto-update** |
| Security | Defender (on-access), SmartScreen, BitLocker, TPM, Secure Boot, VBS | SELinux, firewalld, LUKS option, Secure Boot | AppArmor, ufw (off), LUKS + TPM option, auto security updates | Read-only root, little else | SELinux enforcing, firewalld zones, Flatpak sandbox tightened, Active Protection (ClamAV, on-write), hourly snapshots, cosign. **Nightly suite red; scan after write; kernel lockdown off; LUKS only from Bazzite's installer** |
| Apps and games | Everything, incl. anti-cheat | Flathub + RPM | Snap + apt | Steam (Proton), desktop mode Flatpaks | Steam/Proton, Heroic, Lutris, cloud gaming, Edge, OnlyOffice, VS Code, AI CLIs. Kernel anti-cheat games (GTA Online, Valorant) do not run; Settings says so |
| Accessibility | Narrator, Magnifier, filters, captions, voice access, high contrast | Orca, KWin zoom, high contrast themes | Orca, high contrast, large text | Basic | Orca, magnifier, colour filters, pointer size, sticky keys, animations (v7.5). **No high-contrast theme, captions, voice access** |
| Languages | 100+ display languages | 100+ | 100+ | ~25 | **English + Bulgarian**, with untranslated and cut-off strings in Bulgarian |
| Recovery when broken | WinRE, Reset this PC, recovery USB | Older kernels in GRUB, live USB | Live USB | Recovery image | Previous deployment in GRUB, greenboot auto-rollback, Reset this PC, Previous versions. **No recovery media of its own** |
| Performance | Tuned per OEM | Good | Good | Excellent on Deck | VM: Start opens 164 ms, apps 0.4–0.9 s, plasmashell 960 MB RAM idle (high), clamscan 658 MB while scanning. Real-hardware numbers: none |

---

## 5. Score: how far from a real OS that runs well on every system

**Rubric (same for every area)**

| Score | Meaning |
|---|---|
| 0 | Missing |
| 1 | Exists but broken, or no test proves it |
| 2 | Works for the happy path in the VM; real hardware or key cases unproven |
| 3 | Works and is tested in the VM with known gaps; on par with one reference OS in the VM's view |
| 4 | 3, plus proven on real hardware on at least one machine per class (Intel/AMD/NVIDIA, desktop/laptop) |
| 5 | On par with Windows 11 and proven on a real hardware matrix |

No area can score above 3 today, because there is no real-hardware evidence in the repo for any area.

| Area | Score | Evidence it rests on | Holds it back |
|---|---|---|---|
| Install and first boot | **1** | README.md:16,24; no ISO in repo; login-to-desktop 3 s row | No installer; README installs the wrong image |
| Hardware support | **2** | Bazzite base; hwsim rows (Wi-Fi, BT, printer, controller) pass; gpu-check unit | Nothing proven on real GPUs, laptops, sleep, battery, Wi-Fi chips |
| Updates and rollback | **3** | rpm-ostreed.conf:3; rows "updates: automatic timer enabled and active", rollback and greenboot parts pass | Flatpak apps never update; one greenboot check; "manual" wording wrong |
| Security | **2** | 218 PASS in nightly, attack table rows, SELinux/firewall/sandbox rows | 4 FAIL on nightly `main`; browsers unpatched; scan after write; krfb pre-ticked consent |
| Stability | **3** | 838 PASS / 0 FAIL full run; crash-probe log; 2 clean runs per merge rule | Task Manager Apps list flaky (S5); no long-run soak test |
| No tearing | **2** | `AllowTearing=false` checks in image | Can only be proven on real hardware (testufo) — not done |
| Windows 11 style | **3** | 291 shots judged; Mountain windows consistent and dark | S1, S4, S8, S13, S17; KDE/GNOME apps still look like themselves |
| Contrast | **3** | uxcheck luminance and OCR rules pass | No WCAG contrast measurement per text element; S3 cut text |
| Apps and games | **3** | every-app census (51 apps open, dark, no error text); Steam/Heroic/Lutris/GeForce NOW shots | Kernel anti-cheat games; no game was actually played in CI |
| Accessibility | **2** | Accessibility page rows, magnifier and colour-filter shots (65–67) | No high contrast, captions, voice access; Orca reading only lightly tested |
| Languages | **2** | Bulgarian rows ("Bulgarian translations installed 566"), bg shots | Two languages; S2, S3 |
| Recovery | **3** | rollback/greenboot parts, Previous versions shot 191, Reset this PC row | No recovery media; greenboot blind to a black screen |
| Performance | **2** | perf rows (Start 164 ms, app open times, idle RSS) | VM only; 960 MB plasmashell; no boot-time or battery numbers on hardware |

**Average 2.4 / 5.** The VM-visible layer is around 3. Everything that needs real hardware or a first install is 1–2.

---

## 6. What is needed, ranked

Order inside each group follows the owner's rule: stability → no tearing → Windows 11 style → contrast → glass. Size: S ≈ a day, M ≈ a few days, L ≈ a week or more.

### Blockers (data loss, won't install/boot, security)

| # | Problem | Proof | User impact | Size | Test that proves it fixed |
|---|---|---|---|---|---|
| B1 | No installer, and the README's install commands point at the BlueBuild **template** image | README.md:16, :24; no ISO/anaconda config in repo | A new user cannot install Mountain; following the README installs a different OS | M (try-mountain already runs bootc-image-builder; add its `anaconda-iso` target) + S (README) | CI job builds the ISO, installs it to a blank QEMU disk unattended, then runs vm-test against the installed disk; `grep -q borisalv-marinov/mountain README.md` |
| B2 | Browsers and every Flatpak app never update by themselves | common.yml:101 (uupd disabled); vm-test.yml:210 asserts no flatpak update timer | Firefox/Edge/Brave/Discord stay on old, exploitable versions until the user clicks Updates | S | Unit check: a Flatpak-only update timer enabled; VM: install an older Flatpak commit, run the timer, version goes up |
| B3 | Nightly security suite on `main` is red: definitions timer never ran after boot, and 3 Active Protection archive checks fail (EICAR past 500 MB in a zip, password-protected zip, EICAR behind an encrypted member) | run 45385211772: rows "definitions: the timer is on … `enabled 0`", "Active Protection: EICAR after 500 MB …", "… password-protected zip …", "… behind an encrypted member …" | Virus protection may run with no definitions; archive tricks may slip past. The archive FAILs may be a knock-on of missing definitions on the CI runner (PLAUSIBLE, not confirmed) | M | Nightly suite green twice in a row; remove the "never counts for a merge" exemption |

### Major gaps

| # | Problem | Proof | User impact | Size | Test |
|---|---|---|---|---|---|
| M1 | Active Protection scans after a file is written, so a fast double-click can open a threat first | nightly row "QA known limit: a double-click 1 s after … opens it" | Malware in Downloads can run before it is caught (Defender blocks on open) | M (fanotify permission events on watched folders) | VM: EICAR dropped then opened within 100 ms is blocked |
| M2 | Real hardware never tested: GPUs, tearing, sleep, battery, Wi-Fi, multi-monitor | see "Needs real hardware" | Unknown whether Mountain works on the owner's or anyone's PC | L | Owner-run `mountain-report.txt` + testufo on each machine class, stored in docs |
| M3 | Greenboot has one check (sign-in service) | `/usr/lib/greenboot/check/required.d/10-mountain-signin.sh` only | A broken GPU driver or black screen with the service up never rolls back | M | VM: break plasmashell start in a test deployment → greenboot rolls back |
| M4 | KDE Desktop Sharing remote-control prompt pre-ticks "allow without asking next time" | 236-every-org.kde.krfb | One careless click gives permanent remote control | S (ship krfb off, or default the box unticked) | VM: krfb prompt shot shows box unticked, or krfb not installed |
| M5 | Task Manager "Apps" list empty or incomplete | 160, 169, 240, 289 | Users can't find or end a frozen app — the main job of Task Manager | S–M | VM: open 3 apps → Apps list shows all 3 by name |
| M6 | Discord window shows a Firefox logo | 251 + .json | Discord may not start, or start the wrong app | S to diagnose | VM: Discord window OCR shows Discord UI |
| M7 | Updates: "manual" wording while updates stage automatically; second "Bazzite Updater" app | 22, 33, 90, 210; rpm-ostreed.conf:3 | User can't tell whether the PC is up to date; two update apps | S | uxcheck text rule on Updates card matches the real policy; one update entry in Start |
| M8 | Explorer shows Linux internals (root folders, `/home/…` breadcrumbs, `remote:/`, `.desktop` names) | 130, 133, 134, 135, 142, 154 | Breaks the Windows illusion; risk of users opening system folders | M | census rule: no breadcrumb starting with "/", no ".desktop" in Explorer OCR |
| M9 | Network page text overflows its card | 25, 34, 35, 193 | Looks broken on a core page | S | uxcheck rule: text bounding boxes stay inside card bounds |
| M10 | Bazzite branding visible (Portal, Updater, About, Info Center "Mountain 45") | 55, 210, 211, 230 | Confusing; support questions go to the wrong project | S–M | OCR rule: "Bazzite" never appears on any census shot |
| M11 | Bulgarian: untranslated strings and cut-off labels | 285, 288, 289, 290 | Bulgarian users see a half-English, clipped UI | M | bg census: OCR finds no English UI words from a list; no "…" on Quick Settings labels |
| M12 | Btrfs Assistant asks for root's password | 207 | App unusable; teaches users to look for a root password | S | VM: polkit prompt says "Authenticating as looktest", or app hidden |
| M13 | plasmashell 960 MB idle; clamscan 658 MB while scanning | report rows "plasmashell idle RSS", 159 | Weak PCs (4–8 GB) feel slow | M | perf row with a ceiling (e.g. plasmashell ≤ 600 MB) that fails the run |
| M14 | Accessibility short of Windows: no high-contrast theme, no live captions, no voice access | 31, 64 | Low-vision and deaf users lack tools they rely on | L | Settings rows + VM shots per feature |
| M15 | Two languages only | 49 | Not usable outside English/Bulgarian speakers | L | language census per added language |
| M16 | Tests that pass without proving: Win+Left, task view, census pollution, no in-card text rule, red nightly ignored | T1–T5 | Regressions ship while CI is green | M | each row asserts the outcome (window geometry, window count, clean screen per census shot) |

### Polish

| # | Problem | Proof | Size | Test |
|---|---|---|---|---|
| P1 | Notepad status bar is KWrite's (INSERT, Soft Tabs) | 103, 139, 237 | S | OCR: no "INSERT"/"Soft Tabs" on Notepad shots |
| P2 | Clock shows "UTC+00:00:01" | 14, 98, 227 | S | OCR rule on clock tooltip |
| P3 | Task Manager shows `root` user and raw systemd service text | 164, 166 | S | OCR rule on Users/Services tabs |
| P4 | Night light under Accessibility; Typing under Bluetooth & devices | 48, 50 | S | Settings breadcrumb check |
| P5 | About has no Mountain version number | 55 | S | About shot shows "Mountain 7.x (build …)" |
| P6 | Accounts page has no add-user / other users | 28, 63 | M | Settings row + VM add-user flow |
| P7 | Taskbar icons shrink to dots on very small screens | 177–180 | S | 1024×600 shot: icon width ≥ 24 px |
| P8 | Snipping Tool, Scanner, KFind, Kate, Bazaar, Pika Backup keep KDE/GNOME layouts | 92, 102, 229, 225, 209, 255 | L | per-app census style rules |

---

## 7. Needs real hardware (cannot be proven from a VM — none of these are counted as passing)

- GPUs: NVIDIA (proprietary driver on the nvidia image), AMD, Intel — driver loads, games run, Wayland session stable.
- Tearing and frame pacing (`AllowTearing=false`), including in games — testufo on the owner's PC.
- VRR, HDR, high refresh rate, multi-monitor, mixed scaling, docks/USB-C displays.
- Sleep and resume (s2idle/S3), lid close, hibernate.
- Battery life, power profiles, brightness keys, thermals and fan noise.
- Wi-Fi chips (Intel, Realtek, MediaTek, Broadcom), Bluetooth audio (A2DP, LE Audio), Bluetooth controllers.
- Touchpad gestures, touchscreens, pen.
- Webcams, fingerprint readers, IR cameras (Windows Hello equivalent).
- Real printers and scanners (only a simulated printer is tested).
- Secure Boot with MOK enrollment, LUKS disk encryption, TPM unlock.
- Game performance against Windows on the same PC; anti-cheat behaviour.
- Boot time and idle RAM/CPU on a real SSD and CPU.

---

## 8. What this audit did not check

- Source code line by line (bugs inside helpers); this was a user-view and evidence audit.
- The live Try Mountain desktop: the site password is the owner's, so I did not sign in.
- Accessibility for screen-reader users beyond what screenshots show.
- Contrast ratios per text element (only the luminance rule in uxcheck).

---

## 9. Fixed after the audit (24–25 Nov, branch `v76-readiness`)

The owner said go on 24 Nov. Everything below is proven in the VM unless it says otherwise. Proof runs: full vm-test **45504419944** (877 PASS / 0 FAIL) and security suite **45504432410** (228 PASS / 0 FAIL), both on 53bb7b8.

| Gap | What changed | Proof |
|---|---|---|
| B1 installer | `iso.yml` builds an installer ISO (Btrfs, Anaconda), installs it unattended in QEMU, boots the installed disk and checks it; the release ISO (no test user) is published in parts as `iso-<date>`. README now installs Mountain, not the template | **Not proven yet.** The workflow can only run from `main`; it runs by itself after the merge. Until its `iso-report` passes, B1 stays open |
| B2 app updates | Flatpak apps (all browsers) update once a day, system and user, at low priority, never offline or on a metered network | rows "app updates timers enabled and active"; `tests/test-app-updates.sh`; check_phase48 |
| B3 nightly red | definitions start ~1 min after boot (random delay 5 min → 20 s); archive rows wait for the scan event, not a fixed sleep | security suite 228/0 |
| M3 greenboot | second required check: the sign-in screen must really come up (bounded 150 s wait) | row "greenboot health check result = success" |
| M4 krfb | Desktop Sharing removed from the image | row "krfb gone"; check_phase48 `assert_no_rpm krfb` |
| M5 Task Manager Apps | apps started outside app scopes are listed; system users hidden. Half of the finding was the test itself (it opened raw `dolphin` in `systemd-run` units) | rows "Task Manager Apps lists …"; `tests/test-taskmanager.sh` |
| M7 / M10 wording, branding | Updates text says what happens ("download by themselves and install when you restart"); Bazzite Portal hidden; About shows "Mountain 7.6 (build 20261124)"; Info Center no longer says "Mountain 45" | OCR rules settings-home/updates (no "are manual"), settings-about (no "Bazzite"), kinfocenter (no "Mountain 45"); os-release row |
| M8 Explorer internals | "/" opens This PC; paths resolve to places (Desktop → desktop:/); no root folders, `/home/…` crumbs or `.desktop` names | OCR rules explorer-thispc, pictures-folder, explorer-launchers; `tests/test-explorer.sh` |
| M9 Network overflow | Data usage on its own line inside the card | OCR rule "used since start", no "since you t" |
| M11 Bulgarian | the Bulgarian catalog really loads now (Plasma overwrote LANGUAGE; Settings writes `bg@mountain:bg:en_US`); Task Manager, Explorer places and Settings strings translated; Quick Settings labels wrap; Bluetooth card stacks its button when narrow | OCR rules bg-taskmanager ("Диспечер"), bg-settings-home ("Всички устройства") |
| M16 tests that passed without proving | Win+Left asserts the window geometry (0 / 50 % / 100 %); Task view must list the open window; census closes every window between apps; boot-time row waits for `is-system-running` | rows "Win+Left snaps …" `SNAP\|0\|50\|100`, "Task view lists the open window" |
| P1 Notepad | status bar keys hidden (no INSERT / Soft Tabs) | OCR rule on notepad shots |
| P2 clock | `/etc/localtime` link made when missing (UTC+00:00:01 came from no zone file) | OCR rule on clock shots |
| P3 Task Manager root/services | system users (uid < 1000) hidden | `tests/test-taskmanager.sh` |
| P4 Settings places | Night light under System, Typing only under Time & language | `tests/test-settings.sh` |
| P5 About version | done (see M10) | settings-about rule |

**Corrections to the audit.** M12 (Btrfs Assistant asks for root's password) was the test account: `looktest` is not in `wheel`, so polkit falls back to root. The first account made at install is an admin (wheel) and gets its own password prompt. S4 and part of M5 were the test too (raw `dolphin`, units the Task Manager rightly does not call apps).

**Found and left open.**

| Item | Why it is open |
|---|---|
| Edge aborts while exiting, in its Flatpak sandbox helper (zypak: `Assertion 's->floating' failed … event_free()` from `exit()`) | Seen in 2 of 8 full runs on the branch, after a normal close. Main's test force-killed Edge, so the exit path never ran there; an A/B of 4 quick runs (2 branch, 2 main, 25 Nov) had no crash on either side. The stack is all `exit()` → zypak → libsystemd, nothing of Mountain's. Upstream Edge-Flatpak bug; the test counts exactly this abort in its own row (`tests/vm/crashes.sh`), any other Edge crash still fails. A user may see a crash notice after closing Edge |
| P6 "Other users" in Accounts | The only way today opens a KDE System Settings window, which the image rule forbids (one Windows style). Needs Mountain's own add-user page |
| M1 scan before open | Needs fanotify permission events: a bigger change, not started |
| M6 Discord shows a Firefox logo, P7 tiny taskbar icons, P8 KDE/GNOME app layouts | Not started |
| M13 memory (plasmashell ~970 MB) | Not started |
| M14 high contrast, captions, voice access; M15 more languages | Out of scope by the owner's go (no new languages, captions or voice) |
| M2 real hardware | Needs the owner's PCs |

**Scores now.** Security 2 → **3** (nightly green, browsers update, krfb gone; scan-after-write still open). Install stays **1** until the ISO test passes on `main`, then **2**. The rest are unchanged (they are capped at 3 without real hardware, or the open items above hold them). **Average 2.46 / 5** (32 / 13), **2.54** once the ISO is proven.
