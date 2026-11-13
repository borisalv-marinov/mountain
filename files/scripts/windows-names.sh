#!/usr/bin/env bash
# Windows-familiar app names, and developer/advanced entries hidden from the start menu (still runnable from Terminal).
set -euo pipefail
a=/usr/share/applications; hide=()
ren() { # file new-name; translated Name[xx] lines are dropped so every language shows the familiar name
  [[ -f $a/$1 ]] || { echo "windows-names: missing $1"; return 1; }
  sed -i -E "0,/^Name=/s|^Name=.*|Name=$2|; /^Name\[/d" "$a/$1"
}
ren systemsettings.desktop "All Settings" # the full KDE app; "Settings" is our Windows-style one (org.mountain.settings)
ren org.kde.dolphin.desktop "File Explorer"
ren org.kde.konsole.desktop "Terminal"
ren org.kde.plasma-systemmonitor.desktop "Task Manager"
ren org.kde.kinfocenter.desktop "System Information"
ren org.kde.kwrite.desktop "Notepad"
# v6: everyday apps with their Windows names
ren org.kde.kcalc.desktop "Calculator"
ren org.kde.gwenview.desktop "Photos"
ren org.kde.haruna.desktop "Media Player"
ren org.kde.kamoso.desktop "Camera"
ren org.kde.kclock.desktop "Clock"
ren org.kde.spectacle.desktop "Snipping Tool"
ren org.kde.kolourpaint.desktop "Paint"
ren org.kde.krecorder.desktop "Sound Recorder"
ren org.kde.skanlite.desktop "Scanner"
ren org.kde.kdeconnect.app.desktop "Phone Link"
ren org.kde.okular.desktop "PDF Reader"
ren com.microsoft.VSCode.desktop "VS Code"
# Own identity: no other distro's name on everyday apps
ren io.github.kolunmi.Bazaar.desktop "App Store"
ren io.github.ublue_os.yafti_gtk.desktop "Welcome"
ren io.github.rfrench3.bazzite-updater.desktop "Updates"
pl=$a/org.kde.kdeconnect.app.desktop
[[ -f $pl ]] && sed -i 's|^Exec=.*|Exec=/usr/libexec/mountain-phonelink|' "$pl"
for f in io.github.kolunmi.Bazaar io.github.ublue_os.yafti_gtk io.github.rfrench3.bazzite-updater; do # descriptions and actions too
  sed -i -E '/^(Comment|GenericName|Name|Keywords)(\[|=)/{s/Bazzite Portal/Welcome/g; s/Bazzite/your PC/g}' "$a/$f.desktop"
done
# Start search: no KDE System Settings ("All Settings" stays runnable from Settings > System > About), no Bazzite GPU and
# firewalld tools; the Welcome app says what it is
for f in $(grep -lE '^(Name=Cardwire|Exec=firewall-config)' "$a"/*.desktop 2>/dev/null); do f=${f##*/}; hide+=("${f%.desktop}"); done
sed -i -E '/^(GenericName|Comment)(\[|=)/d; 0,/^Name=/{/^Name=/a GenericName=Get started with your PC
}' "$a/io.github.ublue_os.yafti_gtk.desktop"
for f in systemsettings "${hide[@]}" kvantummanager org.kde.kwalletmanager kwalletmanager5-kwalletd org.kde.khelpcenter input-remapper-gtk \
         org.kde.kdebugsettings org.kde.kjournaldbrowser org.kde.kcolorschemeeditor org.kde.keditbookmarks \
         org.kde.knetattach yad-icon-browser bbrew bazzite-documentation discourse gkbd-keyboard-display org.freedesktop.IBus.Setup \
         com.gerbilsoft.rom-properties.rp-config org.kde.kdeconnect.sms org.kde.kdeconnect.nonplasma org.kde.plasma-interactiveconsole ibus-setup-anthy ibus-setup-chewing \
         ibus-setup-hangul ibus-setup-libbopomofo ibus-setup-libpinyin ibus-setup-m17n ibus-setup-tb ibus-setup-typing-booster; do
  [[ -f $a/$f.desktop ]] || continue
  sed -i '/^NoDisplay=/d' "$a/$f.desktop"
  sed -i '0,/^\[Desktop Entry\]/s//[Desktop Entry]\nNoDisplay=true/' "$a/$f.desktop"
done

# Our file-type defaults must beat Fedora's profile-dir lists (read before /etc/xdg); later keys in a merged group win.
for f in /usr/share/kde-settings/kde-profile/default/xdg/{kde-,}mimeapps.list; do
  [[ -f $f ]] && { echo; cat /etc/xdg/mimeapps.list; } >> "$f"
done

# Title bars and Alt+Tab say "KCalc", "letter.pdf — Okular": Qt appends the app's translated display name, which no
# .desktop key changes. Same trick as explorer-title.sh: a tiny "en@mountain" catalog (read before en_US, see
# /etc/xdg/plasma-workspace/env/mountain-names.sh) that renames only these exact strings, in whichever catalog has them.
python3 - /usr/share/locale <<'PY'
import gettext, glob, os, re, struct, sys
names = {'Dolphin': 'File Explorer', 'Konsole': 'Terminal', 'System Monitor': 'Task Manager', 'KWrite': 'Notepad',
         'KCalc': 'Calculator', 'Gwenview': 'Photos', 'Haruna': 'Media Player', 'Kamoso': 'Camera',
         'Spectacle': 'Snipping Tool', 'KolourPaint': 'Paint', 'KRecorder': 'Sound Recorder', 'Skanlite': 'Scanner',
         'KDE Connect': 'Phone Link', 'Okular': 'PDF Reader'}
