#!/usr/bin/env bash
# vm-test: every app the Start menu lists (system and Flatpak), one .desktop path per line, for the open-every-app style check.
# Left out: entries Start hides, terminal-only tools, and ones that change the system (restart, sign out, updates, uninstall).
for f in /usr/share/applications/*.desktop /var/lib/flatpak/exports/share/applications/*.desktop; do
  [[ -f $f ]] || continue
  s=$(sed -n '/^\[Desktop Entry\]/,/^\[/p' "$f")
  grep -qE '^(NoDisplay|Hidden|Terminal)=true' <<<"$s" && continue
  grep -q '^Type=Application' <<<"$s" || continue
  o=$(sed -n 's/^OnlyShowIn=//p' <<<"$s"); [[ -n $o && ";$o" != *";KDE;"* ]] && continue
  grep -q '^NotShowIn=.*KDE' <<<"$s" && continue
  grep -qiE '^Exec=.*(ujust|windows-boot|shutdown|reboot|poweroff|logout|lite-mode|mountain-topbar|bootc|rpm-ostree|systemctl|uninstall|ksmserver|steam|mountain-ai|lock-session|loginctl)' <<<"$s" && continue
  echo "$f"
done
