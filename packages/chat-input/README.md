# @nicknisi/pi-chat-input

Replaces pi's input editor with a configurable boxed input rendered inside pi's
TUI. All native editor features — cursor movement, history, autocomplete,
paste — work normally inside the box. It also implements paste-again-to-expand:
when a collapsed `[paste #N ...]` marker is present in the editor, pasting the
same content again expands it inline so you can see and edit the actual text.

Evolved from the earlier single-file `box-editor.ts`: rendering is now
config-driven and the paste-expand behavior was merged in from the former
standalone `paste-expand.ts` so the two features don't fight over
`setEditorComponent` (last call wins).

## What it adds

- **Custom editor component** via `ctx.ui.setEditorComponent` (no slash
  commands, no tools, no keybindings, no custom entry types).
- **Events hooked**: `session_start` (installs the editor component) and
  `session_shutdown` (removes it and tears down focus tracking). TUI mode
  only; both handlers no-op when `ctx.mode !== "tui"`.
- **Paste-again-to-expand**: overrides the editor's `handlePaste` to detect
  when an incoming paste matches an already-collapsed paste's stored content;
  if the marker `[paste #N ...]` is still in the buffer, the marker is replaced
  with the real content and the paste registry is renumbered to stay dense.

## Features

- **Rounded or square box**: `╭╮│╰╯` (default, preserves the original look) or `┌┐│└┘`
- **Configurable prefix glyph** on the first body line (default `❯`); continuation lines get a space so content aligns
- **Theme-aware colors**: border and prefix accept any theme colour token or hex value
- **Boxed / unboxed**: full box with side borders, or top/bottom horizontal rules only
- **Menu outside box**: slash-menu lines render below the box, with configurable gap and indent
- **Scroll indicators**: pi's stock `↑ N more` / `↓ N more` indicators are detected in the stock borders and re-embedded in the replacement borders
- **Responsive**: below a minimum width (see caveats) the extension defers to pi's stock editor rendering
- **Focus indicator**: border switches colour when the tmux pane holding this session has terminal focus (requires tmux `focus-events on`)

## Install

```sh
pi install /path/to/pi-extensions/packages/chat-input
```

## Usage

Once installed, there is nothing to invoke — the editor component is installed
automatically at session start. Editing, history, autocomplete, and paste
behave as usual inside the box.

Paste-again-to-expand works automatically too: pi collapses large pastes
(>10 lines or >1000 chars) into `[paste #N +X lines]` markers; paste the same
content a second time while the marker is present and it expands inline. The
comparison replicates pi-tui's paste cleanup (CSI-u Ctrl+letter decoding,
CRLF→LF, tabs→4 spaces, non-printable stripping) and also tolerates a single
leading space that pi prepends to path-like pastes.

Layout (boxed):

```
╭──────────────────────────╮
│ ❯ <content>               │
│   <content continued>     │
╰──────────────────────────╯
<autocomplete menu>
```

## Configuration

Config is read once at extension load from
`~/.pi/agent/configs/chat-input.json` — restart pi to apply changes. Missing
file or invalid JSON falls back to all defaults silently. Copy
`chat-input.example.json` from this package as a starting point.

```json
{
  "boxedView": true,
  "boxPadX": 1,
  "menuGap": 0,
  "extraMenuIndent": 1,
  "borderColor": "border",
  "prefix": "❯",
  "prefixColor": "accent",
  "corners": "rounded",
  "focusIndicator": true,
  "focusedBorderColor": "accent"
}
```

