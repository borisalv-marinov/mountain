#!/usr/bin/env bash
# Supply chain: every `uses:` in the workflows is pinned to a full 40-hex commit SHA (a moved tag cannot swap code in
# next to the signing key); and every build script in files/scripts is executable in git.
cd "$(dirname "$0")/.." || exit 1
bad=$(grep -hnE '^\s*(- )?uses:' .github/workflows/*.yml | grep -vE 'uses: *[^ @]+@[0-9a-f]{40}( |$)' || true)
[[ -z $bad ]] || { echo "FAIL: not pinned to a commit SHA:"; echo "$bad"; exit 1; }
nx=$(git ls-files -s 'files/scripts/*.sh' | grep -v '^100755' || true)
[[ -z $nx ]] || { echo "FAIL: not executable in git:"; echo "$nx"; exit 1; }
echo "ok: every workflow action is pinned to a commit SHA; every files/scripts/*.sh is executable"
