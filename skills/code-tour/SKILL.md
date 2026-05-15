---
name: code-tour
description: Map a known end-to-end code flow with the user through their Neovim editor. Use when they explicitly ask to be walked through, toured through, or shown step-by-step how a feature is wired together along a route you already know — not for open-ended "show me X" or investigative questions (use code-discovery for those). The cairn plugin must be reachable. The editor carries the visual load; you carry the explanation.
---

# Code Tour

A cairn tour is a pair-coding session along a known route, not a lecture and not an investigation. You already know roughly where the flow goes; the tour traces it with the user. The editor carries the visual load — open the file, highlight the range, annotate the line — so chat can stay short and focus on the *why*. The user should end the tour with the code in their head, not just yours.

If you reach a point where the route forks and you don't actually know which branch to take, or the user asks a question that opens an unknown, that's a discovery moment — pivot to `code-discovery` (or run a concept detour, below, if it's a quick zoom-in and you can return to the route). Tours and discovery are frames, not exclusive modes; they're allowed to interleave.

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
