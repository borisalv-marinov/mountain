# Mountain v5 black glass: plan, sources and rulings

Brief: `docs/superpowers/prompts/2026-11-12-mountain-v5-black-glass-master-prompt.md`. Branch `mountain-v5`. Image checks phase 28.

## Research (sources)

- **Lock screen QML.** `kscreenlocker_greet` loads `lockscreenmainscript` from the *Plasma shell* package
  (`/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/LockScreenUi.qml`), not from the look-and-feel
  package, and falls back to its built-in `qrc:/fallbacktheme/LockScreen.qml` when that QML fails, so a bad edit cannot
  lock anyone out. Source: kscreenlocker `greeter/greeterapp.cpp` (`UnlockApp::setShell`, lines ~364-374 and ~505-516),
  plasma-desktop `desktoppackage/contents/lockscreen/`.
- **Login screen QML.** Plasma Login Manager (Bazzite's and Fedora KDE's greeter) loads its `Main.qml` from compiled-in
  resources (`qrc:/qt/qml/org/kde/plasma/login/Main.qml`, plasma-login-manager `src/frontend/greeter/main.cpp`), so it
  has no theme path. Both it and the lock screen build their user/clock/password UI from the shared QML module
  `org.kde.breeze.components` (plasma-workspace `lookandfeel/components`: `UserDelegate`, `Clock`,
  `SessionManagementScreen`), installed as plain files in `/usr/lib64/qt6/qml/org/kde/breeze/components/`
  (Fedora file list, mdapi). The generated `qmldir` has a `prefer :/qt/qml/...` line that makes Qt use the compiled copy;
  dropping that line makes Qt load the files on disk (Qt docs, "Module Definition qmldir Files", *prefer*).
- **SDDM** is no longer Bazzite's desktop greeter (only deck images); switching would also move autologin, PAM wallet
  unlock and session handling. Not taken.
- **Quick settings / Settings backends.** All present as QML modules in the image: `org.kde.plasma.networkmanagement`
  (plasma-nm), `org.kde.bluezqt`, `org.kde.plasma.private.volume` (plasma-pa), `org.kde.plasma.plasma5support`
  (executable + powermanagement engines), `org.kde.kcmutils` (`KCMLauncher`), `/usr/bin/plasmawindowed` (runs a plasmoid
  in its own window). Power profiles over D-Bus `net.hadess.PowerProfiles` (tuned-ppd on Bazzite).
- **Dolphin panels.** Panel visibility is saved in `~/.local/share/dolphin/dolphinstaterc` `[State] State=` (Qt
  `saveState` blob); on first run Dolphin falls back to the `dolphinui.rc` layout and `[PlacesPanel]` etc. We ship
  `Information` panel visible through the kxmlgui `<State>`/`<ToolBar>`... (see task 0.3 for the exact route used).

## Rulings

1. **Lock and login:** keep Plasma Login Manager (Bazzite's choice). One design for both by patching the shared
   `org.kde.breeze.components` on disk at build time (`files/scripts/lock-screen.sh`): "Hello, <name>" under the picture,
   Windows-style big clock. Lock screen already starts as clock-only and reveals the sign-in on a key or click
   (Plasma's `uiVisible`); the login screen gets the same clock-only "curtain" that slides up on a key or click.
   The build fails loudly if KDE's files change shape; kscreenlocker's fallback theme protects the lock screen.
2. **Try Mountain:** no autologin. Lock screen at start, sign-in with `123`, lock screen on (Win+L, idle).
3. **Taskbar:** like the owner's desktop: one floating glass taskbar, start and apps centered, tray and two-line clock on
   the right. The top bar is off by default (the "Top Bar On/Off" app still adds it, with CPU and RAM only).
4. **Settings:** a small "Mountain Settings" plasmoid run in its own window by `plasmawindowed` (no new packages, no C++):
   Windows 11 sidebar, search and Home page; every page opens the real KDE module. KDE's full System Settings stays as
   "All settings" (advanced).
5. **Quick settings:** our tray plasmoid with Windows 11 tiles and sliders on the Plasma backends above. The stock
   network, volume, battery, Bluetooth and power applets move into the tray's hidden list (still reachable with ^).
6. **Look:** our own Plasma theme "Mountain Glass" (SVG, blur masks), colour scheme "Mountain Glass" (WCAG AA checked),
   Aurorae window decoration "Mountain Glass", Kvantum "MountainGlass" (from GlassDark). Lite mode keeps the same SVGs
   with blur off; glass panels are dark enough (≥ 85 % opaque) to read as solid gloss black.
7. **Wallpaper:** our own SVG "Mountain Silk" (soft white-to-black waves), default for desktop, lock and login.
   The owner's own picture is never committed; `docs/OWNER-GUIDE.md` says how to set it in one step.
8. **Details pane:** File Explorer opens with the Information panel on the right for new users.
9. **Speed:** measured in vm-test, budgets enforced there (start menu < 150 ms on real hardware; vm-test uses software
   rendering, so it fails on > 20 % regression against the v5 baseline instead of the absolute number).

## Tasks

0.1 drag-icon test (fast drag right after select, shots mid-drag and on drop). 0.2 title-bar check + shot.
0.3 Details pane default. 0.4 avatar on login and lock shots. 0.5 "Hello, name".
1 lock/login (`lock-screen.sh`), Try Mountain without autologin, vm-test lock flow.
2 glass theme set (Plasma theme, colours, Aurorae, Kvantum), applied in look-and-feel defaults.
3 wallpaper + desktop (icons in columns, Recycle Bin, taskbar layout).
3a Settings app. 3b quick settings. 3c/4 measurements, budgets, tuning, `docs/TESTING.md`.
Image checks: phase 28 in `tests/check-image.sh`.

## Design tokens (every surface uses these)

| Token | Value | Use |
|---|---|---|
| glass-top | `#1B1D22` | top of the vertical gloss gradient |
| glass-bottom | `#07080A` | bottom of the gradient |
| glass-opacity | 0.86 (lite/solid: 1.0) | panels, menus, popups, title bars |
| rim | `#FFFFFF` at 14 % | 1 px outer border |
| rim-top | `#FFFFFF` at 38 %, fading to 0 at the corners | chrome highlight on the top edge |
| inner-shadow | `#000000` at 60 %, 1 px inside the rim | depth |
| text | `#F2F3F5` | normal text (15.9:1 on glass-bottom) |
| text-dim | `#A4A9B2` | secondary text (8.0:1) |
| accent | `#5AB0FF` | glows, focus rings, active indicator, slider fill, toggle on (with dark knob `#07080A`) |
| selection | `#2A6CC4` | selected rows/buttons with white text (5.3:1) |
| hover | `#FFFFFF` at 8 % | hover fill |
| danger | `#C42B1C` | close-button hover (Windows red), white glyph |
| radius | taskbar: full pill; menus/popups 12 px; windows 10 px; buttons/fields 8 px; toggles: pill |
| shadow | `#000000` at 55 %, 24 px blur, 8 px down | popups and windows |