# Windows labels in File Explorer and Task Manager: exact context + text, only in these apps' catalogs
ui = {'@title:menu Create new folder, file, link, etc.\x04Create New': 'New', '@action:inmenu View\x04Sort By': 'Sort',
      '@item\x04Places': 'Quick access', '@item\x04Remote': 'Network', '@item\x04Devices': 'This PC',
      '@action\x04End Process': 'End task', '@action\x04Quit Application': 'End task'}
uicat = {k: r'dolphin|kio6|.*systemmonitor.*' for k in ui}
# App texts that name KDE projects: exact msgids from the apps' de .po files (25.12/26.04), only in that app's catalog
apps = {
    'kdeconnect-app': {'About KDE Connect': 'About Phone Link',
        '@info\x04Make sure to install KDE Connect on your other devices.': 'Install the companion app on your phone, then pair it here.',
        '@title:context\x04KDE Connect Android App': 'Android phone app', '@title:context\x04KDE Connect iOS App': 'iPhone app',
        'Apple Store': 'App Store',
        'If you are having problems, visit the <a href="https://userbase.kde.org/KDEConnect"><span style=" text-decoration: underline;">'
        'KDE Connect Community wiki</span></a> for help.': 'If you are having problems, see the <a href="https://userbase.kde.org/KDEConnect">'
        '<span style=" text-decoration: underline;">Phone Link help</span></a>.'},
    'kdeconnect-core': {'KDE Connect failed to start': 'Phone Link failed to start'},
    'kdeconnect-fileitemaction': {'Send via KDE Connect': 'Send to phone', "Send to '%1' via KDE Connect": "Send to '%1'"},
    r'plasma_applet_org\.kde\.kdeconnect': {'KDE Connect Settings\u2026': 'Phone Link settings\u2026'},
    'kate': {'Recent Documents': 'Recent files', 'No recent documents': 'No recent files', 'Visit homepage': 'Learn more',
             'Get involved': 'Send feedback', 'Read handbook': 'Get help'},
    'kamoso': {'Configure Kamoso': 'Camera settings', 'Configure Kamoso...': 'Camera settings...',
               'Choose the folder where Kamoso will save pictures': 'Choose the folder where Camera saves photos',
               'Choose the folder where Kamoso will save videos': 'Choose the folder where Camera saves videos'},
    'kclock': {'The clock daemon was not found. Please start kclockd in order to have alarm functionality.':
                   'The alarm service is not running. Sign out and back in to use alarms.',
               'The clock daemon was not found. Please start kclockd in order to have timer functionality.':
                   'The alarm service is not running. Sign out and back in to use timers.'}}
for c, d in apps.items(): ui.update(d); uicat.update({k: c for k in d})
loc = sys.argv[1]; found = {}  # catalog -> {key: new}; contexts are read from real translations (de/fr), never guessed
for mo in glob.glob(f'{loc}/de/LC_MESSAGES/*.mo') + glob.glob(f'{loc}/fr/LC_MESSAGES/*.mo'):
    try: cat = gettext.GNUTranslations(open(mo, 'rb'))._catalog
    except Exception: continue
    for k in cat:
        if isinstance(k, str) and k.split('\x04')[-1] in names:
            found.setdefault(os.path.basename(mo), {})[k] = names[k.split('\x04')[-1]]
        elif isinstance(k, str) and k in ui and re.fullmatch(f'({uicat[k]})\\.mo', os.path.basename(mo)):
            found.setdefault(os.path.basename(mo), {})[k] = ui[k]
def write(path, d):
    d = {'': 'Content-Type: text/plain; charset=UTF-8\n', **d}  # with no charset, non-ASCII text does not read back
    keys = sorted(d); ids = [k.encode() for k in keys]; strs = [d[k].encode() for k in keys]
    n = len(ids); o = 28 + 16 * n; tab, data = [], b''
    for b in ids + strs: tab.append((len(b), o + len(data))); data += b + b'\0'
    open(path, 'wb').write(struct.pack('<7I', 0x950412de, 0, n, 28, 28 + 8 * n, 0, o) + b''.join(struct.pack('<2I', *t) for t in tab) + data)
    assert gettext.GNUTranslations(open(path, 'rb'))._catalog == d, 'catalog does not read back: ' + path
os.makedirs(f'{loc}/en@mountain/LC_MESSAGES', exist_ok=True)
for c, d in found.items(): write(f'{loc}/en@mountain/LC_MESSAGES/{c}', d)
seen = {k.split('\x04')[-1] for d in found.values() for k in d}
print('windows-names: titles renamed in', len(found), 'catalogs; not found:', sorted(set(names) - seen) or 'none')
assert {'KCalc', 'Okular', 'Konsole', 'KolourPaint'} <= seen, 'app display names not found in any catalog'
uiseen = {k for d in found.values() for k in d if k in ui}
print('windows-names: labels not found:', sorted(k.split('\x04')[-1] for k in set(ui) - uiseen) or 'none')
assert {'Create New', 'Sort By', 'Places'} <= {k.split('\x04')[-1] for k in uiseen}, 'File Explorer labels not found'
print('windows-names: app texts renamed:', len([k for k in uiseen if uicat[k] in apps]), 'of', sum(map(len, apps.values())))
PY
exit 0
