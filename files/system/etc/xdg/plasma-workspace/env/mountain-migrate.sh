# Sourced by startplasma before the taskbar loads (POSIX sh, never exits). Once per account:
# accounts made before v7.1 still have Plasma's empty-taskbar spacer, whose right-click is KDE's panel menu; the image's own
# taskbar space (same settings: expanding, length; same place in the row) opens Task Manager on a right-click, like Windows.
mt_rc=${XDG_CONFIG_HOME:-$HOME/.config}/plasma-org.kde.plasma.desktop-appletsrc
mt_done=${XDG_STATE_HOME:-$HOME/.local/state}/mountain/migrated-taskbarspace
if [ -f "$mt_rc" ] && [ ! -e "$mt_done" ] && [ -d "${MOUNTAIN_PLASMOIDS:-/usr/share/plasma/plasmoids}/org.mountain.taskbarspace" ]; then
  sed -i 's/^plugin=org\.kde\.plasma\.panelspacer$/plugin=org.mountain.taskbarspace/' "$mt_rc" 2>/dev/null &&
    mkdir -p "${mt_done%/*}" 2>/dev/null && : > "$mt_done"
fi
unset mt_rc mt_done
# Desktop right-click menu like Windows: no "Enter Edit Mode", "Lock Screen", "Show Logout Screen" (Plasma's ActionPlugins of the
# desktop containment, type 0, in the corona's appletsrc; no layout-script hook sets it). From the first sign-in: a file holding only
# this group has no containments, so Plasma still builds its default desktop into it and keeps the group (shellcorona.cpp load()).
mt_menu=${XDG_STATE_HOME:-$HOME/.local/state}/mountain/migrated-desktopmenu
if [ ! -e "$mt_menu" ] && command -v kwriteconfig6 >/dev/null 2>&1; then
  mt_k="--file plasma-org.kde.plasma.desktop-appletsrc --group ActionPlugins --group 0"
  kwriteconfig6 $mt_k --key 'RightButton;NoModifier' org.kde.contextmenu 2>/dev/null &&
  for mt_a in _logout _lock_screen "desktop edit mode"; do
    kwriteconfig6 $mt_k --group 'RightButton;NoModifier' --key "$mt_a" false 2>/dev/null || break
  done &&
    mkdir -p "${mt_menu%/*}" 2>/dev/null && : > "$mt_menu"
fi
unset mt_menu mt_k mt_a
