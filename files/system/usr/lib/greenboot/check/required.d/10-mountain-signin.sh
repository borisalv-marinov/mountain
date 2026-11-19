#!/bin/bash
# "Boots" means the sign-in screen came up. Fedora's default checks are not used: their DNS check fails any offline boot
# and would roll back a good update on a PC without internet.
for _ in $(seq 60); do systemctl is-active --quiet display-manager.service && exit 0; sleep 2; done
echo "mountain: the sign-in screen did not start"; exit 1
