# @nicknisi/pi-claude-plugin-root

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