| Option               | Type                    | Default     | Description                                                                                                              |
| -------------------- | ----------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------ |
| `boxedView`          | `boolean`               | `true`      | `true` = full box with side borders. `false` = top/bottom horizontal rules only.                                         |
| `boxPadX`            | `number`                | `1`         | Horizontal padding inside the box (and around the prefix).                                                               |
| `menuGap`            | `number`                | `0`         | Blank lines between the bottom border and the slash-menu.                                                                |
| `extraMenuIndent`    | `number`                | `1`         | Extra indent (spaces) for slash-menu lines.                                                                              |
| `borderColor`        | `string`                | `"border"`  | Theme colour token **or** hex colour (`"#ff6600"`) for the box border.                                                   |
| `prefix`             | `string`                | `"❯"`       | Prefix glyph shown on the first body line.                                                                               |
| `prefixColor`        | `string`                | `"accent"`  | Theme colour token **or** hex colour for the prefix.                                                                     |
| `corners`            | `"rounded" \| "square"` | `"rounded"` | `rounded` = `╭╮│╰╯`, `square` = `┌┐│└┘`. Any other value falls back to `rounded`.                                        |
| `focusIndicator`     | `boolean`               | `true`      | Track terminal focus (DECSET 1004) and restyle the border when this pane is focused. Requires `focus-events on` in tmux. |
| `focusedBorderColor` | `string`                | `"accent"`  | Border colour while the pane is focused; `borderColor` is used when unfocused.                                           |

### Colour tokens

Any valid theme colour token works. See your active theme in
`~/.pi/agent/themes/` or via `/settings → Theme` for available tokens
(`border`, `accent`, `text`, `muted`, `success`, `error`,
`customMessageLabel`, …). Hex values must be 6-digit `#rrggbb`; invalid values
fall back to the uncoloured text. Hex takes precedence over theme tokens in
`applyColor`.

No environment variables are used.

## Dependencies

Peer dependencies (`*`):

- `@earendil-works/pi-coding-agent` — `ExtensionAPI`, `ExtensionContext`,
  `CustomEditor`, `KeybindingsManager`, `Theme`, `ThemeColor` types; the
  `session_start` / `session_shutdown` events; `ctx.ui.setEditorComponent`.
- `@earendil-works/pi-tui` — `TUI` and `EditorTheme` types, `visibleWidth`
  for width arithmetic over ANSI-styled strings, and `tui.addInputListener` /
  `tui.requestRender` for focus tracking.

No npm runtime dependencies; `node:fs` / `node:os` / `node:path` only.

## Caveats

- **pi-tui internals**: the paste-expand feature reaches into `Editor` privates
  at runtime (`state`, `pastes`, `pasteCounter`, `pushUndoSnapshot`,
  `cancelAutocomplete`, `exitHistoryBrowsing`, `setCursorCol`) and overrides
  the TS-private `handlePaste` (compile-time private, runtime-accessible). It
  also hard-codes pi's paste-marker format (`[paste #N +X lines]` /
  `[paste #N X chars]`) and replicates pi-tui's paste cleanup and registry
  renumbering. Any change to pi-tui's paste handling or marker format can
  break this.
- **Stock-render parsing**: the boxed renderer calls `super.render()` and then
  re-wraps its output, detecting pi's solid `─` borders and `↑/↓ N more` scroll
  indicators by string matching. If pi-tui changes how the stock editor renders
  borders or scroll indicators, the box layout will misdetect sections.
- **Narrow terminals**: if `width < 5 + BOX_PAD_X * padMultiplier`
  (`padMultiplier` is 3 boxed, 1 unboxed) or the stock render produces fewer
  than 2 lines, the component falls back to pi's stock rendering.
- **Focus tracking (DECSET 1004)**: pi itself never enables focus reporting, so
  the extension enables it (`\x1b[?1004h`) and installs a `process.on("exit")`
  hook to disable it — otherwise the shell inherits a mode that spews `[I`/`[O`
  into the prompt. Shutdown hooks also disable it. If the process is killed
  with a signal that bypasses the exit hook, the terminal can be left in
  focus-reporting mode.
- **tmux**: the focus indicator only changes state if tmux has
  `focus-events on` (and the outer terminal passes focus events through).
  Outside tmux it works only if the terminal itself emits CSI I / CSI O.
- **Config is load-time**: `chat-input.json` is read once at module load; edits
  require a pi restart. There is no validation or error reporting — bad JSON or
  wrong types fall back to defaults (or may throw at render time for wildly
  wrong types).
- **setEditorComponent conflicts**: any other extension calling
  `setEditorComponent` after this one will replace the editor (last call wins).
