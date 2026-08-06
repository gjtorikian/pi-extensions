# @nicknisi/pi-dynamic-skills

Claude Code-style `` !`command` `` placeholder execution inside pi `SKILL.md` files. When a skill's `SKILL.md` contains dynamic-command placeholders, the extension runs them as shell commands at invocation time and inlines the output before the model ever sees the prompt. This lets skills embed live context (git state, `gh` output, file listings, etc.) instead of static text.

## What it adds

- **Events hooked:** `input`, `tool_result`
- **Slash commands:** none (it intercepts and rewrites pi's built-in `/skill:<name>` expansion)
- **Tools / keybindings / widgets / overlays / message types:** none

### Two expansion paths

1. **`/skill:name` invocations** — the `input` handler matches `^/skill:(\S+)(?:\s+([\s\S]*))?$`, looks up the skill via `pi.getCommands()` (`source === "skill"`), reads its `SKILL.md`, executes any placeholders, and returns `{ action: "transform", text }` replicating pi's built-in skill expansion (`content` + `\n\nUser: <args>` when args are present). If the file has no placeholders, it returns `{ action: "continue" }` and pi handles it normally.
2. **Agent `read` tool on a `SKILL.md`** — the `tool_result` handler fires when `toolName === "read"` and the input path ends with `SKILL.md`. Text blocks containing placeholders are rewritten with command output inlined, and the handler returns `{ content: newContent }`.

### Security boundary

Commands are executed **only** for `SKILL.md` files pi has registered as skills in the current session (resolved path in `pi.getCommands()` where `source === "skill"`). Reading an arbitrary `SKILL.md` — e.g. from a freshly cloned untrusted repo — never executes anything; the extension posts a `warning` notification (`Skipped !\`cmd\` expansion in unregistered …`) and passes the result through unchanged. Without this guard, `read`ing a hostile `SKILL.md` is remote code execution.

## Placeholder syntax

Mirrors Claude Code. Both forms are recognized by one regex:

- **Inline:** `` !`command` `` — recognized only when `!` starts a line or follows whitespace, so `` KEY=!`cmd` `` stays literal and does not execute.
- **Fenced block:** a fence opened with ` ```! ` for multi-line commands:

  ````
  ```!
  gh pr view --json title,body
  ```
  ````

Execution semantics:

- All matched commands run **in parallel** (`Promise.all` over `child_process.exec`).
- Replacement is index-based in reverse order; command output is never re-scanned for nested placeholders.
- `cwd` is the skill's base directory (`sourceInfo.baseDir`, falling back to `dirname(skillPath)`).
- Per-command limits: `timeout: 30_000` ms, `maxBuffer: 512 KiB`, UTF-8.
- If the command produces no stdout and no stderr and exits non-zero, the placeholder is replaced with `[!\`<label>\` failed: <err.message>]`where`<label>`is the first line of the command (suffixed with`…` for multi-line fenced blocks). If stdout or stderr is non-empty, that output is used (`.trim()`ed) even on non-zero exit.

## Usage

Write placeholders into a skill that pi discovers under a configured skill path:

````markdown
---
name: pr-summary
description: Summarize changes in a pull request
---

- PR diff: !`gh pr diff`
- Changed files: !`gh pr diff --name-only`

```!
gh pr view --json title,body
```
````

Summarize this pull request.

```

Then invoke:

```

/skill:pr-summary 123

````

An `info` notification (`Expanding dynamic commands in pr-summary…`) is shown while commands run; the model receives the fully expanded prompt.

## Configuration

None. No config files, no options, no environment variables.

## Dependencies

- `@earendil-works/pi-coding-agent` (peer, `*`) — `ExtensionAPI` surface used:
  - `pi.on("input", …)` / `pi.on("tool_result", …)` event hooks
  - `pi.getCommands()` — enumerates registered commands; relies on `source === "skill"` and `sourceInfo.path` / `sourceInfo.baseDir` to locate and validate skill files
  - `ctx.ui.notify()` for status/warning notifications; `ctx.cwd` for resolving relative read paths
- Node builtins only: `node:child_process` (`exec`), `node:fs`, `node:path`. No npm runtime dependencies.

## Caveats

- **Depends on pi internals.** The extension reaches into `pi.getCommands()` command metadata (`source`, `sourceInfo.path`, `sourceInfo.baseDir`) and reimplements pi's built-in skill expansion (`content + "\n\nUser: " + args`). If pi changes how skills are registered or expanded, the `/skill:` path can drift from core behavior.
- **`tool_result` shape.** Assumes `event.content` is an array of blocks with `type: "text"` and a `text` field, and that returning `{ content }` from a `tool_result` handler patches the result. Internal shapes; may change across pi versions.
- **Regex edge cases.** The inline form requires `!` at line start or after whitespace; a `` !`cmd` `` immediately following punctuation (e.g. `(!`cmd`)`) will not execute. Fenced blocks must occupy whole lines.
- **`exec` shell.** Commands run via `child_process.exec` (`/bin/sh -c` on POSIX). Only registered skills execute, but treat any registered skill's placeholders as trusted code with your user privileges.
- Path comparison uses `path.resolve` (symlinks are not canonicalized), so a skill read through a symlinked alias path will be treated as unregistered.

## Install

```bash
pi install /Users/nicknisi/Developer/pi-extensions/packages/dynamic-skills
````
