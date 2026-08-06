# @nicknisi/pi-review

Interactive `/review` command for pi, modeled on Codex's review feature. Picks a review target (uncommitted changes, a base branch PR-style diff, a specific commit, or custom instructions), builds a structured review prompt from an embedded rubric, and sends it as a user message. Optionally runs the review on a fresh session-tree branch so the main conversation stays clean, with `/end-review` to summarize the findings and jump back to where you started.

## Install

```bash
pi install /Users/nicknisi/Developer/pi-extensions/packages/review
```

## What it adds

- Commands: `/review`, `/end-review`
- Widget: `review` — a persistent banner (`Review session active, return with /end-review`) shown while a fresh-session review branch is active
- Session-tree branch labeled `code-review` when using fresh-session mode
- Custom TUI overlays (via `ctx.ui.custom`) for preset/branch/commit selection

No tools, keybindings, events, or custom message/entry types.

## Usage

`/review` requires interactive mode (`ctx.hasUI`) and a git repository (`git rev-parse --git-dir` must succeed).

### Direct invocation

```text
/review                              # interactive preset selector
/review uncommitted                  # staged, unstaged, and untracked changes
/review branch main                  # diff against a base branch (PR style)
/review commit abc123                # specific commit
/review commit abc123 fix the bug    # specific commit, with an explicit title
/review custom check for SSRF in the fetch handlers
```

Unknown or incomplete arguments fall back to the interactive selector.

### Interactive selector

Bare `/review` opens a preset picker:

1. `Review against a base branch` (PR style)
2. `Review uncommitted changes`
3. `Review a commit`
4. `Custom review instructions`

The list is reordered so a smart default comes first, based on git state:

1. Uncommitted changes exist → `uncommitted`
2. On a feature branch (current branch ≠ default branch) → `baseBranch`
3. Otherwise → `commit`

Sub-pickers:

- **Base branch**: searchable list of local branches (`git branch --format=%(refname:short)`), default branch sorted first and tagged `(default)`. The default branch is resolved from `refs/remotes/origin/HEAD`, falling back to `main`/`master` existence, then `main`.
- **Commit**: searchable list of the 20 most recent commits from `git log --oneline -n 20`.
- **Custom**: `ctx.ui.editor` free-text input.

### Session mode

If the session already contains messages, you are asked where to run the review:

- `Empty branch` (fresh session): navigates the session tree to the first user message with label `code-review`, clears the editor, shows the `review` widget, and records the origin leaf id. Only one fresh-session review can be active at a time (module-level state; a second `/review` warns to run `/end-review` first).
- `Current session`: sends the review prompt inline. No branch, no widget, no `/end-review` bookkeeping.

In a brand-new session (no messages), the review runs in the current session without asking.

### `/end-review`

Only valid during a fresh-session review; otherwise it notifies and exits. Asks `Summarize review branch?`:

- `Summarize` (default): shows a `BorderedLoader` spinner while `ctx.navigateTree` returns to the origin with `summarize: true` and a custom summary prompt tuned for reviews (captures scope, P0–P3 findings, verdict, next steps). On success it clears the widget and pre-fills the editor with `Act on the code review` if empty.
- `No summary`: navigates back without summarizing.

Cancelling the choice, aborting the spinner, or a navigation error leaves the review state intact so `/end-review` can be retried.

### Review prompt

Every review prepends an embedded rubric (adapted from Codex's `review_prompt.md`) to the target-specific prompt: what to flag, untrusted-input rules (open redirects, unparametrized SQL, SSRF on user-supplied URLs, escape-don't-sanitize), comment style, priorities, P0–P3 tagging, and an output format ending in a `correct` / `needs attention` verdict. For base-branch reviews it resolves the merge base first — `git merge-base HEAD <upstream>` if the branch has an upstream, else `git merge-base HEAD <branch>` — and embeds the SHA in the prompt; if no merge base is found it falls back to instructions telling the agent to compute it.

## Configuration

None. No config files, no options, no environment variables.

## Dependencies

- `@earendil-works/pi-coding-agent` (peer): `ExtensionAPI`, `ExtensionContext`, `ExtensionCommandContext` types; `DynamicBorder`, `BorderedLoader` components. Uses `pi.registerCommand`, `pi.exec`, `pi.sendUserMessage`, `ctx.ui.custom` / `.select` / `.editor` / `.notify` / `.setWidget` / `.setEditorText` / `.getEditorText`, `ctx.sessionManager.getLeafId` / `.getEntries`, and `ctx.navigateTree`.
- `@earendil-works/pi-tui` (peer): `Container`, `Text`, `SelectList`, `SelectItem`.
- `@nicknisi/pi-shared` (workspace): `SearchableSelectList` for the filterable branch/commit pickers.

No npm runtime dependencies.

## Caveats

- Depends on pi internals that may change across versions: `ctx.navigateTree` (session-tree branching and summarization options `summarize`, `customInstructions`, `replaceInstructions`, `label`), `ctx.sessionManager.getEntries()` entry shapes (`e.type === "message"`, `e.message.role`), and `ctx.ui.setWidget` semantics. These are not stable public APIs.
- Review state (`reviewOriginId`) is module-level: only one active fresh-session review per pi process, and it does not survive a restart — after reloading the session, `/end-review` will report "Not in a review branch" even if you are sitting on a `code-review` tree branch.
- `/end-review` is meaningless for current-session reviews (no branch to return to); it says so when invoked.
- All git probing shells out via `pi.exec`; behavior depends on the repo state (upstream tracking branches, `origin/HEAD` symref) rather than any libgit binding.
- The commit selector only lists the 20 most recent commits; older commits require `/review commit <sha>`.
- No platform-specific behavior (no macOS/tmux/ghostty assumptions).
