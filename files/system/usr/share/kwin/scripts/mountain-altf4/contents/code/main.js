// Alt+F4 like Windows: close the active window; on the desktop (no normal window active) ask to shut down.
registerShortcut("WindowsAltF4", "Close window, or shut down from the desktop", "Alt+F4", function () {
    const w = workspace.activeWindow;
    if (w && w.normalWindow && !w.desktopWindow) {
        w.closeWindow();
    } else { // the "Shut Down Mountain" dialog (plasmawindowed org.mountain.shutdown) as a user unit: KWin scripts can't start programs
        callDBus("org.freedesktop.systemd1", "/org/freedesktop/systemd1", "org.freedesktop.systemd1.Manager",
                 "StartUnit", "mountain-shutdown-dialog.service", "replace");
    }
});

// Run, Quick Link menu (Win+X) and Shut Down Mountain: frameless, above other windows, where Windows puts them.
// Wayland apps can't place their own windows, so KWin does it. They are plasmawindowed windows with these titles.
const sizes = {}; // placed size per window (internalId), to re-place when it changes
const dialogs = { "Run": "bottomleft", "Quick Link menu": "start", "Shut Down Mountain": "center" };
function place(w) {
    const where = dialogs[w.caption];
    if (!where || !/plasmawindowed/i.test(w.resourceClass + " " + w.resourceName + " " + w.desktopFileName)) return;
    w.noBorder = true; // first: the size below is then the content size
    w.keepAbove = true;
    if (where === "start") { w.skipTaskbar = true; w.skipSwitcher = true; }
    const a = workspace.clientArea(KWin.MaximizeArea, w), g = w.frameGeometry;
    let x, y = a.y + a.height - g.height - 12;
    if (where === "center") {
        x = a.x + (a.width - g.width) / 2; y = a.y + (a.height - g.height) / 2;
    } else if (where === "start" && !readConfig("taskbarLeft", false)) {
        // shortcut: Start's place on a centred taskbar is estimated (about 250 px left of centre with the default pins); read it from the panel if pins change a lot
        x = Math.max(a.x + 8, a.x + a.width / 2 - 250); y = a.y + a.height - g.height - 8;
    } else {
        x = a.x + (where === "start" ? 8 : 12);
    }
    sizes[w.internalId] = g.width + "x" + g.height;
    w.frameGeometry = { x: Math.round(x), y: Math.round(y), width: g.width, height: g.height };
    workspace.activeWindow = w;
}
workspace.windowAdded.connect(function (w) {
    place(w);
    w.captionChanged.connect(function () { place(w); });
    // Win+X opens its "Shut down or sign out" flyout by growing: keep the bottom-left corner where it was
    w.frameGeometryChanged.connect(function () {
        const g = w.frameGeometry;
        if (sizes[w.internalId] && sizes[w.internalId] !== g.width + "x" + g.height) place(w);
    });
});
workspace.windowRemoved.connect(function (w) { delete sizes[w.internalId]; });
