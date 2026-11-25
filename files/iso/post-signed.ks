# Added to every Mountain installer ISO: the installed system follows the SIGNED image (the ISO's own payload is unsigned)
%post --log=/root/mountain-switch.log
bootc switch --mutate-in-place --transport registry --enforce-container-sigpolicy ghcr.io/borisalv-marinov/mountain:latest || echo "signed switch failed (offline install?); run: sudo bootc switch --enforce-container-sigpolicy ghcr.io/borisalv-marinov/mountain:latest"
%end
