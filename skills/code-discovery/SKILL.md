---
name: code-discovery
description: Investigate code with the user through their Neovim editor when the destination is unknown. Use when they want to plan a change, understand how something works, or chase down a hypothesis — anything where the next step depends on what we find together. Dead ends are expected. The cairn plugin must be reachable. Distinct from code-tour, which traces a route you already know end-to-end; this is iterative threading. The two frames can pivot into each other.
---

# Code Discovery

Investigation, not exposition. The user doesn't know exactly where this goes, and neither do you. You're pulling threads together until they have enough for their next decision. The editor carries the visual load; chat stays short and names *why* you're looking at this next.

This skill is a frame, not the only way to use cairn. The cairn primitives can be used ad hoc; this is the shape that works well when the question is "let's figure out X" or "I'm planning to change Y and want to see the lay of the land first."

## Preflight

1. Call `cairn_status`. If it errors or returns unreachable, do the discovery in chat with `file:line` references and minimal excerpts. Don't try to reconnect mid-loop.
2. Pick an entry point — the file or symbol the user named, or `cairn_view` to start from their current cursor.
3. State the working question in one sentence if it's ambiguous ("ok so we're trying to find where the save-conflict check actually fires, right?"). Don't pre-plan a route past the first step; the next step is a function of what you find.

## The loop

Each iteration is roughly:

1. **Open** — `cairn_open(path, line)`. Never use `split`. The current buffer is replaced.
2. **Focus, optionally** — `cairn_highlight(path, start_line, end_line, label="…", group="discovery")` when there's a specific span the user should look at, or `cairn_annotate(path, line, text)` for a single-point note. Marks are dynamic here, not structural — they serve the current point of attention and get cleared as the thread shifts. Use them when they add clarity; skip them when a plain `cairn_open` is enough.
3. **Narrate** — 1-3 sentences. What this is, what you're looking for here, and what the hypothesis is. The user is reading the code in their editor; don't repeat it.
4. **Pull a thread** — pick the tool that fits the question:
   - `cairn_lsp_hover` — what type/signature is this?
   - `cairn_lsp_definition` — where is this declared?
   - `cairn_lsp_references` — who calls this / where is it used?
   - `cairn_lsp_workspace_symbol` — fuzzy/prefix symbol search. Check `clients_queried` to confirm the right server answered; an empty result with `kotlin_lsp` may just mean the query was too long (the server only matches short prefixes).
   - `cairn_diagnostics` — when compile/type errors might inform the path.
   - `cairn_ts_enclosing` / `cairn_ts_node_at` — when you need syntactic structure (e.g. "what function contains this position?").
   - `grep` — when LSP isn't the right shape (strings, comments, config keys) or has returned ambiguous results.
5. **Open the next thing.** Loop.

`cairn_clear(group="discovery")` between iterations when the previous step's marks are no longer relevant to the current point. Accumulating marks across a thread is fine if the user is comparing or building up context.

## Detours and pivots

- **Quick detour** — same affordance as code-tour: `cairn_snapshot("discovery_origin")` before diving into a side-question, `cairn_restore` after. Use when you'll want to return to the current thread.
- **Pivot to code-tour** — if the thread converges on a known flow the user wants walked end-to-end ("ok now let's actually trace the whole save pipeline"), propose handing off to `code-tour`. The frames are not exclusive; you can keep using cairn primitives during the handoff.
- **Pivot from code-tour** — if you're touring and hit an unknown branch, you can run a discovery loop until the route is clear, then resume the tour.

## Stopping

- The user has what they need ("ok, got it, that's enough to plan from") → stop. `cairn_clear()` any leftover marks.
- The thread dead-ends honestly — say so plainly, name what you tried, and offer alternative threads. Don't fake confidence.
- You've looped 5-6 times without progress — pause and reframe with the user before continuing.

## Hard rules

- **No excerpt walls.** The editor carries the code. If the user needs to see a chunk, `cairn_open` to it. Quote at most a single short line into chat when you're naming a specific token, never a span.
- **No split.** Replace the current buffer with `cairn_open`. Splits are for explicit side-by-side comparisons the user asks for.
- **No pre-planned route.** Each step is informed by the previous result, not by a route you mapped before the user got involved.
- **Surface dead ends and tool quirks.** "Hover returned empty here — kotlin_lsp's workspace_symbol is also prefix-only, let me grep" is more useful than silent fallback.
- **Clean up before stopping.** Marks left over from a discovery session pollute the user's view when they take the keyboard back.

## Fallback

If `cairn_status` reports unreachable, do the same investigation in chat with `file:line` references and minimal excerpts. Don't repeatedly retry the bridge.
