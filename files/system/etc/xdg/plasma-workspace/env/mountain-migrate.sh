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
