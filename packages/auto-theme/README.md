# @nicknisi/pi-auto-theme

Syncs pi's UI theme with the macOS system appearance. Polls dark/light mode every 3 seconds via AppleScript and swaps the active theme to the paired dark/light counterpart. Exists so pi doesn't stay on a dark theme (or vice versa) when the OS switches modes on a schedule.

## What it adds

- No slash commands, tools, keybindings, or widgets.
- Hooks two events:
  - `session_start` — checks OS appearance once, corrects the theme if mismatched, then starts the poll interval.
  - `session_shutdown` — clears the poll interval.

## Theme pairs

Every theme in the map is bidirectional — if the active theme has an entry in `PAIRS`, it is swapped to its counterpart when the OS mode changes.

| Dark               | Light              |
| ------------------ | ------------------ |
| `nightowl`         | `lightowl`         |
| `tokyonight-night` | `tokyonight-day`   |
| `catppuccin-mocha` | `catppuccin-latte` |
| `dark`             | `light`            |

If the active theme is not in the map, the extension does nothing (appearance is still polled, but no switch occurs).

## Usage

Install and forget. There is nothing to invoke or configure.

On `session_start`:

1. `isDarkMode()` runs `osascript -e 'tell application "System Events" to tell appearance preferences to return dark mode'` with a 2000 ms timeout.
2. If the current theme's mode disagrees with the OS, `ctx.ui.setTheme(PAIRS[current])` corrects it.
3. A `setInterval(…, 3000)` re-polls; on a mode change it swaps the theme to its pair.

## Configuration

None. No config files, no options, no environment variables. The theme pairs and 3-second poll interval are hardcoded in `index.ts`.

## Dependencies

- `@earendil-works/pi-coding-agent` (peer, `*`) — `ExtensionAPI` type, `pi.on` events, `ctx.ui.theme.name`, `ctx.ui.setTheme`.
- `node:child_process.execSync` — shells out to `osascript`.
- No npm runtime dependencies, no workspace deps.

## Caveats

- **macOS only.** The appearance check is an AppleScript call to `System Events`. On any other platform `execSync` throws, the `catch` returns `true` (dark), and the extension forces dark themes forever. Behavior on Linux/Windows is "always dark".
- **Failure defaults to dark.** If `osascript` errors or times out (>2 s), `isDarkMode()` returns `true`, so transient failures read as dark mode.
- **Fixed poll interval.** 3 seconds; there is up to a 3-second lag between an OS appearance change and the theme swap. No event-driven notification is used.
- **pi internals.** Depends on `ctx.ui.theme.name` and `ctx.ui.setTheme()` from pi's extension API — both could change across pi versions. Theme names must match pi's theme registry exactly (`nightowl`, `tokyonight-night`, `catppuccin-mocha`, etc.); a renamed or removed theme silently no-ops.
- **Unknown themes are untouched.** If you run a custom theme not in `PAIRS`, this extension never switches it.
- **Synchronous subprocess on the main thread.** `execSync` blocks the extension's poll tick while AppleScript runs; with the 2 s timeout this is bounded but not async.

## Install

```bash
pi install /Users/nicknisi/Developer/pi-extensions/packages/auto-theme
```
