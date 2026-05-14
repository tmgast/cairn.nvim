# cairn

A Neovim plugin and MCP bridge that lets Claude drive your editor: guided tours, paired coding, diff review, and direct access to LSP, treesitter, and git from your conversation.

## Why

AI coding tends to pull attention out of the editor and into a chat window. Cairn flips that: the editor stays the canvas, and Claude operates on it through structured gestures — open a file, highlight a range, annotate, snapshot a position, diff against git. Tours start to feel like a knowledgeable colleague walking you through code instead of pasting excerpts into chat.

## How it works

The Lua plugin opens a Unix socket per project root (`$XDG_RUNTIME_DIR/cairn/<hash>.sock`). A small Go binary runs as a Claude Code stdio MCP server and forwards tool calls over that socket. Per-project sessions are naturally isolated by the socket hash, so cross-project state never collides.

## Install

### Quick install

```sh
git clone <repo> ~/projects/cairn
cd ~/projects/cairn
./install.sh
```

The script builds `cairn-server`, registers it with `claude mcp add`, symlinks the `code-tour` skill into `~/.claude/skills/`, and (if `~/bin` exists on `$PATH`) installs the `pair` helper. It prints the remaining manual steps — adding the LazyVim plugin spec and the optional pair-mode hook — at the end.

### Manual install

If you prefer to do it piece by piece:

1. **Plugin** — add to your lazy.nvim spec:

   ```lua
   return {
     { dir = "~/projects/cairn", name = "cairn.nvim", lazy = false,
       config = function() require("cairn").setup() end },
   }
   ```

2. **MCP server**:

   ```sh
   cd cairn/server
   go build -o cairn-server .
   claude mcp add cairn $(pwd)/cairn-server -s user
   ```

3. **Code-tour skill** (optional, teaches Claude the tour pattern):

   ```sh
   ln -s ~/projects/cairn/skills/code-tour ~/.claude/skills/code-tour
   ```

4. **Pair-mode hook** (optional) — add to `~/.claude/settings.json`:

   ```json
   {
     "hooks": {
       "UserPromptSubmit": [
         { "hooks": [{ "type": "command", "command": "/absolute/path/to/cairn-server --drain-queue" }] }
       ]
     }
   }
   ```

Then `:CairnPair on` in nvim. Off by default.

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
| `:CairnStatus` | Print server state |
| `:CairnPair on\|off\|toggle` | Toggle pair mode |
| `:CairnClear` | Clear all marks (also `<Esc>` by default) |
| `:CairnReload` | Reload all `cairn.*` modules cleanly |

## Customization

```lua
require("cairn").setup({
  clear_on_escape = true,  -- default true; disable to keep your own <Esc> binding
})
```

Highlight groups, all overridable in your colorscheme:

- `CairnHighlight` — line-range marks (default: soft tint blended from `Search` bg)
- `CairnLabel` — labels (default: links to `Comment`)
- `CairnDiffSuggestAdd` / `Delete` / `Change` / `Text` — suggestion-diff palette (default: tinted from `DiagnosticInfo`)

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
ln -s ~/projects/cairn/bin/pair ~/bin/pair
```
