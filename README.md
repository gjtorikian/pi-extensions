# pi-extensions

Nick Nisi's pi extensions — a pnpm monorepo of independently installable [pi](https://github.com/badlogic/pi-mono) packages. Each package under `packages/` is a self-contained pi extension (or shared library) with its own `pi` manifest; install only the ones you want.

## Install

Packages are private (not on npm). Install from a local checkout:

```bash
git clone <this-repo> ~/Developer/pi-extensions
pi install ~/Developer/pi-extensions/packages/statusline   # absolute
pi install ../pi-extensions/packages/btw                   # relative to the settings file
```

Local paths are added to pi's settings without copying — edits in the repo are live on next pi start. Remove with `pi remove <path>`.

## Packages

### Productivity

| Package                              | What it does                                                                                                                             | Adds                                                |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| [answer](packages/answer/)           | Extracts questions from the last assistant message via a side LLM call, answers them in a tab-through overlay, sends one formatted reply | `/answer`, `ctrl+.`, Q&A overlay                    |
| [btw](packages/btw/)                 | Side-channel LLM chat in a floating window — sees branch context, never touches the main agent's context; promote or fork the thread     | `/btw`, overlay, `btw-answer` entry type            |
| [commit](packages/commit/)           | AI-generated conventional commits from the staged diff + session history                                                                 | `/commit` (`--push`, `--dry-run`, `--no-changelog`) |
| [handoff](packages/handoff/)         | Transfers context to a new linked session with a model-generated, editable prompt instead of compacting                                  | `/handoff <goal>`                                   |
| [llm-council](packages/llm-council/) | Multiple models answer in parallel as headless pi subprocesses; a chairman synthesizes                                                   | `llm_council` tool with live inline progress        |
| [orchestrate](packages/orchestrate/) | `/goal` keeps working until a condition holds; `/loop` re-runs a prompt on a timer                                                       | `/goal`, `/loop`                                    |
| [review](packages/review/)           | Interactive code review: pick a target, rubric-driven review on a labeled session branch, summarized wrap-up                             | `/review`, `/end-review`                            |
| [save-md](packages/save-md/)         | Export the latest assistant response to a markdown file                                                                                  | `/save-md <name>`                                   |

### UI & appearance

| Package                                      | What it does                                                                                                 | Adds                                        |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------- |
| [chat-input](packages/chat-input/)           | Config-driven boxed input editor; paste-again-to-expand for collapsed paste markers; tmux focus-aware border | custom editor component                     |
| [nicknisi-header](packages/nicknisi-header/) | Animated dashboard header (GIF-compiled truecolor frames or ASCII art) with session info, on fresh sessions  | `/nicknisi-header`, custom header           |
| [pin-last-prompt](packages/pin-last-prompt/) | Sticky bar pinning the owning user prompt while scrolled back in fullscreen (pi ≥ 0.84)                      | scrollback overlay bar                      |
| [recap](packages/recap/)                     | LLM "where was I" card injected into the transcript after idle minutes                                       | `/recap`, `/recap-idle`, `recap` entry type |
| [spinner-verbs](packages/spinner-verbs/)     | ~1000 rotating joke/meme phrases for the working spinner                                                     | —                                           |
| [statusline](packages/statusline/)           | Footer: model, cost, context bar, lines changed, usage limits, git PR link; writes tmux status files         | custom footer, `~/.cache/pi-status/`        |
| [turn-timer](packages/turn-timer/)           | Dim per-turn elapsed-time row below each response                                                            | `turn-duration` entry type                  |

### Behavior & plumbing

| Package                                            | What it does                                                                                                                 | Adds                                                |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| [agent-urls](packages/agent-urls/)                 | `agent://` / `history://` URIs for pi-subagents runs; list and read run outputs/transcripts                                  | `/agent`, `list_agent_runs`, `read_agent_url` tools |
| [artifacts](packages/artifacts/)                   | `artifact` tool: render markdown/HTML to styled browser pages from a lazy localhost server, with live reload                 | `artifact` tool, `/artifacts`                       |
| [auto-theme](packages/auto-theme/)                 | Sync pi theme with macOS system appearance (dark↔light pairs)                                                                | —                                                   |
| [claude-plugin-root](packages/claude-plugin-root/) | Sets `CLAUDE_PLUGIN_ROOT` and rewrites references in tool calls so Claude Code skills work under pi                          | —                                                   |
| [dynamic-skills](packages/dynamic-skills/)         | `` !`command` `` placeholders in SKILL.md files, executed at invocation with a strict registered-skills allowlist            | `input`/`tool_result` hooks                         |
| [magic-keywords](packages/magic-keywords/)         | Standalone prompt keywords (`ultrathink`, `orchestrate`) inject hidden per-turn guidance; `ultrathink` bumps thinking to max | —                                                   |
| [pi-cloak](packages/pi-cloak/)                     | Redact secrets from `read` tool results before they reach model context, via glob-scoped regex rules                         | `/cloak-status`, `cloak.json`                       |
| [session-name](packages/session-name/)             | Auto-name sessions (heuristic or LLM), mirror to terminal title, name-focused session picker                                 | `/sn`, `/sessions`                                  |
| [stash](packages/stash/)                           | `ctrl+s` parks the prompt draft on a LIFO stack; pop or auto-restore                                                         | `ctrl+s`, stash widget                              |

### Library

| Package                    | What it does                                                                                                                                                                                                                                                                           |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [shared](packages/shared/) | `@nicknisi/pi-shared` — helper library (not an extension): `getModelProvider` for one-off LLM calls, TUI utilities (gradient text, tree section removal, two-column layout, escape sanitization, render dispatcher), `SearchableSelectList`. Consumed via `workspace:*` by 8 packages. |

## Development

```bash
pnpm install
pnpm typecheck   # tsgo (TypeScript 7 native preview)
pnpm lint        # oxlint
pnpm fmt         # oxfmt
```

Layout: one directory per package in `packages/`, each with `index.ts` + `package.json` carrying a `pi` manifest (`"pi": { "extensions": ["./index.ts"] }`). Extensions ship TypeScript source directly — pi's loader handles it; there is no build step. `@earendil-works/*` packages are peer dependencies: pi's runtime aliases them to its own modules at load time, and the root devDependencies provide one canonical copy for typechecking (`autoInstallPeers: false` keeps it that way).

Cross-package helpers go in `packages/shared`, consumed as `"@nicknisi/pi-shared": "workspace:*"`.

## Notes

- Runtime configs live outside the repo: `~/.pi/agent/configs/<name>.json` for most packages. Example configs ship with the packages that need them.
- Several extensions lean on pi internals (component tree shapes, editor privates, fullscreen renderer state) — each README's caveats section calls these out; a pi upgrade can break them.
- macOS-centric: auto-theme, statusline's tmux integration, and btw's fork-to-window all assume macOS/tmux/ghostty.
