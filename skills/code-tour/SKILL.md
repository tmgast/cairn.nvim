---
name: code-tour
description: Guide the user through a code path in their Neovim editor using the cairn plugin. Use when the user asks for a walkthrough, tour, or step-by-step explanation of how a feature is wired together, and the cairn nvim plugin is reachable.
---

# Code Tour

Step-by-step guided walkthrough of code, driving the user's running Neovim session via the cairn MCP bridge. The editor carries the visual load; chat carries the explanation. Keep chat short per step.

## Preflight

1. Call `cairn_status`. If it errors or returns `connected: false`, fall back to chat-only excerpts and tell the user the plugin isn't reachable.
2. Confirm with the user what they want toured before driving their editor.

## Tour shape

A tour has three phases. Treat them as a hard structure.

### Enter

`cairn_snapshot("pre_tour")` — save the user's current working position so they can be returned to it.
`cairn_only(path=<entry_file>, close_buffers=true)` — clean canvas: one window, one buffer, no residue from prior work.

### Per checkpoint

For each step in the tour:

1. `cairn_open(path, line)` — surface the relevant file/line. Never use `split`. The current buffer is replaced.
2. `cairn_highlight(path, start_line, end_line, label="N: short title", group="tour")` — mark the range that matters. The default `focus: true` jumps the cursor and centers.
3. Optional `cairn_annotate(path, line, text)` for inline commentary at a specific point.
4. Explain in chat in 2-4 sentences. Stop and wait for the user to acknowledge or ask questions.
5. Before moving on, call `cairn_clear(group="tour")` to wipe the previous step's marks — unless the user is asking you to accumulate the path visually.

### Concept detour (mid-tour zoom-in)

When the user asks a question that requires looking at something outside the main tour line:

1. `cairn_snapshot("detour_origin")` — save where you were.
2. `cairn_open(...)`, `cairn_highlight(group="detour", ...)` — show the concept.
3. Explain. Pause for follow-up.
4. `cairn_clear(group="detour")` — wipe the detour marks.
5. `cairn_restore("detour_origin")` — return to the main tour line.

The "tour" group's marks are untouched throughout the detour.

### Exit

`cairn_clear()` — wipe every cairn mark.
`cairn_restore("pre_tour")` — put the user back where they were.

## Hard rules

- **Never use `split`** in `cairn_open` during a tour. Splits are reserved for explicit side-by-side comparisons the user asks for.
- **Never call `cairn_only` without confirming the user is okay with closing buffers** when `close_buffers=true` — they may have unsaved work.
- **One short chat message per checkpoint.** The editor's visual state is the main channel; don't dump prose.
- **Always restore.** If you snapshot, you owe a restore. Tours that leave the user on a different file than they started are jarring.

## Fallback

If `cairn_status` reports unreachable mid-tour, complete the rest of the tour as chat-only excerpts with `file:line` references — don't repeatedly retry the bridge.
