#!/usr/bin/env bash
# Install cairn locally: build server, register MCP, symlink skill,
# install the optional pair helper, and print remaining manual steps.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$REPO_DIR/server"
BIN_PATH="$SERVER_DIR/cairn-server"
SKILL_SRC="$REPO_DIR/skills/code-tour"
SKILL_DST="$HOME/.claude/skills/code-tour"
PAIR_SRC="$REPO_DIR/bin/pair"
PAIR_DST="$HOME/bin/pair"

color() { printf '\033[1;36m%s\033[0m\n' "$1"; }
warn()  { printf '\033[1;33m%s\033[0m\n' "$1"; }
ok()    { printf '\033[1;32m%s\033[0m\n' "$1"; }

check_cmd() {
    local label="$1" cmd="$2" kind="$3"
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "  $label: $(command -v "$cmd")"
        return 0
    elif [ "$kind" = "required" ]; then
        warn "  $label: MISSING (required)"
        return 1
    else
        warn "  $label: not found (optional)"
        return 0
    fi
}

color "==> Checking prerequisites"
missing=0
check_cmd "go      " go     required || missing=1
check_cmd "git     " git    required || missing=1
check_cmd "nvim    " nvim   required || missing=1
check_cmd "claude  " claude required || missing=1
check_cmd "tmux    " tmux   optional
if [ "$missing" -ne 0 ]; then
    warn ""
    warn "Install the missing required commands and re-run."
    exit 1
fi

color "==> Building cairn-server"
( cd "$SERVER_DIR" && go build -o cairn-server . )
ok "  built $BIN_PATH"

color "==> Registering MCP server with Claude"
if command -v claude >/dev/null 2>&1; then
    if claude mcp list 2>/dev/null | grep -q '^cairn'; then
        ok "  cairn already registered, skipping"
    else
        claude mcp add cairn "$BIN_PATH" -s user
        ok "  registered cairn (user scope)"
    fi
else
    warn "  skipped: run 'claude mcp add cairn $BIN_PATH -s user' manually later"
fi

color "==> Linking code-tour skill"
mkdir -p "$(dirname "$SKILL_DST")"
if [ -L "$SKILL_DST" ] || [ -e "$SKILL_DST" ]; then
    ok "  $SKILL_DST already exists, skipping"
else
    ln -s "$SKILL_SRC" "$SKILL_DST"
    ok "  linked $SKILL_DST -> $SKILL_SRC"
fi

color "==> Installing pair helper"
if [ -d "$HOME/bin" ]; then
    if [ -e "$PAIR_DST" ]; then
        ok "  $PAIR_DST already exists, skipping"
    else
        ln -s "$PAIR_SRC" "$PAIR_DST"
        ok "  linked $PAIR_DST -> $PAIR_SRC"
    fi
else
    warn "  ~/bin not on disk; skipping. Add it to PATH and link $PAIR_SRC manually if you want the helper."
fi

cat <<EOF

$(color "Done. Remaining manual steps:")

  1. Add the LazyVim plugin spec at ~/.config/nvim/lua/plugins/cairn.lua:

       return {
         { dir = "$REPO_DIR", name = "cairn.nvim", lazy = false,
           config = function() require("cairn").setup() end },
       }

  2. (Optional, for pair mode) Add this UserPromptSubmit hook to ~/.claude/settings.json:

       {
         "hooks": {
           "UserPromptSubmit": [
             { "hooks": [ { "type": "command",
                            "command": "$BIN_PATH --drain-queue" } ] }
           ]
         }
       }

  3. Restart any existing Claude sessions so they re-read the MCP tool list.

  4. In Neovim, run ':CairnStatus' to confirm the plugin is listening.
EOF
