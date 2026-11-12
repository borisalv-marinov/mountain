#!/usr/bin/env bash
# Tests mountain-ai via env overrides and fake commands (no network).
S=$(cd "$(dirname "$0")/.." && pwd)/files/system/usr/libexec/mountain-ai
export HOME=$(mktemp -d); fake=$(mktemp -d)
rc=0
ok() { if [[ $2 == *"$3"* ]]; then echo "ok: $1"; else echo "FAIL: $1 -> '$2'"; rc=1; fi; }
ok codex-dry "$(MOUNTAIN_AI_DRYRUN=1 bash "$S" codex)" 'npm install -g --prefix'
ok codex-pkg "$(MOUNTAIN_AI_DRYRUN=1 bash "$S" codex)" '@openai/codex'
ok install-msg "$(MOUNTAIN_AI_DRYRUN=1 bash "$S" gemini)" 'Installing Gemini CLI (first time only, about a minute)'
ok claude-dry "$(MOUNTAIN_AI_DRYRUN=1 bash "$S" claude)" 'https://claude.ai/install.sh'
printf '#!/bin/sh\necho FAKE-CODEX-RAN\n' > "$fake/codex"; chmod +x "$fake/codex"
out=$(PATH="$fake:$PATH" MOUNTAIN_AI_DRYRUN=1 bash "$S" codex)
ok installed-runs "$out" FAKE-CODEX-RAN
[[ $out != *Installing* ]] || { echo "FAIL: installed still installs"; rc=1; }
out=$(MOUNTAIN_AI_OFFLINE=1 bash "$S" gemini); r=$?
ok offline-msg "$out" 'No internet — connect and click again'
[[ $r == 1 ]] || { echo "FAIL: offline exit $r"; rc=1; }
[[ ! -e $HOME/.local ]] || { echo "FAIL: offline created ~/.local"; rc=1; }
bash "$S" unknown >/dev/null 2>&1; [[ $? == 2 ]] || { echo "FAIL: unknown exit"; rc=1; }
exit $rc
