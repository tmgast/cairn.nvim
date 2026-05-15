package main

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
)

func registerTools(s *server.MCPServer) {
	s.AddTool(
		mcp.NewTool("cairn_status",
			mcp.WithDescription("Check whether the cairn nvim plugin is reachable for the current project root. Returns root path, socket path, and pair mode state."),
		),
		bridge("status"),
	)

	s.AddTool(
		mcp.NewTool("cairn_open",
			mcp.WithDescription("Open a file in the user's running Neovim, optionally jumping to a line. Default behavior replaces the current window's buffer (no split), which is what tours should use almost always."),
			mcp.WithString("path", mcp.Required(), mcp.Description("Absolute or repo-relative path to the file.")),
			mcp.WithNumber("line", mcp.Description("1-indexed line to jump to.")),
			mcp.WithString("split", mcp.Description("Split direction: 'none' (default, strongly preferred). Use 'horizontal' or 'vertical' ONLY when explicitly comparing two places side-by-side at the user's request. Tours should never split.")),
		),
		bridge("open"),
	)

	s.AddTool(
		mcp.NewTool("cairn_highlight",
			mcp.WithDescription("Mark a range of lines with a labeled highlight, visible in the user's Neovim. By default, also jumps the cursor to start_line and centers the view. Auto-grouped into the active tour."),
			mcp.WithString("path", mcp.Required(), mcp.Description("File path the range refers to.")),
			mcp.WithNumber("start_line", mcp.Required(), mcp.Description("1-indexed start line.")),
			mcp.WithNumber("end_line", mcp.Required(), mcp.Description("1-indexed end line, inclusive.")),
			mcp.WithString("label", mcp.Description("Short label shown alongside the highlight, e.g. '1: entry point'.")),
			mcp.WithString("group", mcp.Description("Group key for batched clearing. Defaults to 'tour'.")),
			mcp.WithBoolean("focus", mcp.Description("If true (default), jump the cursor to start_line and center the view. Set false to mark without changing focus, e.g. when placing several highlights before navigating.")),
		),
		bridge("highlight"),
	)

	s.AddTool(
		mcp.NewTool("cairn_annotate",
			mcp.WithDescription("Add virtual-text annotation at a specific line in a file, visible above/below/inline."),
			mcp.WithString("path", mcp.Required(), mcp.Description("File path.")),
			mcp.WithNumber("line", mcp.Required(), mcp.Description("1-indexed line.")),
			mcp.WithString("text", mcp.Required(), mcp.Description("Annotation text to display.")),
			mcp.WithString("position", mcp.Description("Placement: above, below, or eol. Defaults to above.")),
			mcp.WithString("group", mcp.Description("Group key for batched clearing.")),
		),
		bridge("annotate"),
	)

	s.AddTool(
		mcp.NewTool("cairn_clear",
			mcp.WithDescription("Clear cairn highlights and annotations. Omit group to clear everything."),
			mcp.WithString("group", mcp.Description("Group key to clear. Omit to clear all cairn marks.")),
		),
		bridge("clear"),
	)

	s.AddTool(
		mcp.NewTool("cairn_view",
			mcp.WithDescription("Report the user's current view: active file, cursor position, and viewport bounds."),
		),
		bridge("view"),
	)

	s.AddTool(
		mcp.NewTool("cairn_selection",
			mcp.WithDescription("Report the user's current or most recent visual selection: file, range, and selected text."),
		),
		bridge("selection"),
	)

	s.AddTool(
		mcp.NewTool("cairn_only",
			mcp.WithDescription("Collapse all splits to a single window. Optionally open a specific file as the sole visible buffer and/or :bdelete every other listed buffer for a true clean canvas. Use at tour start and tour end to give the user a known state."),
			mcp.WithString("path", mcp.Description("Optional file path. If provided, opens this file before collapsing splits.")),
			mcp.WithBoolean("close_buffers", mcp.Description("If true, :bdelete all listed buffers other than the current one. Use for true clean-slate.")),
		),
		bridge("only"),
	)

	s.AddTool(
		mcp.NewTool("cairn_close",
			mcp.WithDescription("Close a buffer with :bdelete. Defaults to the current buffer if no path is given."),
			mcp.WithString("path", mcp.Description("File path of the buffer to close. Omit to close current.")),
		),
		bridge("close"),
	)

	s.AddTool(
		mcp.NewTool("cairn_snapshot",
			mcp.WithDescription("Save the current buffer + cursor position under a name, for later restoration via cairn_restore. Use before a concept detour mid-tour so you can return cleanly. Snapshots do not include window layout or extmarks."),
			mcp.WithString("name", mcp.Description("Snapshot name. Defaults to '_last' if omitted.")),
		),
		bridge("snapshot"),
	)

	s.AddTool(
		mcp.NewTool("cairn_restore",
			mcp.WithDescription("Jump back to a previously saved snapshot's buffer and cursor. Use to return from a concept detour."),
			mcp.WithString("name", mcp.Description("Snapshot name to restore. Defaults to '_last' if omitted.")),
		),
		bridge("restore"),
	)

	s.AddTool(
		mcp.NewTool("cairn_diff_git",
			mcp.WithDescription("Open a file in vim's diff mode against its state at a given git ref. Use for code review (working copy vs HEAD, vs main, vs a commit). The reference panel is a read-only scratch buffer fed by 'git show'. Default colors via your colorscheme (typical github red/green)."),
			mcp.WithString("path", mcp.Required(), mcp.Description("File path to diff.")),
			mcp.WithString("ref", mcp.Description("Git ref to compare against. Defaults to 'HEAD'.")),
		),
		bridge("diff_git"),
	)

	s.AddTool(
		mcp.NewTool("cairn_diff_suggest",
			mcp.WithDescription("Compare a file against one or more inline content suggestions in diff mode. Each suggestion opens as its own read-only scratch buffer in a vsplit. All panels use the CairnDiffSuggest palette (info-color tinted) so they look distinct from a real git diff. Use when proposing implementation options to the user."),
			mcp.WithString("path", mcp.Required(), mcp.Description("File path of the base content.")),
			mcp.WithArray("suggestions", mcp.Required(),
				mcp.Description("Array of suggestion objects, each with required 'content' (full file content as string) and optional 'label' (short title shown in the buffer name)."),
			),
		),
		bridge("diff_suggest"),
	)

	s.AddTool(
		mcp.NewTool("cairn_lsp_references",
			mcp.WithDescription("Find all references to the symbol at a given file:line:col via the language server. Returns locations across the workspace with one-line previews. Requires an LSP attached to the file's filetype."),
			mcp.WithString("path", mcp.Required(), mcp.Description("File containing the symbol.")),
			mcp.WithNumber("line", mcp.Required(), mcp.Description("1-indexed line of the symbol.")),
			mcp.WithNumber("col", mcp.Required(), mcp.Description("1-indexed column on that line, pointing at the symbol's name.")),
			mcp.WithBoolean("include_declaration", mcp.Description("Include the declaration itself in results. Default true.")),
		),
		bridge("lsp_references"),
	)

	s.AddTool(
		mcp.NewTool("cairn_lsp_definition",
			mcp.WithDescription("Resolve the definition location of the symbol at a given file:line:col via the language server. Returns one or more locations."),
			mcp.WithString("path", mcp.Required(), mcp.Description("File containing the symbol use.")),
			mcp.WithNumber("line", mcp.Required(), mcp.Description("1-indexed line.")),
			mcp.WithNumber("col", mcp.Required(), mcp.Description("1-indexed column.")),
		),
		bridge("lsp_definition"),
	)

	s.AddTool(
		mcp.NewTool("cairn_lsp_hover",
			mcp.WithDescription("Return the language server's hover info (type, signature, doc comment) for the symbol at a given file:line:col."),
			mcp.WithString("path", mcp.Required(), mcp.Description("File containing the symbol.")),
			mcp.WithNumber("line", mcp.Required(), mcp.Description("1-indexed line.")),
			mcp.WithNumber("col", mcp.Required(), mcp.Description("1-indexed column.")),
		),
		bridge("lsp_hover"),
	)

	s.AddTool(
		mcp.NewTool("cairn_lsp_workspace_symbol",
			mcp.WithDescription("Search symbols across the workspace by name. Dispatches to every attached LSP client whose server advertises workspaceSymbolProvider, regardless of which buffer is currently focused; each returned symbol carries a 'client' field identifying its source. The response also includes 'clients_queried' so an empty 'symbols' array unambiguously means 'these servers responded with no matches' rather than 'no server was asked'. NOTE: matching strategy is server-defined and not always fuzzy. kotlin_lsp in particular only returns short name-prefix matches (roughly 1-4 chars); a long query like 'SaveSyncOrchestrator' will return [] even when the symbol exists. If a long Kotlin query returns empty but cairn_lsp_status shows kotlin_lsp healthy, retry with a 2-4 char prefix, or fall back to grep to locate a file and then use cairn_lsp_hover / cairn_lsp_definition on the name."),
			mcp.WithString("query", mcp.Required(), mcp.Description("Symbol name or name prefix to search for. Matching is server-defined; see tool description for kotlin_lsp's prefix-only quirk.")),
		),
		bridge("lsp_workspace_symbol"),
	)

	s.AddTool(
		mcp.NewTool("cairn_lsp_status",
			mcp.WithDescription("Report attached LSP clients and their initialized/capability state. Use before issuing expensive LSP queries to confirm the server is warm — large TypeScript projects and Kotlin servers can take 10-30 seconds to initialize. With a path, scopes to that buffer; without, returns all active clients."),
			mcp.WithString("path", mcp.Description("Optional file path. If given, reports clients attached to that buffer (loading the buffer first if needed). If omitted, reports all active clients.")),
		),
		bridge("lsp_status"),
	)

	s.AddTool(
		mcp.NewTool("cairn_diagnostics",
			mcp.WithDescription("Read LSP diagnostics (errors/warnings/info/hints) for a file or the whole workspace. Direct alternative to re-running compilation."),
			mcp.WithString("path", mcp.Description("Optional file path to scope diagnostics. Omit for all diagnostics across loaded buffers.")),
		),
		bridge("diagnostics"),
	)

	s.AddTool(
		mcp.NewTool("cairn_buffer_content",
			mcp.WithDescription("Return the in-memory content of a buffer, including unsaved edits. Use when the user is mid-edit and you need to see what they're actually looking at rather than the on-disk state."),
			mcp.WithString("path", mcp.Required(), mcp.Description("File path of the buffer.")),
			mcp.WithNumber("start_line", mcp.Description("Optional 1-indexed start line. Defaults to 1.")),
			mcp.WithNumber("end_line", mcp.Description("Optional 1-indexed end line, inclusive. Defaults to last line.")),
		),
		bridge("buffer_content"),
	)

	s.AddTool(
		mcp.NewTool("cairn_clipboard",
			mcp.WithDescription("Read the contents of a Vim register. Defaults to the unnamed register (last yank/delete). Useful when the user yanks code in nvim and asks Claude about it in the chat pane."),
			mcp.WithString("register", mcp.Description("Single character register name. Defaults to '\"' (unnamed). Common options: '+' system clipboard, '*' selection, '0' last yank, 'a'-'z' named.")),
		),
		bridge("clipboard"),
	)

	s.AddTool(
		mcp.NewTool("cairn_git_blame",
			mcp.WithDescription("Run `git blame` for a specific line of a file. Returns sha, author, timestamp, and summary of the commit that last touched the line. Useful for legacy-code archaeology."),
			mcp.WithString("path", mcp.Required(), mcp.Description("File path to blame.")),
			mcp.WithNumber("line", mcp.Required(), mcp.Description("1-indexed line number.")),
		),
		bridge("git_blame"),
	)

	s.AddTool(
		mcp.NewTool("cairn_git_log",
			mcp.WithDescription("Return recent commits, optionally scoped to a single file's history. Each commit has sha, author, timestamp, and subject."),
			mcp.WithString("path", mcp.Description("Optional file path. If given, scope log to commits touching that file.")),
			mcp.WithNumber("limit", mcp.Description("Max number of commits. Defaults to 20.")),
		),
		bridge("git_log"),
	)

	s.AddTool(
		mcp.NewTool("cairn_to_quickfix",
			mcp.WithDescription("Populate nvim's quickfix list with a set of locations and (by default) open the quickfix window. Pipe LSP references, search results, or any list of file:line locations so the user can navigate with native bindings like ]q/[q."),
			mcp.WithArray("locations", mcp.Required(), mcp.Description("Array of {file, line, col?, preview?} objects. The 'file' field is required per item.")),
			mcp.WithString("title", mcp.Description("Title for the quickfix list. Defaults to 'cairn'.")),
			mcp.WithBoolean("open", mcp.Description("Open the quickfix window after populating. Defaults to true.")),
		),
		bridge("to_quickfix"),
	)

	s.AddTool(
		mcp.NewTool("cairn_ts_node_at",
			mcp.WithDescription("Return the treesitter AST node at a file:line:col position, along with its parent chain. Useful when LSP isn't enough or you want syntactic structure (e.g. is this position inside a string literal?). Requires a treesitter parser for the file's language."),
			mcp.WithString("path", mcp.Required(), mcp.Description("File path.")),
			mcp.WithNumber("line", mcp.Required(), mcp.Description("1-indexed line.")),
			mcp.WithNumber("col", mcp.Required(), mcp.Description("1-indexed column.")),
		),
		bridge("ts_node_at"),
	)

	s.AddTool(
		mcp.NewTool("cairn_ts_enclosing",
			mcp.WithDescription("Find the nearest enclosing treesitter node at a position whose type matches one of the provided types. Use to ask 'what function/class/method contains this cursor position?'. Node type names are language-specific (e.g. 'function_declaration', 'method_definition', 'class_declaration')."),
			mcp.WithString("path", mcp.Required(), mcp.Description("File path.")),
			mcp.WithNumber("line", mcp.Required(), mcp.Description("1-indexed line.")),
			mcp.WithNumber("col", mcp.Required(), mcp.Description("1-indexed column.")),
			mcp.WithArray("types", mcp.Required(), mcp.Description("Array of treesitter node type strings to search for, walking up from the cursor.")),
		),
		bridge("ts_enclosing"),
	)
}

func bridge(method string) func(context.Context, mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		params := req.GetArguments()
		if params == nil {
			params = map[string]any{}
		}
		result, err := sendRequest(method, params)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("cairn plugin unreachable: %v", err)), nil
		}
		b, err := json.Marshal(result)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("marshal result: %v", err)), nil
		}
		return mcp.NewToolResultText(string(b)), nil
	}
}
