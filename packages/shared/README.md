# @nicknisi/pi-shared

Shared helper library for the extensions in this monorepo. It is not a pi extension itself — it exports no default extension entry, adds no commands, tools, keybindings, widgets, or events, and installing it into pi directly does nothing. Other packages depend on it via `"@nicknisi/pi-shared": "workspace:*"` and import from it like any library.

It exists to centralize two things that several extensions were duplicating: one-off LLM calls on pi-ai's modern provider API (no `/compat` imports), and a set of TUI utilities (gradient text, renderable-tree surgery, two-column layout, escape-sequence sanitization, render dispatch) plus a composable searchable select component.

## Exports

`index.ts` re-exports everything from `llm.ts`, `tui-utils.ts`, and `searchable-select-list.ts`.

### LLM (`llm.ts`)

```ts
import { getModelProvider } from "@nicknisi/pi-shared";
```

`getModelProvider(ctx, model)` resolves the composed runtime provider for a model via `ctx.modelRegistry.getProvider(model.provider)`. Unlike compat's global API dispatch, this honors `models.json` overrides and extension-registered providers. Throws `No provider registered for <provider>` if unregistered.

`ctx` only needs a `modelRegistry` (`Pick<ExtensionContext, "modelRegistry">`), so non-extension callers can pass a narrower object.

Migration cheat sheet from the compat API (documented in the source header):

```ts
// compat complete(model, ctx, opts)
getModelProvider(ctx, model).stream(model, ctx, opts).result();

// compat streamSimple(model, ctx, opts)
getModelProvider(ctx, model).streamSimple(model, ctx, opts);
```

Auth stays explicit: pass `apiKey`/`headers` from `ctx.modelRegistry.getApiKeyAndHeaders(model)` in the stream options.

### TUI utilities (`tui-utils.ts`)

```ts
import {
  columns,
  formatDirectory,
  gradientText,
  hideLabeledSection,
  sanitizeTerminalLabel,
  // ...
} from "@nicknisi/pi-shared";
```

Six self-contained patterns, adapted from a pi dashboard extension:

| Export                                             | What it does                                                                                                                                                                                                                                                                 |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `gradientText(text, phase, palette?)`              | Per-character truecolor gradient. `phase` shifts the gradient (use `rowIndex * k` to stagger multi-line art). Spaces pass through uncolored.                                                                                                                                 |
| `sampleGradient(position, palette?)`               | Sample a wrapping gradient at `position` (0..1, wraps modulo 1); adjacent palette stops are linearly interpolated.                                                                                                                                                           |
| `DEFAULT_PALETTE`, `RESET`                         | Default blue-leaning 6-stop RGB palette; ANSI reset code.                                                                                                                                                                                                                    |
| `hideLabeledSection(root, label)`                  | Walk a renderable tree, find the first child whose first non-empty rendered line equals `label`, splice it out (plus one trailing blank-line sibling), and `invalidate()` the root. Returns `true` if removed. Original use: stripping pi's auto-injected `[Themes]` widget. |
| `scheduleHideLabeledSection(root, label, delays?)` | Progressive-poll removal at `[0, 50, 250, 1000]` ms for asynchronously injected nodes; calls `root.requestRender(true)` on success. Returns timers.                                                                                                                          |
| `clearHideTimers(timers)`                          | Teardown for the above.                                                                                                                                                                                                                                                      |
| `columns(left, right, width)`                      | Two-column line layout. Pads the gap when both sides fit; otherwise shrinks left to ~45% and right to the remainder with a minimum 1-space gap, truncating via pi-tui's `truncateToWidth`.                                                                                   |
| `sanitizeTerminalLabel(text)`                      | Strip OSC, CSI, other escape sequences, and C0/C1 control chars from user-controllable strings before rendering (prevents escape injection and layout breakage).                                                                                                             |
| `formatDirectory(cwd)`                             | Collapse `$HOME` to `~` for display, then sanitize.                                                                                                                                                                                                                          |
| `renderedText(node, width = 200)`                  | Render a node to a throwaway 200-wide buffer and strip ANSI — introspect a component whose API only exposes `render(width)`. Returns `""` if `render` throws.                                                                                                                |
| `createRenderDispatcher()`                         | Reassignable render thunk so event sources can trigger redraws without knowing which surface is bound. `bind(tui)` points `requestRender()` at `tui.requestRender()`; `unbind()` clears it.                                                                                  |

