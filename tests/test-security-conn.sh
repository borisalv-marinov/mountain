#!/usr/bin/env bash
# Tests mountain-security's choice of the connection for the firewall profile: the one with the default route, by UUID.
S=$(dirname "$0")/../files/system/usr/libexec/mountain-security
T=$(mktemp -d); rc=0; trap 'rm -rf "$T"' EXIT
ok() { if eval "$1"; then echo "ok: $2"; else echo "FAIL: $2"; rc=1; fi; }
eval "$(sed -n '/^conn()/,/^}/p' "$S")"
cat > "$T/nmcli" <<'STUB'
#!/bin/sh
case "$*" in
  "-g GENERAL.CON-UUID device show wlp2s0") echo 1111-wifi ;;
  "-g UUID,TYPE connection show --active") printf '%s\n' 0000-lo:loopback 2222-docker:bridge 1111-wifi:802-11-wireless ;;
esac
STUB
printf '#!/bin/sh\n[ -n "$NOROUTE" ] || echo "default via 192.168.1.1 dev wlp2s0 proto dhcp metric 600"\n' > "$T/ip"; chmod +x "$T/nmcli" "$T/ip"
ok '[[ $(PATH=$T:$PATH conn) == 1111-wifi ]]' "the default-route connection, not the bridge listed first"
ok '[[ $(NOROUTE=1 PATH=$T:$PATH conn) == 2222-docker ]]' "no default route: the first active non-loopback connection"
exit $rc
