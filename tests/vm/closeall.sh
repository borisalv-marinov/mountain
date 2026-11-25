#!/usr/bin/env bash
# vm-test (run as the test user): close every window except the shell, then end Spectacle (its region overlay and background
# service outlive a window close), so the next every-app shot shows only its own app. With an argument (a class regex) it closes only
# those windows, like a person pressing X (no forced kill).
only=null; [[ -n ${1:-} ]] && only="/$1/i" # optional: close only windows whose class matches this regex
cat > /tmp/closeall.js <<JS
const only = $only;
for (const w of workspace.windowList()) if ((w.normalWindow || w.dialog || w.onScreenDisplay) && w.resourceClass !== "plasmashell" && (!only || only.test(w.resourceClass))) w.closeWindow();
JS
chmod 644 /tmp/closeall.js
i=$(dbus-send --session --print-reply --dest=org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript string:/tmp/closeall.js string:mountain-closeall | awk '/int32/{print $2}')
[[ -n $i ]] && dbus-send --session --print-reply --dest=org.kde.KWin /Scripting/Script$i org.kde.kwin.Script.run >/dev/null
sleep 3
pkill -u "$(id -u)" -x spectacle
dbus-send --session --print-reply --dest=org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript string:mountain-closeall >/dev/null
sleep 1
echo closed
