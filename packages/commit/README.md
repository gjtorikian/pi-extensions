# @nicknisi/pi-commit

AI-powered git commits for pi. Adds a `/commit` command that analyzes the current diff (staged, unstaged, and untracked files), streams it to the session's current model with a conventional-commit system prompt, shows the generated message, asks for confirmation, then runs `git commit` — optionally followed by `git push`. It can also produce a changelog bullet alongside the message. Ported from omp's commit pipeline; uses the provider `stream` API directly rather than spawning a subagent, so it uses the session's current model and auth.

## What it adds

- Slash command: `/commit`
- UI: `BorderedLoader` overlay while generating (abortable with Esc), `ctx.ui.confirm` dialog before committing, `ctx.ui.notify` for results/errors
- No tools, keybindings, widgets, events, or custom entry types

## Usage

```
/commit                    — generate a message from the diff, confirm, commit
/commit --push             — commit and then `git push`
/commit --dry-run          — show the generated message without committing
/commit --no-changelog     — skip changelog bullet generation
/commit -c "extra context" — pass free-text context to the model
```

Flags and short forms:

| Flag             | Short | Effect                                                      |
| ---------------- | ----- | ----------------------------------------------------------- |
| `--push`         | `-p`  | Run `git push` after a successful commit                    |
| `--dry-run`      | `-n`  | Print the message via notify; never commits                 |
| `--no-changelog` | —     | Don't request the changelog bullet                          |
| `--context`      | `-c`  | Everything after the flag is passed to the model as context |

Unknown non-flag arguments are also treated as context and concatenated, so `/commit fix the flaky timer test` works the same as `/commit -c fix the flaky timer test`.

Flow:

1. Verifies `ctx.cwd` is inside a git work tree (`git rev-parse --is-inside-work-tree`); errors out otherwise.
2. Collects `git diff --cached`, `git diff`, `git status --porcelain=v1`, and untracked files (`git ls-files --others --exclude-standard`).
3. If there are no changes at all, notifies "No changes to commit" and exits.
4. Builds a prompt with each section plus any `-c` context and a changelog request (unless `--no-changelog`).
5. Shows a `BorderedLoader` ("Generating commit message..."); Esc aborts the stream.
6. On success, if `--dry-run` was given, notifies the message and stops.
7. Otherwise shows a confirm dialog with the subject line. Confirm runs the commit; cancel aborts.
8. If nothing is staged, runs `git add -A` first. The message is written to a temp file and committed via `git commit -F <file>` to avoid shell-escaping issues. With `--push`, runs `git push` after. The `git commit` (and `git push`) stdout is shown in a notification.

## Model and prompt details

- Uses `ctx.model` (the session's current model). Auth comes from `ctx.modelRegistry.getApiKeyAndHeaders(model)`; throws a notify-visible error if no API key is configured.
- The prompt sent to the model includes the full conversation history: `ctx.sessionManager.buildContextEntries()` → `sessionEntryToContextMessages` → `convertToLlm`, followed by the diff as the final user message. This means the model can see what you were working on in the session, not just the diff.
- System prompt enforces conventional commits (`type(scope): description`), subject < 72 chars, imperative mood, optional 80-char-wrapped body, no AI co-author footers, raw output only.
- The changelog is requested via a `---CHANGELOG---` separator in the model's response; everything after it is treated as a single changelog bullet and displayed (but not written to any file).

## Configuration

None. No config files, no environment variables, no options beyond the command flags above.

## Dependencies

- `@earendil-works/pi-coding-agent` (peer) — `ExtensionAPI`, `ExtensionCommandContext`, `BorderedLoader`, `convertToLlm`, `sessionEntryToContextMessages`, `pi.registerCommand`, `ctx.ui.custom` / `confirm` / `notify`, `ctx.modelRegistry`, `ctx.sessionManager`
- `@earendil-works/pi-ai` (peer) — `Message` type
- `@nicknisi/pi-shared` (workspace) — `getModelProvider(ctx, model)`, which resolves the streaming `Provider` for the model from `ctx.modelRegistry` (throws if the provider isn't registered)
- Node builtins only otherwise: `child_process.execSync`, `fs`, `os`, `path`

## Caveats

- Depends on pi internals that are not guaranteed stable across versions: `sessionManager.buildContextEntries()`, `sessionEntryToContextMessages`, `convertToLlm`, the provider `stream(...).result()` shape, and the `BorderedLoader` TUI component. A pi upgrade may require touching `index.ts`.
- Git operations are synchronous (`execSync`), so large repos or slow hooks will block the UI during the commit step (not during generation).
- Diff gathering caps output at 10 MB per command (`maxBuffer`); very large diffs will be truncated by execSync throwing, which is swallowed as an empty string for `git diff` reads — the model may then see an incomplete diff.
- `git commit` runs without `--no-verify`, so commit hooks execute and their failure surfaces as a "git commit failed" notify.
- `git push` pushes the current branch with default remote/upstream config; no force-push or remote selection.
- Changelog output is display-only; nothing is written to `CHANGELOG.md`.
- Cross-platform (no macOS/tmux/ghostty specifics), but requires `git` on `PATH`.

## Install

```
pi install /Users/nicknisi/Developer/pi-extensions/packages/commit
```
