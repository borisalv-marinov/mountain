// Mountain window census (vm-test): every window that appears during the run, with its kind and look facts.
// Lines go to the journal as MWC|event|kind|class|desktop file|caption|ssd or noborder|opacity %|x,y,w,h|pid.
function kind(w) {
    if (w.normalWindow) return "normal";
    if (w.dialog) return "dialog";
    if (w.notification || w.criticalNotification) return "notification";
    if (w.onScreenDisplay) return "osd";
    if (w.tooltip) return "tooltip";
    if (w.dropdownMenu || w.popupMenu) return "menu";
    if (w.popupWindow) return "popup";
    if (w.dock) return "dock";
    if (w.desktopWindow) return "desktop";
    if (w.splash) return "splash";
    return "other";
}
function log(ev, w) {
    const g = w.frameGeometry;
    console.warn(["MWC", ev, kind(w), w.resourceClass, w.desktopFileName, String(w.caption).replace(/\|/g, "/"),
                  w.noBorder ? "noborder" : "ssd", Math.round(w.opacity * 100),
                  [g.x, g.y, g.width, g.height].map(Math.round).join(","), w.pid].join("|"));
}
for (const w of workspace.windowList()) log("old", w);
workspace.windowAdded.connect(w => log("add", w));
workspace.windowActivated.connect(w => { if (w) log("act", w); });
