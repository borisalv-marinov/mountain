#!/usr/bin/env bash
# Tests mountain-windows-boot's Windows entry detection with fake efibootmgr output.
S=$(dirname "$0")/../files/system/usr/libexec/mountain-windows-boot
T=$(mktemp -d); rc=0
ok() { if eval "$1"; then echo "ok: $2"; else echo "FAIL: $2"; rc=1; fi; }
fake() { printf '#!/bin/sh\nprintf "%%s\\n" "BootCurrent: 0001" "BootOrder: 0001,0003" %s\n' "$1" > "$T/efi"; chmod +x "$T/efi"; }
fake '"Boot0001* Mountain	HD(1,GPT)/File(\\EFI\\fedora\\shimx64.efi)" "Boot0003* Windows Boot Manager	HD(2,GPT)/File(\\EFI\\Microsoft\\Boot\\bootmgfw.efi)"'
ok '[[ $(MOUNTAIN_EFIBOOTMGR=$T/efi bash "$S" check) == 0003 ]]' "finds the Windows entry"
fake '"Boot0001* Mountain	HD(1,GPT)" "Boot0002* UEFI QEMU HARDDISK"'
ok '! MOUNTAIN_EFIBOOTMGR=$T/efi bash "$S" check >/dev/null' "no Windows entry: hidden"
ok '! MOUNTAIN_EFIBOOTMGR=$T/efi bash "$S" go 2>/dev/null' "go refuses without an entry"
# a refused restart cancels the one-time Windows boot again
fake '"Boot0003* Windows Boot Manager	HD(2,GPT)"'
printf '#!/bin/sh\necho "$*" >> "%s/pkexec.log"\n' "$T" > "$T/pkexec"; printf '#!/bin/sh\nexit 1\n' > "$T/systemctl"; chmod +x "$T/pkexec" "$T/systemctl"
ok '! PATH=$T:$PATH MOUNTAIN_EFIBOOTMGR=$T/efi bash "$S" go 2>/dev/null && grep -q " clear$" "$T/pkexec.log"' "a refused restart clears BootNext"
ok 'PATH=$T:$PATH MOUNTAIN_EFIBOOTMGR=$T/efi bash "$S" go --no-restart >/dev/null && ! grep -q " clear$" <(tail -1 "$T/pkexec.log")' "go --no-restart leaves it set (Plasma asks to restart)"
rm -rf "$T"; exit $rc
