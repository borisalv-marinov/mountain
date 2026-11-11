// Top bar (menu, title, CPU/RAM/net, tray, clock) + floating bottom taskbar.
// opt() skips applets that are not installed so a missing one never breaks the panel.
const known = (typeof knownWidgetTypes !== "undefined") ? knownWidgetTypes : null;
const opt = (p, id) => {
    if (known === null) { try { return p.addWidget(id); } catch (e) { return null; } }
    return known.indexOf(id) >= 0 ? p.addWidget(id) : null;
};

const top = new Panel();
top.location = "top";
top.lengthMode = "fill";
top.floating = false;
top.opacity = "translucent";
top.height = Math.round(gridUnit * 1.6);

opt(top, "org.kde.plasma.appmenu");
opt(top, "org.kde.plasma.panelspacer");
opt(top, "org.kde.windowtitle") || opt(top, "org.kde.plasma.windowtitle"); // only one exists, whichever is installed
opt(top, "org.kde.plasma.panelspacer");
opt(top, "org.kde.plasma.systemmonitor.cpu");
opt(top, "org.kde.plasma.systemmonitor.memory");
opt(top, "org.kde.plasma.systemmonitor.net");
top.addWidget("org.kde.plasma.systemtray");
top.addWidget("org.kde.plasma.digitalclock");

const panel = new Panel();
panel.location = "bottom";
panel.height = 2 * Math.ceil(gridUnit * 2.5 / 2);
panel.floating = true;
panel.alignment = "center";
panel.lengthMode = "fit";
panel.opacity = "translucent";
panel.hiding = "none";

const kickoff = panel.addWidget("org.kde.plasma.kickoff");
kickoff.currentConfigGroup = ["General"];
kickoff.writeConfig("icon", "mountain-logo");

const tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.mozilla.firefox.desktop",
    "applications:org.kde.dolphin.desktop",
    "applications:dev.vencord.Vesktop.desktop",
    "applications:steam.desktop",
    "applications:com.microsoft.Edge.desktop",
    "applications:code.desktop",
    "applications:org.onlyoffice.desktopeditors.desktop",
    "applications:org.kde.konsole.desktop"
]);
tasks.writeConfig("showOnlyCurrentDesktop", false);

opt(panel, "org.kde.plasma.trash");

for (const d of desktopsForActivity(currentActivity())) {
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/mountain/wallpaper.svg");
}
