// Mountain v7.2, once per account (Plasma records it): the tray's language button becomes Mountain's, whose click opens
// the Windows language list; Plasma's switched to the next language on a click. New accounts get it from the layout.
const kdeKbd = "org.kde.plasma.keyboardlayout", mtKbd = "org.mountain.keyboardlayout";
panels().forEach(panel => panel.widgets("org.kde.plasma.systemtray").forEach(tray => {
    tray.currentConfigGroup = ["General"];
    const list = key => String(tray.readConfig(key, "")).split(",").filter(s => s);
    const extra = list("extraItems").filter(id => id !== kdeKbd);
    if (extra.indexOf(mtKbd) < 0) extra.push(mtKbd);
    const known = list("knownItems");
    [kdeKbd, mtKbd].forEach(id => { if (known.indexOf(id) < 0) known.push(id); });
    tray.writeConfig("extraItems", extra);
    tray.writeConfig("knownItems", known);
    tray.reloadConfig();
}));
