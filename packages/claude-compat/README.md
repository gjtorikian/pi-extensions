# @nicknisi/pi-claude-compat

Claude Code compatibility for pi — two independent shims that let Claude Code-origin skills run unmodified:

1. **`CLAUDE_PLUGIN_ROOT` resolution** (`index.ts`) — CC skills reference files and scripts via `${CLAUDE_PLUGIN_ROOT}`, which pi does not set. This shim discovers loaded skills' package roots and transparently rewrites the variable in tool calls to real paths.
2. **`` !`command` `` dynamic placeholders** (`dynamic-skills.ts`) — CC-style dynamic-command placeholders in `SKILL.md` files, executed at invocation time with output inlined before the model sees the prompt, guarded by a strict registered-skills allowlist.

---

Compatibility shim that makes Claude Code-origin skills work under pi. Claude Code sets `${CLAUDE_PLUGIN_ROOT}` to the root of the plugin a skill belongs to, and CC skills (ideation, image-gen, etc.) reference files and scripts via that variable. Pi does not set it, so ported skills break when they try to read references or run scripts. This extension discovers the package roots of all loaded skills and transparently resolves `${CLAUDE_PLUGIN_ROOT}` references — the model writes the variable as it always does, and the extension silently rewrites it to a real path.

## What it adds

No slash commands, tools, keybindings, widgets, or entry types. It is entirely passive: two event hooks plus one environment variable.

- **Event `session_start`** — calls `pi.getCommands()`, filters to commands with `source === "skill"`, derives each skill's package root from its `sourceInfo.path`, and collects unique roots.
- **Event `tool_call`** — rewrites `CLAUDE_PLUGIN_ROOT` references in the `bash` tool's `input.command` and the `read` tool's `input.path` before execution.
- **Environment variable `CLAUDE_PLUGIN_ROOT`** — set on `process.env` at session start to the first discovered package root, so plain shell expansions (`$CLAUDE_PLUGIN_ROOT`) work in the single-package case.

## How it works

### Root discovery

Skill paths follow the convention `<package-root>/skills/<skill-name>/SKILL.md`, so the package root is three levels up from the skill file (`SKILL.md` → `<skill-name>/` → `skills/` → `<package-root>/`). All unique roots are kept in an in-memory array, rebuilt on every `session_start`.

### Rewriting

Two forms are handled:

- Single-package: `process.env.CLAUDE_PLUGIN_ROOT` is set, so bash expansions of `$CLAUDE_PLUGIN_ROOT` resolve naturally.
- Multi-package (or any case): the `tool_call` interceptor matches the pattern `${CLAUDE_PLUGIN_ROOT}/path`, `$CLAUDE_PLUGIN_ROOT/path`, and a bare `${CLAUDE_PLUGIN_ROOT}` (no trailing path). For a reference with a path, it tries each known root with `existsSync()` and substitutes the first root where the file exists. If none match, it falls back to the first root. A bare reference is replaced with the first root directly.

## Usage

No configuration. Once installed and loaded, ported CC skills that reference `${CLAUDE_PLUGIN_ROOT}` work without modification:

```bash
# In a skill ported from Claude Code:
read ${CLAUDE_PLUGIN_ROOT}/references/schema.md
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sync.sh
```

Both resolve to real paths under the skill's package root before the tool runs.

## Configuration

None. No config files, no options, no user-facing environment variables. `CLAUDE_PLUGIN_ROOT` is written (not read) by the extension.

## Dependencies

- Peer: `@earendil-works/pi-coding-agent` — uses `ExtensionAPI.on("session_start")`, `ExtensionAPI.on("tool_call")`, and `pi.getCommands()`.
- Node builtins only: `node:fs` (`existsSync`), `node:path` (`dirname`, `join`).

No workspace deps, no npm deps.

## Caveats

- **Pi internals**: depends on the shape of `pi.getCommands()` entries — specifically `source === "skill"` and `sourceInfo.path`. If pi changes how skill commands are tagged or where their paths live, root discovery silently yields zero roots and the extension becomes a no-op.
- **Heuristic resolution**: in the multi-package case, a `${CLAUDE_PLUGIN_ROOT}/path` reference resolves to the first root where the file _exists_. Two skills shipping a file at the same relative path can resolve to the wrong package.
- **Fallback is arbitrary**: when no root contains the referenced file, the first discovered root is substituted — discovery order is `getCommands()` order, not sorted.
- **Only `bash` and `read` are intercepted.** References inside other tools' inputs (e.g. `edit`, `write`) are not rewritten.
- **String-level rewrite**: the regex `/\$\{?CLAUDE_PLUGIN_ROOT\}?(?:\s*\/([^\s;|&"'()]+))?/g` operates on raw text. Paths containing spaces, semicolons, quotes, or parentheses after the variable will be truncated or missed.
- **Mutation of tool input**: the interceptor rewrites `event.input` in place. Behavior relies on pi applying tool-call input mutations from event handlers; a pi version that freezes inputs would break this.
- `process.env.CLAUDE_PLUGIN_ROOT` is a single value, so in multi-package sessions plain shell expansions of `$CLAUDE_PLUGIN_ROOT` (that the interceptor misses) resolve to the first package, which may be wrong.

## Install

```bash
pi install /Users/nicknisi/Developer/pi-extensions/packages/claude-plugin-root
```

---

# Part 2: `!`command`` dynamic skill placeholders

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