Shared structural types: `RenderableNode` (`children?`, `invalidate()`, `render(width)`), `RequestRenderable` (adds `requestRender(force?)`), `RenderDispatcher`. These are subsets of pi's own `RenderableNode` and are structurally compatible with `@earendil-works/pi-coding-agent` components.

### Searchable select (`searchable-select-list.ts`)

```ts
import { SearchableSelectList } from "@nicknisi/pi-shared";
```

A pi-tui `Component` composing an `Input` above a `SelectList`. pi-tui removed `SelectList.searchable`; this is the manual filtering pattern pi's own model/theme selectors use. `handleInput` routes the `tui.select.up` / `tui.select.down` / `tui.select.confirm` / `tui.select.cancel` keybindings to the list and everything else to the input, whose value drives `selectList.setFilter()`.

```ts
const list = new SearchableSelectList(items, maxVisible, theme);
list.onSelect = (item) => {
  /* ... */
};
list.onCancel = () => {
  /* ... */
};
// mount into an overlay/dialog; render(width) and handleInput(keyData) are the Component contract
```

`selectList` is exposed as a readonly field for direct list manipulation.

## Usage

Consumers in this monorepo add the workspace dependency:

```json
{
  "dependencies": {
    "@nicknisi/pi-shared": "workspace:*"
  }
}
```

and import individual functions as shown above. Known consumers: `answer`, `btw`, `handoff`, `header`, `session-name`, `statusline`.

## Configuration

None. No config files, no options, no environment variables.

## Install

Not intended for direct installation — it registers nothing with pi. It is pulled in automatically as a workspace dependency of the extensions that use it. If you did run it:

```bash
pi install /Users/nicknisi/Developer/pi-extensions/packages/shared
```

pi would load the package and find no extension entry point.

## Dependencies

Peer dependencies (all `*`, provided by the pi runtime):

- `@earendil-works/pi-ai` — types (`Api`, `Model`, `Provider`) for `getModelProvider`.
- `@earendil-works/pi-coding-agent` — `ExtensionContext` type; the `RenderableNode` shape targets its component tree.
- `@earendil-works/pi-tui` — `truncateToWidth`, `visibleWidth` (layout), and `Container`, `Input`, `SelectList`, `getKeybindings` (searchable select).

No runtime npm dependencies; Node builtins only (`node:os`, `node:path`).

## Caveats

- `getModelProvider` depends on pi-ai's provider-owns-streaming architecture and `ModelRegistry.getProvider()` returning the composed runtime provider. Both are current pi internals and could change across pi versions; the compat API this replaces is the canary — if pi-ai restructures provider resolution again, this needs to move with it.
- `hideLabeledSection` relies on rendering children to a throwaway buffer to compare visible text — it depends on `render(width)` being side-effect-free enough to call speculatively, and on target sections having a stable first visible line (pi's `[Themes]` widget label is a pi internal that could change).
- `scheduleHideLabeledSection` is a timing heuristic (`[0, 50, 250, 1000]` ms) for asynchronously injected nodes; a sufficiently slow injection can slip past the last poll.
- `SearchableSelectList` hardcodes the `tui.select.*` keybinding IDs from pi-tui. If those IDs are renamed, navigation silently stops routing.
- `package.json` `files` lists `index.ts`, `llm.ts`, `tui-utils.ts` but not `searchable-select-list.ts`. Harmless for workspace use (nothing is packed), but `pnpm pack`/publish would produce a broken tarball.
- The package is marked `private: true` and ships TypeScript sources (`exports: { ".": "./index.ts" }`); consumers must run in pi's TS-loading extension environment, not plain Node.
