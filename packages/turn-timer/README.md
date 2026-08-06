# @nicknisi/pi-turn-timer

Shows how long each full turn took — assistant response plus tool calls plus tool results — as a dim one-line row rendered below the response, similar to Claude Code's per-turn elapsed timer. It exists because pi has no built-in per-turn timing display. One row is emitted per turn (not per assistant message), so tool-call batches within a turn share a single timer.

## What it adds

- **UI:** a custom transcript entry renderer that draws a dim text row of the form `· 12.3s` (or `· 1m 23s` for ≥ 60s) after each completed turn.
- **Events hooked:** `turn_start` (records the start timestamp), `turn_end` (computes elapsed time and appends the entry).
- **Custom entry type:** `turn-duration`, with data shape `{ seconds: number }`.

No slash commands, tools, keybindings, or overlays. No configuration.

## Behavior details

- The entry is a custom transcript entry that does **not** participate in LLM context, so it never pollutes the conversation.
- `/copy` reads only assistant message text, so it never picks up the timer rows.
- Timing starts from `event.timestamp` on `turn_start` if present, falling back to `Date.now()`. Elapsed time is computed with `Date.now()` at `turn_end`.
- If `turn_end` fires without a prior `turn_start` (e.g. extension loaded mid-turn), the event is ignored.
- Duration formatting: `< 60s` → `Ns.s` (one decimal, e.g. `0.8s`); `≥ 60s` → `Mm Ss` (e.g. `1m 23s`).

## Configuration

None. No config files, no options, no environment variables.

## Dependencies

- `@earendil-works/pi-coding-agent` (peer) — `ExtensionAPI`: `registerEntryRenderer`, `on`, `appendEntry`.
- `@earendil-works/pi-tui` (peer) — `Text` component used to render the row.

No npm runtime dependencies, no workspace deps.

## Caveats

- Depends on pi extension internals: `registerEntryRenderer`, `appendEntry`, and the `turn_start` / `turn_end` event names (including `turn_start`'s `timestamp` field). A pi release that renames these APIs or events breaks the extension.
- Relies on the theme's `"dim"` foreground color existing; unusual themes could render the row differently.
- Uses wall-clock time (`Date.now()`), so the measurement includes any time the session sat idle mid-turn (e.g. waiting on an interactive tool prompt or permission prompt).
- No platform-specific behavior; works anywhere pi runs.

## Install

```bash
pi install /Users/nicknisi/Developer/pi-extensions/packages/turn-timer
```
