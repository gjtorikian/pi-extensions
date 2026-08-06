# @nicknisi/pi-agent-urls

`agent://` and `history://` URL tools for reading [pi-subagents](../pi-subagents) runs, outputs, and transcripts. The extension discovers past and in-flight subagent runs from session JSONL files, async-run status directories, artifact directories, and chain-run directories, assigns each run a stable `agent://<runId>` URI, and exposes both a slash command and two LLM tools for listing and reading them. It exists so that a parent agent (or the human at the prompt) can pull a child subagent's transcript or final output back into context after the run has finished, using a short URI instead of a long filesystem path.

## Install

```bash
pi install /Users/nicknisi/Developer/pi-extensions/packages/agent-urls
```

## What it adds

- Slash command: `/agent` (with `list`/`ls` and `read`/`show`/`cat` subcommands)
- Tool: `list_agent_runs` — list recent subagent runs and their `agent://` / `history://` URLs
- Tool: `read_agent_url` — read `agent://` and `history://` URLs (run summaries, child outputs, rendered transcripts, raw files)
- Custom message type: `agent-url` (results of `/agent` commands are posted into the conversation as `display: true` custom messages with `details.kind = "agent-url-command"`)
- Argument completion for `/agent`: completes `list`/`read`, then `agent://<runId>` / `history://<runId>` for the 20 most recent runs

No keybindings, widgets, overlays, or event hooks.

## URI scheme

```text
agent://<runId>                       run summary (source, mode, state, cwd, children, file paths)
agent://<runId>/<child>               child output (same as /output)
agent://<runId>/<child>/<leaf>        specific child content
history://<runId>                     rendered transcript for all children with a session file
history://<runId>/<child>             rendered transcript for one child
```

`<runId>` may be abbreviated to any unique prefix; ambiguous or unknown prefixes throw. `<child>` may be a child index (e.g. `0` or `run-0`) or an agent-name substring. `<leaf>` is one of:

- `output` / `result` — child output file, falling back to log file, falling back to the last assistant message of the session
- `history` — rendered transcript (messages only, `### user` / `### assistant` / `### toolResult` sections)
- `session` / `jsonl` — raw session JSONL (or artifact JSONL)
- `input` — artifact `_input.md`
- `meta` — artifact `_meta.json`
- `log` — async run `output-<index>.log`
- `summary` — per-child run summary

## Usage

Slash command:

```text
/agent list
/agent list workos
/agent read agent://3f9a1c2e
/agent read agent://3f9a1c2e/1/history
/agent read history://3f9a1c2e/0
```

`/agent read` without a URI, or an unknown subcommand, shows a usage warning via `ctx.ui.notify`.

Tool usage (as called by the LLM):

```json
{ "tool": "list_agent_runs", "params": { "query": "debrief", "limit": 10 } }
{ "tool": "read_agent_url", "params": { "uri": "agent://3f9a1c2e/0/output", "maxLines": 1000 } }
```

`list_agent_runs` also returns structured run data in `details.runs` for programmatic consumers; `read_agent_url` returns the rendered text with `details.uri` echoing the request.

## Run discovery

Runs are discovered on every invocation from four sources, merged by `runId` (the 8-char hex id):

1. **session** — session JSONL files under `~/.pi/agent/sessions/` matching `/<runId>/run-<n>/*.jsonl` (the layout written by pi-subagents' `session` mode). `cwd`, first user message (task, with a leading `Task:` stripped), and last assistant message are parsed out of the JSONL.
2. **async** — directories under `$TMPDIR/pi-subagents-uid-<uid>/async-subagent-runs/` containing a `status.json`. Steps (multi-step runs) or the top-level status become children; `events.jsonl` and `output-<index>.log` are attached when present.
3. **artifact** — files under `~/.pi/agent/sessions/**/subagent-artifacts/` named `<runId>_<agent>[_<index>]{_input.md,_output.md,_meta.json,.jsonl}`.
4. **chain** — directories under `$TMPDIR/pi-subagents-uid-<uid>/chain-runs/`; every `.md`/`.json` file inside becomes a child output.

Discovery caps: max depth 8 (7 for session scans, 5 for artifacts, 4 for chain dirs), max 2500 files per scan, `node_modules`/`.git` skipped, entries visited newest-first by mtime.

## Configuration

No config files are read. No per-run options.

Environment variables:

- `PI_CODING_AGENT_DIR` — pi agent directory. Defaults to `~/.pi/agent`. A leading `~/` is expanded. This determines where `sessions/` is scanned.

Constants (hardcoded in `index.ts`):

- `MAX_SCAN_FILES = 2500` — per-scan file cap
- `DEFAULT_LIMIT = 20` — runs listed by default (tool clamps `limit` to 1–100)
- `DEFAULT_MAX_LINES = 500` — rendered line cap for reads (tool clamps `maxLines` to 20–5000)

## Dependencies

- `@earendil-works/pi-coding-agent` (peer, `*`) — `ExtensionAPI` (`registerTool`, `registerCommand`, `sendMessage`) and `ExtensionCommandContext` (`ctx.ui.notify`) types/APIs only.
- Node builtins: `fs`, `os`, `path`. No npm runtime dependencies, no workspace deps.

## Caveats

- Depends on pi-internal file layouts that are not a stable API: the session JSONL schema (`session`/`message` entries, content block types `text`/`toolCall`/`thinking`), the `sessions/<runId>/run-<n>/` directory naming, and pi-subagents' tmpdir layout (`pi-subagents-uid-<uid>/async-subagent-runs`, `chain-runs`) and `status.json` shape. Any of these changing across pi or pi-subagents versions silently reduces discovery to partial or empty results (all parse failures are swallowed).
- Async/chain run discovery is POSIX-flavored: it uses `process.getuid()` (falls back to the literal string `user` when unavailable) to build the tmpdir path.
- Run ids are assumed to be 8 lowercase hex chars (`[0-9a-f]{8}`); runs with other id formats are invisible.
- Discovery is synchronous filesystem I/O on every command/tool call; very large `~/.pi/agent/sessions` trees are mitigated only by the depth/file caps.
- `history://` rendering drops `thinking` blocks and non-message entries; truncated reads append a `[truncated: N more line(s) in <file>]` marker.
- Results of `/agent` are injected as custom `agent-url` messages with `display: true`; themes or UIs that don't handle unknown custom message types may render them differently.
