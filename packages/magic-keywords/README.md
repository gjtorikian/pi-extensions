# @nicknisi/pi-magic-keywords

Standalone keywords typed in a user prompt that inject hidden per-turn instructions and (for `ultrathink`) temporarily bump the thinking level. Ported from omp's magic-keywords feature. The keyword stays visible in your prompt; the injected guidance is hidden from the conversation and added to the system prompt for that turn only.

## Install

```bash
pi install /Users/nicknisi/Developer/pi-extensions/packages/magic-keywords
```

## Keywords

| Keyword       | Effect                                                                                                                                                                                                            |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ultrathink`  | Bumps thinking level to `max` for the turn, then restores the previous level after the agent settles. Injects guidance to reason carefully through the task, consider edge cases and failure modes before acting. |
| `orchestrate` | Injects guidance to scope the full task, delegate substantial independent work in parallel to subagents, and verify each phase's output before continuing.                                                        |

### Matching rules

- Case-sensitive, lowercase only. `Ultrathink` does not trigger.
- Must be a standalone word. Punctuation may touch it, but identifiers, inflections, paths, and file extensions do not match.
  - Matches: `ultrathink, please fix this`
  - No match: `ultrathinking`, `ultrathink.ts`, `/ultrathink`
- Keywords inside fenced code blocks (` ``` `) or inline code spans (`` ` ``) are ignored.
- Detection happens on raw input in the `input` event, before skill/template expansion.

## Usage

```text
ultrathink, why is this auth token refresh racing on tab close?
```

```text
orchestrate migrate the settings schema and update all consumers
```

Both keywords can appear in one prompt; their instruction blocks are concatenated.

When a keyword is recognized, the status bar shows:

```text
✨ ultrathink, orchestrate
```

The status clears when the agent settles.

## What it adds

- **Keywords**: `ultrathink`, `orchestrate` (prompt text, not slash commands)
- **Status indicator**: `magic-keywords` status segment via `ctx.ui.setStatus` (TUI only)
- **Events hooked**:
  - `input` — scans raw user text for keywords before expansion
  - `before_agent_start` — appends a `<keyword-guidance>` block to `event.systemPrompt` and bumps the thinking level via `pi.setThinkingLevel("max")`
  - `agent_settled` — restores the saved thinking level and clears pending state (handles retries, since it runs after the full interaction rather than per-turn)

No slash commands, tools, keybindings, overlays, or custom entry/message types.

## Injected system prompt block

```xml
<keyword-guidance>
[ultrathink] Reason carefully through this multi-step task. ...

[orchestrate] Scope the full task first, then delegate substantial ...
</keyword-guidance>
```

## Configuration

None. No config files, no options, no environment variables. Keywords and their instructions are hardcoded in `KEYWORDS` in `index.ts`.

## Behavior notes

- `ultrathink` only bumps the level if the current level is below `max`; if you're already at `max`, nothing is saved or restored. `pi.getThinkingLevel()` / `pi.setThinkingLevel()` are session-scoped.
- The restore happens on `agent_settled`, so a turn that errors or retries still restores the level once the interaction fully settles.
- State (`pendingKeywords`, `savedThinkingLevel`) is module-level and session-scoped; it resets on session start.

## Dependencies

- `@earendil-works/pi-coding-agent` (peer) — `ExtensionAPI` type; runtime use of `pi.on`, `pi.getThinkingLevel`, `pi.setThinkingLevel`, `ctx.ui.setStatus`, `ctx.hasUI`.

No npm dependencies, no workspace dependencies.

## Caveats

- Depends on pi events `input`, `before_agent_start`, and `agent_settled`, and on the `getThinkingLevel`/`setThinkingLevel` API surface — all pi internals that could change across versions. `getThinkingLevel()` is cast to the local `ThinkingLevel` union (`"off" | "minimal" | "low" | "medium" | "high" | "xhigh" | "max"`); if pi adds/renames levels, the bump/restore logic needs updating.
- `orchestrate` references "the subagent tool" in its injected instruction; if no subagent-capable tool (e.g. pi-subagents) is installed, the model may attempt to call a tool that doesn't exist.
- Status indicator is TUI-only; in headless mode (`ctx.hasUI === false`) keywords still function silently.
