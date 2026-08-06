# @nicknisi/pi-spinner

Replaces pi's default working/loading message with a randomly selected phrase on every turn. The list contains ~1000 entries drawn from The Office, Lord of the Rings, Arnold Schwarzenegger / Predator, LinkedIn-influencer satire, gym culture, security-ops jargon, and assorted programming memes. It exists purely to make the wait between turns more entertaining; it changes no agent behavior.

## Install

```bash
pi install /Users/nicknisi/Developer/pi-extensions/packages/spinner-verbs
```

## What it adds

No slash commands, tools, keybindings, widgets, or custom entry types. It only hooks two events:

- `turn_start` — calls `ctx.ui.setWorkingMessage("<random verb>...")`, replacing the spinner's working text for the duration of the turn.
- `turn_end` — calls `ctx.ui.setWorkingMessage()` with no argument, resetting the working message to pi's default.

## Usage

Nothing to invoke. Once installed, every agent turn shows a random message in the spinner, e.g.:

```
Getting to the Chopper...
```

A new phrase is sampled independently each turn, so repeats are possible.

## Configuration

None. No config files, no options, no environment variables. The verb list is a hardcoded `VERBS` array in `index.ts`; edit the source to add or remove phrases.

## Dependencies

- `@earendil-works/pi-coding-agent` (peer, `*`) — uses `ExtensionAPI`, specifically `pi.on` for the `turn_start` / `turn_end` events and `ctx.ui.setWorkingMessage()`.

No npm dependencies, no workspace dependencies, no build step. The package ships raw TypeScript (`"exports": "./index.ts"`, `"pi.extensions": ["./index.ts"]`).

## Caveats

- Depends on the `turn_start` / `turn_end` event names and the `ctx.ui.setWorkingMessage()` API, which are pi extension-API surface; a pi release that renames or removes either will break this extension.
- The selection uses `Math.random()` with no deduplication, so the same phrase can appear on consecutive turns.
- Because it hooks `turn_start` without checking event payload, it overrides the working message even in contexts where another extension may have set one; the last `setWorkingMessage` call wins.
