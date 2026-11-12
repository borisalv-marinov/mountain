# Mountain — owner guide

## Using it

- **Start menu**: the Mountain logo in the middle of the taskbar. Type to search, click **All apps** for everything, pinned apps are at the top, **Recommended** shows recent files. Right-click an app to pin or unpin it.
- **File Explorer**: double-click **This PC** on the desktop. Left side: Home, Recent, Desktop, Documents, Downloads, Pictures, Music, Videos, Recycle Bin. The bar under the address has New, cut/copy/paste/rename/delete, Sort, View, Filter and Information (details).
- **Opening files**: double-click. Photos → Gwenview, PDF → Okular, text and code → VS Code, video and music → Haruna, zip and other archives → Ark, Word/Excel/PowerPoint → OnlyOffice. Right-click → **Open With** for something else.
- **Moving files**: drag onto a folder and pick **Move Here** (hold Shift to move straight away, Ctrl to copy).
- **Lock screen**: Mountain starts on a lock screen with the clock and date. Click or press a key: it says **Hello, <your name>**; type your password. **Win+L** locks it again.
- **Settings**: start menu → Settings (Windows 11 layout: Home, System, Bluetooth & devices, … Updates; search at the top). Each page opens the real KDE page. **All Settings** in the start menu is the full KDE app.
- **Quick settings**: click the network/volume/battery icons next to the clock, or press **Win+A**: Wi-Fi, Bluetooth, Airplane mode, Energy saver, Accessibility, Night light, brightness and volume; the gear opens Settings. The old separate icons are under the **^** arrow.
- **Top Bar On/Off** (start menu) adds or removes a bar at the top with CPU and memory.
- **Your own wallpaper** (one step): right-click the desktop → **Desktop and Wallpaper** (Change wallpaper) → **Add…** and pick your picture file. Mountain ships its own look-alike, *Mountain Silk*, because the picture on your Windows PC is a downloaded image we may not publish; *Mountain Peaks* is the other built-in choice.
- **Cloud gaming**: desktop folder *Cloud Gaming* (GeForce NOW, Xbox Cloud Gaming, Boosteroid). Each opens in its own window with its own taskbar icon; you sign in once per service.
- **AI tools and coding**: desktop folder *AI* (Claude Code, Codex, Gemini, Copilot) and *Coding* (VS Code, Terminal, Python, Node.js). The first click installs the AI tool (about a minute). Tools installed with `npm install -g` work without admin rights.

## Updating

Mountain does not update in the background (it would use your internet and CPU while you play).
To update: start menu → **Updates** → follow the window. Or in Terminal: `ujust update`.
Every update is a whole new system image; if anything is wrong, restart and pick the previous entry in the boot menu (or `sudo bootc rollback`).

## Security: what is hardened, and how to undo it

| What | Why | How to undo |
|---|---|---|
| Firewall zone **mountain** (blocks all incoming connections except network setup, printer/device discovery, Windows file sharing as a client, Steam Remote Play and Steam LAN transfers). The old default opened every port from 1025 to 65535. | Nothing on the internet or your Wi-Fi can connect to your PC unless you allow it. | Programs that wait for incoming connections on other ports (Sunshine game streaming, a dev server you open from another device) are now blocked. Allow one: `sudo firewall-cmd --permanent --zone=mountain --add-port=47984-48010/tcp` (or `--add-service=<name>`), then `sudo firewall-cmd --reload`. Go back fully: `sudo firewall-cmd --set-default-zone=FedoraWorkstation`. |
| Kernel settings (`/usr/lib/sysctl.d/60-mountain-hardening.conf`): programs can only debug their own children, kernel addresses and logs hidden from normal users, no unprivileged eBPF, no kexec, no network redirects or source routing, stronger address randomisation (64-bit programs), safer shared temp folders, SYN-flood protection. | Makes many attacks much harder; games, Proton, flatpaks, VS Code and the AI tools are not affected. | Put the old value in `/etc/sysctl.d/99-local.conf`, e.g. `kernel.yama.ptrace_scope = 0` (needed only to attach a debugger to any running program), then reboot. |
| Kernel boot options `slab_nomerge page_alloc.shuffle=1 randomize_kstack_offset=on vsyscall=none` (`/usr/lib/bootc/kargs.d/10-mountain-hardening.toml`). | Harder to exploit memory bugs in the kernel; very small speed cost. | Try it for one boot: in the boot menu press **e** and remove the option from the `linux` line. For good: ask for the file to be removed from the image (an update re-applies these options). `vsyscall=none` only matters for very old (pre-2014) native Linux programs. |
| SELinux stays **enforcing** (checked by the image tests). | Confines system services. | Do not turn it off; ask for help if something is blocked. |
| Passwords: the shipped image never allows admin without a password. Your account picture is the Mountain logo (new accounts; change it in Settings → Users). Accounts that sign in automatically get no "KDE Wallet" pop-ups (the wallet is off for them); accounts with a password keep the encrypted wallet. | Saved passwords stay encrypted when the account has a password. | To use the wallet with automatic sign-in: delete `~/.config/kwalletrc` and turn off automatic sign-in. |
| Fewer background services: no SSH server, no printer server until you need it, no mobile-modem service, no KDE Connect, no input remapper, no update timers, no usage-count ping. | Less to attack, less memory used. | `sudo systemctl enable --now <name>` (e.g. `ModemManager`, `input-remapper`, `sshd`). |

Not used on purpose (they break games or everyday apps): the hardened memory allocator (breaks Electron apps like VS Code and Discord, and Steam), USB device blocking (new controllers and headsets would not work), turning off io_uring, ignoring ping.

## Speed

- The **LAVD** CPU scheduler runs from boot; it favours what you are interacting with (desktop, games). Undo: `sudo systemctl disable --now scx_loader`.
- **Lite mode**: on PCs without a working graphics driver or with less than 4 GB RAM, Mountain turns off blur and animations at login, and Edge runs without GPU acceleration.
- Animations run at half the normal length.

## Try Mountain (browser desktop)

See `docs/TRY-MOUNTAIN.md`. It runs in a cloud VM without a graphics card, so it is slower than a real PC; blur is switched on there anyway so you can see the look.
