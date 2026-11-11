# Mountain v3 — "Feels like Windows, runs like Linux" master prompt

Use superpowers (brainstorming → writing-plans → subagent-driven-development → verification-before-completion) and ponytail (lite: build what's asked, name smaller options in one line). Use the design skills (frontend-design, design-critique, accessibility-review) for every visual piece. Use cheap subagent models where the plan has full code; keep reviews mid-tier. Do not stop to ask between tasks — make rulings and log them.

## Goal

Mountain is a Linux OS for normal people, gamers and coders: as close to Windows as possible in look, feel and behaviour, so anyone can use it, with no bloat, fast even on weak PCs and in a VM. It must feel like a real, polished OS — not "a browser or something".

## Where things are (read before planning)

- Repo `C:\Users\marin\Desktop\mountain`, branch from `main`. BlueBuild on Bazzite stable, KDE Plasma 6, Fedora 45. Recipes `recipes/common.yml`, files under `files/system/...`, build scripts `files/scripts/*.sh`.
- Image checks `tests/check-image.sh` (cumulative phases, now `MOUNTAIN_PHASE=18`; add phases, never weaken old ones). CI `.github/workflows/build.yml` (build + image tests), `vm-test.yml` (boots QEMU, screenshots `desk1-3.png`, RAM, report.md), `try-mountain.yml` (browser desktop for the owner via noVNC + cloudflared; page `try/mountain.html`).
- Previous plan: `docs/superpowers/plans/2026-11-11-mountain-desktop-v2.md` (what exists: lite mode, icons, desktop folders, AI launchers `/usr/libexec/mountain-ai`, top bar + dock layout.js, We10X icons, Try Mountain paste).
- Testing notes `docs/TESTING.md`, owner guide `docs/TRY-MOUNTAIN.md`.

## What the owner saw in Try Mountain (fix all of it)

1. **Laggy**: moving the cursor feels "like an old phone"; response time is bad. VM shows RAM ~50%, CPU 16–20%. Find out how much is the VM/VNC path vs the OS. Fix both: noVNC quality/compression settings, QEMU display/cursor options, KWin latency/compositor settings, animations, background services. Must not be laggy even in the VM.
2. **Opening files/folders doesn't work or is weird**: opening a photo or a folder did nothing. Every file type a normal user meets (photos, videos, music, PDF, text, office docs, archives) must open in a sensible default app on the expected click. Drag and drop of files and folders must work.
3. **File system should feel like Windows File Explorer**: a "This PC"-style home with Quick access, Desktop/Documents/Downloads/Pictures/Music/Videos, drives with friendly names (no unnamed red bar devices, no "root"), Windows-like toolbar/ribbon feel, no ".desktop" endings on shortcuts, simple context menus. Research how Zorin OS, Linux Mint, KDE "Windows-like" setups do it.
4. **Start button / start menu**: the start button currently shows a Windows logo — it must show the Mountain logo (two mountains), everywhere (start button, menu, boot, about). Start menu must work like Windows: pinned apps, "All apps", search, Settings and Power at the bottom. "Utilities" is weird, "Application launcher settings" is confusing, Settings is hard to find — fix the structure and names for a normal user.
5. **Remove advanced/confusing things for normal users**: e.g. "KDE Wallet service" prompts (make wallet unlock automatically or never ask), confusing system-tray items, developer-ish menu entries. Keep advanced tools reachable but out of the way.
6. **Wallpaper**: new graphic wallpaper — only mountain peaks drawn as thin lines, peaks flowing around. Great design, dark and light variants, crisp at 1080p/1440p/4K. Also login and lock screen to match.
7. **Polish the whole UI**: consistent spacing, fonts, icons, window decorations, taskbar, top bar, notifications, dialogs. It currently "looks like Windows but feels like Linux" — make it feel like Windows too. Windows-familiar names ("Settings", "File Explorer", "Task Manager", "Control Panel" style entries if helpful).
8. **Games and cloud gaming**: Steam opens (keep it). Make sure everything is installed/downloaded at first boot (Boosteroid, GeForce NOW, Xbox Cloud, launchers) and actually works; drivers present. Owner will test cloud gaming.
9. **CLIs**: AI agents (Claude Code, Codex, Gemini, Copilot) and terminal open with one click, install on first click, clear feedback while installing.
10. **Secure it**: sensible defaults (firewall on, updates automatic, no passwordless sudo in the real image, screen lock in the real image, secrets never in repo/logs).
11. **Fast, no bloat**: audit what runs at login and in the background; remove/disable what a normal user doesn't need. Measure before/after (RAM, boot time, login-to-desktop time, input latency where possible). Keep Bazzite Portal, Bazaar, Konsole (owner said leave them).

## Research step (before the plan)

Look at how other projects do Windows-like Linux well and badly: Zorin OS, Linux Mint (Cinnamon), Kubuntu/KDE Windows-like layouts, Bazzite, ChimeraOS, elementary (for polish), and known Plasma pitfalls (KDE bug 512005 for layout.js panels, applets compiled as `qt6/plugins/plasma/applets/*.so`, Dolphin showing `.desktop` file names). Write down: what to do, what not to do. Cite sources in the plan.

## Testing (every task, and a full pass at the end)

- Each task: TDD where possible; image checks in `tests/check-image.sh`; push and let CI build + vm-test run; read the report and screenshots.
- Extend `vm-test.yml` to exercise real use, not just boot: open File Explorer, open a photo/PDF/text file, drag a file into a folder, open Settings, open the start menu and search, launch Steam, launch each AI CLI launcher (dry-run install), open/close windows, log out, shut down and reboot cleanly. Screenshot each step; fail on errors.
- Measure latency/RAM in vm-test and record trends in `docs/TESTING.md`.
- At the end: start Try Mountain from `main`, open the link in the built-in browser, confirm the page loads, and give the owner the link plus a checklist of what to try.

## Constraints (hard rules)

- Never commit cosign.key, ISOs or VM disks; repo stays public; never print the Try Mountain browser password (owner's notes file: `Desktop\Operating System\try-mountain-password.txt`); never type passwords on public sites.
- No third-party downloads at build time except Fedora repos, existing repos in the recipe, or Flathub.
- Never draw or copy brand logos (Windows, NVIDIA, Xbox…); use the apps' own installed icons. The Mountain logo is ours.
- Try Mountain only: desktop password `123`, no lock screen, passwordless admin (in `try-mountain.yml`, never in the shipped image). Browser page password stays the GitHub secret's first 8 characters.
- CI lessons: Azure apt mirror outages (workflows now use archive.ubuntu.com + retries); ghcr 429 rate limits when builds start together (wait 5 min, rerun failed); `build.yml` cancels in-progress builds on the same ref; Try Mountain needs `actions/checkout` for `try/`.
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. PRs end with the Claude Code line. Owner authorized merging to main.
- Owner is non-technical: always show the live task list and a status table (⏳ working, 🕓 waiting, ✅ done, 🔍 reviewing, 🔧 fixing, ☁️ cloud). Short, plain messages. Save usage: cheap models for mechanical work, no repeated waiting.

## Owner's own words (verbatim, for fidelity)

> Now when I log in, it doesn't ask me for a password, and it's really buggy. Like moving my cursor, it's like playing on an old phone. And also, I need the weird thing is when I try to open a photo, a folder, it doesn't open it. But it's very buggy, the UI. It's not polished at all. It needs to be fully polished. When I try to open the folder, it's a little bit weird. I need you to recreate the folder system of the Windows, and the UI a little bit. I can see network, memories, which is on 50% of the VM, and CPU is around 16 to 20. I don't know if the VM is making it buggy, but it is buggy. Steam is opening Steam should be open. Yeah, Steam is opening. There is cache. I want the bounties to be graphical, like only the peaks, like thin lines, like peaks going around. Use great design for it, and use great design for the whole program. Go into it. The Windows tick looks good, but there is a Windows logo on it, and it works weird. To be fair, when I open Windows mount, it doesn't show up the logo. When I try to go to utilities, it's weird. When I try to go to settings, I cannot even find them. Let me search for them. Yeah, they are on the top bar. I found them. Application launcher settings. I have no idea what this is. I don't think it's polished. Maybe that's why. Everything is really buggy and not polished at all. It should be more polished, more better working. Try to polish it, secure it, and to make it actually work with games and everything. I'm gonna try out I can try out cloud gaming, and make sure everything is downloaded. Everything is downloaded, and make it closer to Windows, so I know what I'm doing. Response time is really bad. Kate wallet service, I have no idea what is that. This is made for normal user. I don't need this advanced. I don't need this advanced functions. I just need it to feel like a Windows, to look like a Windows, to be good, to fix the UI, use the design skills and everything. Try to make it like Windows, a little bit. [...] It doesn't feel polished. It doesn't feel like a real operating system. It just seems like a browser or something like that. Also, last but not least, they need to fix the looks are very bad. It looks like Windows, but to feel like Linux, and it to be easy to operate. I want to click on a file and it just opens it. I want to be able to drag folders, to do things, and it to not to be laggy even on the VM. [...] Honestly, my goal is to make it as close to Windows as possible, so people feel familiarity with it, and everybody else can use it. It's fastest Linux, and it's very close to Windows, so everybody can use it. It has pretty much the same systems, but no bloatware. [...] Try to optimize as much as you can. Look at other sources, other Linux programs, how they're built, how to build them right, how to build them wrong, what to do, what not to do, and everything in between. Do your best. [...] Do the plan advanced. Make sure everything is included. Because developing UI and OS as general is very hard. Make sure you're testing every time, and at the end, I want you to test every single feature from opening to files to closing systems to fixing bugs and everything is in between. I want you to test the CLIs and everything. The CLIs to be open with one button and everything in between.

## Done means

All 11 items fixed and shown in vm-test screenshots; full-feature test pass green; RAM/latency measured and improved; merged to main; fresh Try Mountain link checked and handed to the owner with a short "what to try" list and a list of rulings made.
