# Mountain v6 (was v5.1): "Smooth, sharp, Task Manager, unbreakable, complete" master prompt

Use superpowers: brainstorming → writing-plans → subagent-driven-development → verification-before-completion. Use ponytail full. Use the design skills (frontend-design, design-critique, accessibility-review) for every visual piece. Model choice:
- Cheap subagent models where the plan has full code.
- Mid-tier for reviews.
- The most capable model for design, security architecture and the final review.

Do not stop to ask between tasks. Make rulings and log them. The owner is non-technical: always keep a live task list and a status table (⏳ 🕓 ✅ 🔍 🔧 ☁️), and keep messages short and plain.

**Branch:** `mountain-v5.1` from `main`. v5 is merged ([PR #17]). Its prompt is `docs/superpowers/prompts/2026-11-12-mountain-v5-black-glass-master-prompt.md`; read its "Where things are" and "Constraints" sections, which still apply. Image checks end at the phase v5 left (see `MOUNTAIN_PHASE` in `.github/workflows/build.yml`); add phases and never weaken old ones.

**Owner's screenshots of v5** (in `C:\Users\marin\Desktop\Operating System\mountain-v51-refs\`):
- `v5-quick-settings-no-brightness.png`: the quick settings flyout has no brightness slider.
- `v5-file-explorer-issues.png`, problems visible:
  - truncated labels ("Docume…", "Recycle B…", status bar "9 f…ers")
  - the tab bar floats oddly in the middle of the toolbar
  - the window is so transparent that content behind it ("Sign in") bleeds through
  - text is low-contrast on glass
  - the whole picture looks soft and not sharp

## Owner's words (verbatim)

> PHOTO ONE ADD BRIGHTNESS ITS NOT SMOOTH EXPERIENCE SWITCHING OPENING FILES DOESN'T FEEL LIKE WINDOWS OR MAC FEELS MAKE SURE IT RUNS SMOOTH NOT SO MUCH CONTRAST YOU NEED TO ADD MORE CONTRAST the ui doesn't feel sharp on my screen there is no task manager i need a pure task manager like a built in system one that gives info and a protection against threats open source or not brainstorm for one i want nearly unbreakable system too that is going to hold to any attack that is for 5.1v

(Lightly spell-corrected. "Not so much contrast, you need to add more contrast" means the UI is too washed-out and see-through; it needs clearer, higher-contrast text and surfaces.)

## What to build (all of it)

### 1. Brightness in quick settings
- Add a brightness slider (PowerDevil's screen-brightness backend) and keep the volume slider.
- Laptops and desktops with DDC/CI monitors: the real backlight.
- When no brightness control exists (VMs, some desktops): show the slider disabled with "Not available on this display", never a missing gap.
- Night light tile stays.
- vm-test: screenshot the flyout, and check that the slider exists.

### 2. Smooth: switching and opening files must feel like Windows/Mac
**Measure first, in vm-test:**
- time from double-click to a window on screen: a file in File Explorer, a photo, a PDF, a text file, a folder
- Alt+Tab and window switching
- the minimize/maximize animation
- frame pacing while dragging a window (KWin's `showfps`, or the compositor timing in the journal)

**Then fix the causes:**
- Animations: short and eased like Windows 11 (open and close about 150–200 ms, no laggy fades).
- Disable effects that cost frames.
- File Explorer: preload thumbnails, avoid the slow Information panel recompute on every click (debounce or a lighter panel), and open folders in the same window.
- Preload or keep-alive only where measured worth it, for example the Dolphin daemon.
- Check that blur strength isn't redrawing too much.

**Budgets** (fail vm-test on a regression over 20 %):
- double-click → window ≤ 500 ms warm
- folder navigation ≤ 150 ms
- Alt+Tab ≤ 100 ms

### 3. Contrast and sharpness
**Glass:**
- Much less transparency on windows and app surfaces: content behind must not read through.
- Keep blur and see-through mostly for the taskbar, start menu and flyouts.
- Text and icons: WCAG AA at minimum, AAA for body text where possible; run accessibility-review on every screenshot.
- Stronger separation between sidebar, content and toolbar.

**File Explorer layout:**
- no truncated sidebar labels (wider default sidebar or shorter names)
- a status bar that doesn't truncate
- the tab bar where Windows 11 has it (in the title row), or hidden while there is only one tab
- toolbar items aligned

**Sharp text and icons:**
- Font rendering: hinting, subpixel or grayscale, a font that is crisp at 100 % and 125 %.
- Icon sizes at whole pixels, no fractional scaling blur in Kvantum or SVG themes.
- Check at 1280×800 and 1920×1080.

**Try Mountain:**
- The owner sees the VM through noVNC, which scales and compresses the picture, so make the browser view sharp too.
- Use the owner's browser window size where possible (`resizeSession`, or a VM resolution matching the window), no blurry downscaling (`scaleViewport` only when it must), and quality and compression tuned for crisp text.
- Explain in `docs/TRY-MOUNTAIN.md` what remains soft only because of the remote view.

### 4. Task Manager (built in, like Windows)
- **Brainstorm first.** Compare extending Plasma System Monitor (rename, our own pages, faces), Mission Center (Flathub), Resources (Flathub) and a small own app. Pick the most native, lightest and most reliable option; log the ruling.
- **Requirements:**
  - Name "Task Manager"; Ctrl+Shift+Esc opens it; it's in the start menu and in the taskbar right-click menu.
  - Tabs like Windows 11:
    - Processes: apps and background processes, CPU/RAM/disk/network/GPU per process, End task.
    - Performance: CPU, RAM, disk, network and GPU graphs, with model names.
    - App history.
    - Startup apps, with enable/disable that really changes autostart.
    - Users.
    - Details.
    - Services: systemd, start/stop with an admin prompt.
  - Black-glass styling, fast to open (≤ 500 ms warm), light while open.
- vm-test: Ctrl+Shift+Esc opens it; screenshot every tab; End task on a test process works; disabling a startup app removes it from the next login.

### 5. Protection against threats (like Windows Security)
- **Brainstorm the options**, open source preferred and closed source allowed if it's clearly better and free for personal use. Log the ruling. Options to weigh:
  - ClamAV with on-demand and scheduled scans (clamd/freshclam, plus an on-access option weighed against its RAM cost)
  - ClamTk or our own front end
  - rkhunter/chkrootkit
  - USBGuard (careful with gaming peripherals)
  - firewalld status
  - Flatpak permission review (Flatseal)
  - fail2ban (only if a service listens)
- Build **one "Security" page/app** in the Settings app (Windows Security style). It shows, with green/yellow/red status and one-click fixes:
  - Virus & threat protection (last scan, Scan now, quarantine)
  - Firewall (on, zone `mountain`)
  - App & browser protection (Flatpak sandbox, permissions)
  - Device security (Secure Boot, TPM, SELinux enforcing, kernel lockdown)
  - Updates (last update, rollback available)
  - Account protection (password set, screen lock on)
- Virus definitions update **only when the owner runs Updates or Scan now**; no background downloads, which was the owner's earlier rule. Say this in the UI.
- Must not hurt gaming: no on-access scanning of Steam or Proton paths by default; measure RAM and CPU before and after.

### 6. Nearly unbreakable system
**Threat-model first** (write it in the plan):
- remote attack
- malicious app or download
- malicious USB
- stolen laptop
- broken update
- user mistake
- ransomware

**Build on what Mountain already is:** an image-based, read-only `/usr` (bootc/ostree) with automatic rollback. Then add, each with its undo step in `docs/OWNER-GUIDE.md`:
- **Updates and rollback:** signed images verified on update (cosign policy, already signed), the previous image always kept, plus a one-click "Go back to the previous version" in Updates and the boot menu.
- **Boot:** Secure Boot support documented (Bazzite's MOK key), with a status check in the Security page.
- **Data:** disk encryption (LUKS) recommended at install, with a guide. Btrfs snapshots of `/home` (snapper or a timer) with restore from File Explorer: ransomware and mistake protection.
- **Hardening, layered:**
  - SELinux enforcing
  - firewalld zone `mountain` (no open ports by default)
  - Flatpak sandbox defaults tightened (no `--filesystem=home` where not needed)
  - kernel lockdown (integrity) if it is gaming-safe
  - the hardened sysctls from v4
- **Accounts:** screen lock on, `sudo` asks for a password, and no passwordless admin in the shipped image.
- **Tested in vm-test:**
  - roll back works
  - a file deleted in `/home` is restored from a snapshot
  - the firewall blocks an incoming port
  - a Flatpak can't read `~/Documents` without permission
  - Steam, Proton and the web apps still work

### 7. Keep everything else green
All v5 checks and vm-test steps stay green: lock screen, Hello greeting, Settings, quick settings, File Explorer title and Details pane, drag icons, files open, Steam, AI CLIs, web apps, reboot.

## Testing and done

- Each task: TDD where possible, an image-check phase, vm-test with screenshots. Look at every screenshot yourself and compare it with the owner's screenshots above.
- Full pass at the end: all v5 and v5.1 checks green, budgets met, numbers recorded in `docs/TESTING.md`.
- Merge to main (the owner authorized it once everything is green).
- Start Try Mountain from main, open the link in the built-in browser, confirm the page loads (never type passwords there), then give the owner:
  - the link
  - a "what to try" list: brightness, smoothness, Task Manager with Ctrl+Shift+Esc, the Security page, rollback
  - the rulings

## Constraints

Everything in the v5 prompt's Constraints section, plus:
- Security changes must not break gaming. Anything risky is opt-in with a clear switch.
- Never weaken the shipped image for convenience; the Try-VM-only relaxations stay in `try-mountain.yml`.
- Commit trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; PR bodies end with the Claude Code line.
- Don't flood the GitHub API: one `gh run watch` per run, no tight polling loops. The rate limit was hit once.

# Addendum (owner, 2026-11-12 evening): make Mountain complete. Sections 8-19. v5.1 was renamed to v6.

Start menu feedback (`v5-start-menu-blank.png`): Pinned has only 2 rows above a big empty gap, Recommended is empty, the bottom bar floats far below. Fix like Windows 11: 18 pins (3 rows) with a page indicator or sized to content; Recommended never blank (recent files, new apps; recent-file tracking on for new users; one calm hint line when truly empty); no dead space at 1280x800 and 1920x1080; "Visual Studio" -> "VS Code"; "Welcome" not pinned; screenshot on a fresh account and after opening files.

Append this to `docs/superpowers/prompts/2026-11-12-mountain-v5.1-smooth-secure-master-prompt.md` as sections 8–19 and commit it. Everything here is part of v5.1. The same rules apply: brainstorm and research first, open-source community solutions first, measure, test each item in vm-test with screenshots, review, and merge only when everything is green.

## Owner's words (verbatim)

> Okay, out all this, I'm still not gonna install it on my PC yet. It's not time. It should have protection against threat. It should already be polished enough to be running. This is already better. It doesn't look like Windows. It doesn't feel like Linux. Like it's something very the shit in between. You understand me? It should look good like Windows. It should be black themed, like glass themed, but it should look like a Windows still, so people will be familiar with it. Just do everything I told you there into 5.1, and everything in between that will make mounting complete, make it a big ass prompt.

Earlier tonight, about the start menu: "look at the win menu how blank it is, fix that". Screenshot: `v5-start-menu-blank.png` in this folder. The details went to the session already.

## North star (the top rule for every decision in v5.1)

**Mountain must look like Windows 11 at first glance, in a black glass skin.**
- Same shapes, positions, sizes, spacing, icons style, names and behaviour as Windows 11.
- The material is the black glass from the v5 refs. Use glass as an accent material; don't drift into a "Linux theme" look.
- **Today's verdict from the owner: "in between".** It doesn't look like Windows and doesn't feel like Linux.

Fix this:
1. Put a v5 screenshot of each surface next to the matching Windows 11 surface: taskbar, start menu, File Explorer, Settings, quick settings, notifications, context menus, dialogs, title bars, Alt+Tab, lock screen.
2. List every difference in shape, spacing, size, font, icon, naming and behaviour.
3. Close the differences. Keep black glass as the material.

Details:
- **Font:** Segoe-like. Use an open font that is metric-close and crisp, such as Selawik (MIT, Microsoft's open Segoe UI fallback), Inter or Noto Sans, and log the ruling.
- **Sizes:** Windows 11 sizes (taskbar 48 px, start menu 640×~720, corner radius 8 px).
- **Icons:** Fluent-style icons (open Fluent icon themes, kept within license).
- **Behaviour:** the Windows hover, press and selection visuals.
- Run design-critique against the Windows reference on every surface until the answer is "looks like Windows 11 in black glass".

The owner is **not installing on a real PC yet**. Do not build an installer this round. Everything must be polished and fully working in Try Mountain and vm-test.

## 8. Protection against threats

This is required, not optional (see section 5 of the main prompt): a Windows Security–style page with real antivirus scanning, firewall, device security and update/rollback status. Make sure it is actually done, working and tested this round.

## 9. Bulgarian and languages

The owner writes Cyrillic; their folder names are Bulgarian.
- A Bulgarian keyboard layout available (BG phonetic and BDS), switching with Win+Space and Alt+Shift, and a language indicator in the taskbar ("ENG"/"БЪЛ") like Windows.
- Cyrillic renders correctly everywhere: file names, menus, the lock screen.
- The UI stays in English by default, with Bulgarian selectable in Settings → Time & language. The "File Explorer" title must still work, or be translated there.

## 10. Windows keyboard shortcuts (all must work; test each in vm-test)

| Shortcut | Action |
|---|---|
| Win | Start menu |
| Win+E | File Explorer |
| Win+I | Settings |
| Win+A | Quick settings (failed in v5 vm-test: fix it) |
| Win+N | Notification center |
| Win+D | Show desktop |
| Win+L | Lock |
| Win+Tab | Task view |
| Win+Shift+S | Snipping tool region capture to the clipboard, with a notification |
| PrtSc | Full screenshot |
| Win+V | Clipboard history |
| Win+. | Emoji picker |
| Win+Z | Snap layouts |
| Win+Arrows | Snap |
| Alt+Tab | Switch windows |
| Ctrl+Shift+Esc | Task Manager |
| Alt+F4 | Close, then the shut down dialog on the desktop |
| Win+R | Run |
| Win+X | Power-user menu |

## 11. Everyday apps, Windows-named and black-glass styled

Pinned and in All apps, each with the right icon and file associations:

| App | Built from | Also |
|---|---|---|
| Notepad | KWrite or Kate in simple mode; VS Code stays for code | |
| Calculator | KCalc or GNOME Calculator; pick the cleaner one | |
| Photos | Gwenview | |
| Media Player | Haruna | |
| Camera | Kamoso or Snapshot | |
| Clock | KClock (alarms, timer, stopwatch) | |
| Snipping Tool | Spectacle | Win+Shift+S |
| Paint | KolourPaint | |
| Sound Recorder | | |
| Calendar | Merkuro | Optional: weigh its RAM |
| Weather | | Only if it costs nothing in the background |

Use Fedora packages or Flathub. Rename them through `.desktop` overrides, as v4 and v5 did.

## 12. Notification center and widgets

- **Notification center (Win+N):** the Windows 11 look, with the calendar below the notifications, opened by clicking the clock. Do Not Disturb sits there.
- **Widgets (Win+W):** a glass panel with weather, calendar and system stats. Optional; weigh its cost and keep it light.

## 13. Start menu completeness (with the blank-menu fix already sent)

- **Pinned:** 18 pins, with a page indicator.
- **Recommended:** recent files and new apps, never blank.
- **All apps:** A–Z with letter headers.
- **Bottom bar:** the account menu (Change account settings, Lock, Sign out) and the power menu (Sleep, Shut down, Restart).
- **Search:** finds apps, settings, files and calculations ("2+2"), like Windows.

## 14. Taskbar completeness

- **Right-click the taskbar:** Taskbar settings and Task Manager.
- **Right-click an app:** a jump list (recent files) and Pin/Unpin.
- Hover previews of windows.
- A Show-desktop sliver at the far right.
- **Tray:** the language indicator, the quick-settings group, the clock with two lines, and a notification badge.

## 15. Backup and recovery

- **"Reset this PC":** Settings → System → Recovery. Keep files or remove everything; document what it does on an image-based system.
- **"Go back":** the previous image, in Settings → Recovery and in the boot menu, tested in vm-test.
- **File History:** Btrfs snapshots of `/home` (see section 6). Restore from File Explorer through right-click → "Restore previous versions".

## 16. Phone and cloud

- **Phone Link:** KDE Connect, named "Phone Link", shown on first use, with no background drain when unused.
- **File Explorer:** OneDrive and Google Drive through KIO/online accounts (if it works without paid services), shown in the sidebar once signed in.

## 17. Printing and scanning

- Driverless printing (IPP Everywhere, CUPS) and scanning (Skanlite or simple-scan) work when the device is plugged in.
- Show them in Settings → Bluetooth & devices → Printers & scanners.

## 18. Gaming extras

- **Controllers:** Xbox, PlayStation and Switch pads work, shown in Settings → Gaming.
- **Displays:** VRR and HDR switches in Settings → Display (Plasma 6 supports them).
- **Overlay:** a Game Bar–like FPS and performance overlay (MangoHud, already in Bazzite) toggled with Win+G.
- **Game mode:** on by default for Steam games.

## 19. Polish pass (last)

1. Walk the whole OS as a new Windows user: boot, lock screen, desktop, start menu, open every pinned app, File Explorer tasks, Settings, every shortcut, Task Manager, Security, a game launcher, a cloud gaming app, lock, sleep, restart.
2. Screenshot every step, then run design-critique and accessibility-review on every one of them.
3. Fix everything that looks unfinished, inconsistent, Linux-ish or "in between".
4. Record it in `docs/TESTING.md`.

**Done means** sections 1–19 are all green in vm-test, with screenshots, and merged. The owner then gets the Try Mountain link with a "what to try" list that walks through the new things.
