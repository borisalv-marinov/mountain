// One floating, centered, translucent bottom panel: launcher, pinned apps, tray, clock.
const panel = new Panel();
panel.location = "bottom";
panel.height = 2 * Math.ceil(gridUnit * 2.5 / 2);
panel.floating = true;
panel.alignment = "center";
panel.lengthMode = "fit";
panel.opacity = "translucent";
panel.hiding = "none";

panel.addWidget("org.kde.plasma.kickoff");

const tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.mozilla.firefox.desktop",
    "applications:org.kde.dolphin.desktop",
    "applications:dev.vencord.Vesktop.desktop",
    "applications:steam.desktop",
    "applications:com.microsoft.Edge.desktop",
    "applications:code.desktop",
    "applications:org.onlyoffice.desktopeditors.desktop"
]);
tasks.writeConfig("showOnlyCurrentDesktop", false);

panel.addWidget("org.kde.plasma.marginsseparator");
panel.addWidget("org.kde.plasma.systemtray");
panel.addWidget("org.kde.plasma.digitalclock");

for (const d of desktopsForActivity(currentActivity())) {
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/mountain/wallpaper.svg");
}
