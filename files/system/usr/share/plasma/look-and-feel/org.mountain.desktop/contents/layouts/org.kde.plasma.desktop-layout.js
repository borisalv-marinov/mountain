// One Windows 11 style taskbar like the owner's desktop: start and apps in the middle, tray and two-line clock on the right.
// The top bar (CPU/RAM) is off by default; the "Top Bar On/Off" app adds it. Apps keep their menus inside their windows.
// opt() skips applets that are not installed so a missing one never breaks the panel.
const known = (typeof knownWidgetTypes !== "undefined") ? knownWidgetTypes : null;
const opt = (p, id) => {
    if (known === null) { try { return p.addWidget(id); } catch (e) { return null; } }
    return known.indexOf(id) >= 0 ? p.addWidget(id) : null;
};
const spacer = (p, expanding, length) => {
    const s = opt(p, "org.kde.plasma.panelspacer");
    if (s) { s.currentConfigGroup = ["General"]; s.writeConfig("expanding", expanding); if (length) s.writeConfig("length", length); }
};

const panel = new Panel();
panel.location = "bottom";
panel.height = 48; // Windows 11 taskbar
panel.floating = false;
panel.lengthMode = "fill";
panel.opacity = "translucent";
panel.hiding = "none";

spacer(panel, false, Math.round(gridUnit * 9)); // balances the tray so start + apps sit in the middle
spacer(panel, true);
// Windows 11 style start menu (vendored Menu 11 Enhanced: pins and icon are its defaults); Kickoff if it is missing.
if (!opt(panel, "menu.11.enhanced")) {
    const kickoff = panel.addWidget("org.kde.plasma.kickoff");
    kickoff.currentConfigGroup = ["General"];
    kickoff.writeConfig("icon", "mountain-logo");
    kickoff.writeConfig("showActionButtonCaptions", true);
}
// pinned apps come from kde-profile/default/xdg/kicker-extra-favoritesrc

const tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.mozilla.firefox.desktop",
    "applications:org.kde.dolphin.desktop",
    "applications:dev.vencord.Vesktop.desktop",
    "applications:steam.desktop",
    "applications:com.microsoft.Edge.desktop",
    "applications:com.microsoft.VSCode.desktop",
    "applications:org.onlyoffice.desktopeditors.desktop",
    "applications:org.kde.konsole.desktop"
]);
tasks.writeConfig("showOnlyCurrentDesktop", false);
spacer(panel, true);

const tray = panel.addWidget("org.kde.plasma.systemtray");
// Windows 11 quick settings replace the separate network/volume/battery/Bluetooth/brightness icons;
// the stock applets stay enabled behind the tray's ^ expander.
tray.currentConfigGroup = ["General"];
const stock = ["org.kde.plasma.networkmanagement", "org.kde.plasma.volume", "org.kde.plasma.battery",
               "org.kde.plasma.bluetooth", "org.kde.plasma.brightness"];
const extra = String(tray.readConfig("extraItems", "")).split(",").filter(s => s);
stock.forEach(id => { if (extra.indexOf(id) < 0) extra.push(id); });
tray.writeConfig("extraItems", extra);
tray.writeConfig("hiddenItems", stock);
// "known" but not enabled: the tray leaves the bell out, it sits on the taskbar instead (scripts can't reach the tray's own applets)
tray.writeConfig("knownItems", ["org.kde.plasma.notifications"]);
tray.reloadConfig();
const quick = opt(panel, "org.mountain.quicksettings"); // network, volume and battery icons; click for the flyout
if (quick) quick.globalShortcut = "Meta+A"; // Windows' quick-settings shortcut
const clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", "BelowTime"); // two lines, like the Windows taskbar
clock.writeConfig("dateFormat", "shortDate");
const bell = opt(panel, "org.kde.plasma.notifications"); // notification center right of the clock, like Windows 11
if (bell) bell.globalShortcut = "Meta+N";
opt(panel, "org.kde.plasma.showdesktop"); // the show-desktop corner, like Windows

for (const d of desktopsForActivity(currentActivity())) {
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/wallpapers/mountain-silk/");
    d.currentConfigGroup = ["General"];
    d.writeConfig("arrangement", 1); // icons in columns from the top left, like Windows
}
