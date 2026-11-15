# Mountain v7 brief (owner, 2026-11-14)

v7 includes everything in v6.1 (branch `mountain-v7` from `mountain-v6.1` 2a9533c). The standing rules in `2026-11-14-mountain-v6.1-prompt.md` still apply.

**Goal:** the owner's daily driver for gaming, cloud gaming, coding, office work and talking with friends. It must be secure, never break, look glossy and feel like Windows 11. The bar is "a hospital or police station could rely on it". The owner only gets a build after a critical real-user QA review passes. Claims must be backed by tests; this is not a certification.

**Budget:** the weekly allowance (~28 %) until 16:00 on Sunday 2026-11-15. Run lean: ponytail, cheap helpers, no unnecessary work.

## Owner findings from Try Mountain v6.1

1. **Pop-up corners:** the power button and its menu, and almost every pop-up, show odd dark squares around the rounded corners.
2. **Start menu icons:** the icons look odd and don't match each other. Make them one consistent quality and size, and keep the brand colours like Windows (the owner's Windows taskbar is the reference).
3. **Settings sidebar icons:** make them simple black-and-white (monochrome) icons in one style.
4. **One Settings app:** Settings must not open third-party windows (KDE System Settings, e.g. Display Configuration). Everything, including display, sound, Bluetooth, portals and the rest, is configured inside the Mountain Settings app, branded as ours.
5. **Sound and volume:** they feel odd and slightly buggy.
6. **Speed:** faster than before, but not fast enough.
7. **File Explorer:** This PC shows drives with letters (C:, D:…), like Windows. The folder icons and the Photos icon look bad.
8. **Desktop launchers:** show just the app name (no ".desktop"). A double-click launches at once, with no "do you trust / open this file" pop-up.
9. **Security** doesn't feel convincing yet.
10. **Occasional screen tearing:** in the Try VM this is software rendering over VNC. KWin "allow tearing in fullscreen" stays (it's for games), but check that desktop windows never tear.
11. **Languages:** Settings has an "Add a language" option. The keyboard switcher shows only **ENG** and **БГ**. Bulgarian = **Phonetic** (owner's choice); remove the separate BDS entry.
12. **Archives:** when a zip is extracted, a quick malware check runs on the extracted files and shows the result.
13. **Glass:** the owner chose **"everything glass"**. Use macOS-style frosted glass on the taskbar, Start, pop-ups, menus, notifications **and whole app windows**, with strong background blur and gloss, like the owner's macOS-style dock reference. Text must stay readable (contrast checked).

## Final QA (before handing over)

A critical reviewer uses Mountain like a real person:
- **as a gamer:** Steam, Heroic, cloud gaming, controller
- **as a programmer:** VS Code, terminal, git
- **as an office user:** ONLYOFFICE, printing, files
- **as a social user:** Discord, browser
- **as an attacker:** the Part H attack test, plus downloads, archives and USB

It covers downloads, uploads, deletes, every UI element, speed, visibility, the Windows 11 resemblance and glass quality. Findings get fixed. The build is handed over only after 2 clean vm-test runs on one commit and a passing review.
