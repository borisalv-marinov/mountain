#!/usr/bin/env bash
# Tests mountain-lite-mode decisions via env overrides (no GPU needed).
S=$(dirname "$0")/../files/system/usr/libexec/mountain-lite-mode
rc=0
t() { # renderer mem_kb expected
  out=$(MOUNTAIN_RENDERER=$1 MOUNTAIN_MEM_KB=$2 bash "$S" --dry-run)
  if [[ $out == "$3" ]]; then echo "ok: $1 / $2"; else echo "FAIL: $1 / $2 -> '$out' (want '$3')"; rc=1; fi
}
t 'llvmpipe (LLVM 19.1, 256 bits)' 16000000 'lite: on (software rendering)'
t 'AMD Radeon Graphics (radeonsi, renoir)' 16000000 'lite: off'
t 'NVIDIA GeForce RTX 3060' 3500000 'lite: on (low memory)'
t 'Mesa Intel(R) UHD Graphics 620' 8000000 'lite: off'
t '' 8000000 'lite: off'
exit $rc
