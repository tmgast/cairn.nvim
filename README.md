# cairn.nvim

[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)
[![Build](https://github.com/tmgast/cairn.nvim/actions/workflows/build.yml/badge.svg)](https://github.com/tmgast/cairn.nvim/actions/workflows/build.yml)
[![Neovim](https://img.shields.io/badge/Neovim-0.10+-57A143?logo=neovim&logoColor=white)](https://neovim.io)

A Neovim plugin and MCP bridge that lets Claude work alongside you in your editor instead of running tasks in the background; guided tours, paired coding, live diff review, and direct access to LSP, treesitter, and git from the conversation.

## Features

- **Guided tours:** Claude opens files, highlights ranges with labels, annotates lines, and pauses for your acknowledgement at each step. Snapshot/restore round-trips for concept detours.
- **Diff review:** `cairn_diff_git` runs `:diffthis` against any git ref; `cairn_diff_suggest` shows side-by-side comparison of N inline content options with an info-tinted palette distinct from real git diffs.
- **Native LSP access:** references, definition, hover, workspace symbol search, diagnostics, plus a status tool to check whether a slow server (Kotlin, large TypeScript) is warm before issuing queries.
- **Treesitter queries:** AST node at position with parent chain, enclosing-node-by-type ("what function am I in?").
- **Git context:** per-line blame and per-file log, all returned as structured data.
- **Quickfix integration:** pipe LSP references or any location set into nvim's native quickfix list.
- **Pair mode:** `BufWritePost` diffs auto-inject into your next Claude message via a `UserPromptSubmit` hook, so saving feels like a chat update.

## Why

Agentic AI coding tools are very good at *doing things* on your behalf. They are much less good at keeping you informed about what they are doing, why, and what they noticed along the way. Left to defaults, an agentic workflow drifts into a workhorse pattern: you ask for a thing, the agent disappears for a few minutes, you accept or reject the diff, and you never build the same understanding the agent did. The codebase ends up in the agent's context, not yours.

Cairn is a deliberate counter to that. It gives the agent a way to *show you* what it's looking at: open the file, highlight the range, annotate the line, pause for your acknowledgement. It also gives you a way back into the loop, by selecting code, saving a buffer, or simply being where the work is happening. The result feels more like a pair-coding session than a delegated task. The agent moves at your tempo, you stay in your editor, and the codebase ends the session in your head as well as the agent's.

## How it works

The Lua plugin opens a Unix socket per project root (`$XDG_RUNTIME_DIR/cairn/<hash>.sock`). A small Go binary runs as a Claude Code stdio MCP server and forwards tool calls over that socket. Per-project sessions are naturally isolated by the socket hash, so cross-project state never collides.

## Install

### LazyVim (recommended)

Add to your lazy.nvim plugins:

```lua
{
  "tmgast/cairn.nvim",
  lazy = false,
  build = "cd server && go build -o cairn-server .",
  opts = {},
}
```

Then in any project's Neovim, once:

```vim
:CairnInstall
```

That registers `cairn-server` with `claude mcp add`, symlinks the `code-tour` skill into `~/.claude/skills/`, and prints the optional pair-mode hook snippet for you to paste into `~/.claude/settings.json`. Verify state any time with:

```vim
:checkhealth cairn
```

For local development against a working tree, replace the repo string with `dir = "~/projects/cairn.nvim"`.

### Shell installer (no lazy.nvim)

If you'd rather set up from the shell:

```sh
git clone git@github.com:tmgast/cairn.nvim.git ~/projects/cairn.nvim
~/projects/cairn.nvim/install.sh
```

`install.sh` builds `cairn-server`, registers it, symlinks the skill, and (if `~/bin` is on `$PATH`) installs the `pair` helper. It validates that `go`, `git`, `nvim`, and `claude` are on `$PATH` and exits cleanly if any are missing; it never auto-installs anything. You still need to add a plugin spec to your nvim config; the script prints one at the end.

### Pair-mode hook (optional)

Required only if you want `:CairnPair on` to push save-diffs into your next Claude message. Add to `~/.claude/settings.json`, merging with any existing `hooks` block:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "/absolute/path/to/cairn-server --drain-queue" }] }
    ]
  }
}
```

`:CairnInstall` prints this snippet with the correct path baked in.

## Tools (28)

### Navigation and view

| Tool | Purpose |
|---|---|
| `cairn_status` | Plugin reachable, project root, pair mode state |
| `cairn_open` | Open file at line |
| `cairn_view` | Current buffer, cursor, viewport bounds |
| `cairn_buffer_content` | In-memory content including unsaved edits |
| `cairn_selection` | The user's last visual selection |
| `cairn_clipboard` | Read a yank/clipboard register |

### Visual annotation

| Tool | Purpose |
|---|---|
| `cairn_highlight` | Mark line range with a label, focus and center cursor |
| `cairn_annotate` | Virtual-text annotation above, below, or end-of-line |
| `cairn_clear` | Clear marks by group, or all |

### Layout and state

| Tool | Purpose |
|---|---|
| `cairn_only` | Collapse splits; optional path-open and close-other-buffers |
| `cairn_close` | `:bdelete` a specific buffer |
| `cairn_snapshot` | Save current buffer and cursor under a name |
| `cairn_restore` | Jump back to a saved snapshot |

### Diff and review

| Tool | Purpose |
|---|---|
| `cairn_diff_git` | File vs git ref in side-by-side diff mode |
| `cairn_diff_suggest` | File vs N inline content suggestions, info-tinted palette |

### LSP

| Tool | Purpose |
|---|---|
| `cairn_lsp_status` | Attached clients, initialized state, capabilities |
| `cairn_lsp_references` | All references to symbol at position |
| `cairn_lsp_definition` | Definition location for symbol at position |
| `cairn_lsp_hover` | Type and docs for symbol at position |
| `cairn_lsp_workspace_symbol` | Name-based symbol search across workspace |
| `cairn_diagnostics` | Errors and warnings for a file or all buffers |

### Treesitter

| Tool | Purpose |
|---|---|
| `cairn_ts_node_at` | AST node at position with parent chain |
| `cairn_ts_enclosing` | Nearest enclosing node matching given types |

### Git

| Tool | Purpose |
|---|---|
| `cairn_git_blame` | Sha, author, timestamp, subject for a line |
| `cairn_git_log` | Recent commits, optionally scoped to a path |

### Workflow

| Tool | Purpose |
|---|---|
| `cairn_to_quickfix` | Populate nvim's quickfix list with a set of locations |

## Pair mode

`:CairnPair on` to enable. On `:w`, the plugin diffs the buffer against its last-seen state and appends an entry to `$XDG_STATE_HOME/cairn/queue-<root-hash>.jsonl`. When you next send a Claude message, the configured `UserPromptSubmit` hook drains the queue and prepends each diff as context.

The plugin watches `FileChangedShellPost` to refresh its "last seen" baseline when Claude's `Edit` tool writes to disk, so external edits don't pollute the next diff.

## Commands

| Command | Purpose |
|---|---|
| `:CairnInstall` | Run post-build setup: register MCP server, symlink skill, print pair-mode hook |
| `:CairnStatus` | Print server state |
| `:CairnPair on\|off\|toggle` | Toggle pair mode |
| `:CairnClear` | Clear all marks (also `<Esc>` by default) |
| `:CairnReload` | Reload all `cairn.*` modules cleanly |
| `:checkhealth cairn` | Report status of binary, MCP registration, skill, and hook |

## Customization

### Config

All options shown with their defaults:

```lua
require("cairn").setup({
  -- Bind <Esc> to clear all cairn marks alongside :nohlsearch. Set false
  -- to keep whatever your existing <Esc> mapping does.
  clear_on_escape = true,
})
```

### Highlight groups

All overridable in your colorscheme. Defaults are derived from your existing theme so cairn blends in:

- `CairnHighlight`: line-range marks (default: soft tint blended from `Search` bg with `Normal` bg)
- `CairnLabel`: labels next to highlights and annotations (default: links to `Comment`)
- `CairnDiffSuggestAdd` / `CairnDiffSuggestDelete` / `CairnDiffSuggestChange` / `CairnDiffSuggestText`: palette for `cairn_diff_suggest` panels (default: tinted from `DiagnosticInfo`)

## Requirements

- Neovim 0.10+ (uses `vim.api.nvim_win_set_hl_ns` and modern LSP APIs)
- Go 1.22+ to build the server
- Claude Code with MCP support
- `git` on PATH for `diff_git`, `git_blame`, `git_log`
- Treesitter parsers for any languages you want `ts_*` tools to work against

## License

MIT. See [LICENSE](LICENSE).

## Pair helper

`bin/pair [dir]` opens a tmux session named after the project basename with Claude in a 30% left pane and Neovim in the 70% right pane. If the session already exists, it attaches or switches to it. Installed automatically by `install.sh` when `~/bin` is on `$PATH`; otherwise link it manually:

```sh
ln -s ~/projects/cairn.nvim/bin/pair ~/bin/pair
```
