# CLIs installed with "npm install -g" go to ~/.local (no sudo), which is on PATH, so terminals and AI agents find them.
export NPM_CONFIG_PREFIX="$HOME/.local"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
