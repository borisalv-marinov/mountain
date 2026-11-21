#!/usr/bin/env bash
# vm-test: send a notice through the REAL wrapper that mountain-security uses (the same function text), so a click on it runs the default action.
eval "$(grep '^notify-send()' /usr/libexec/mountain-security)"
notify-send -a Security -i security-medium -h string:desktop-entry:org.mountain.security "Mountain Security" "No virus definitions yet. Click to open Security."
wait
