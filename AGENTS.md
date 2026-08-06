# pi-extensions — Agent Instructions

Monorepo of Nick Nisi's pi extensions. Each `packages/<name>/` is an independently published npm package (`@nicknisi/pi-<name>`) installable via `pi install`.

## Hard rules

- **Conventional commits are required** (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:` …). PR titles must be conventional — CI enforces it (`lint-pr-title`), and squash-merge titles become the main-branch history.
- **Add a changeset for any user-facing change** to a package: run `pnpm changeset`, pick the packages + bump, and commit the generated file with your change. No changeset = no release. (Docs/config/CI-only changes don't need one.)
- Never edit a package's behavior during a structural move or rename.

## Workflow

```bash
pnpm install
pnpm typecheck     # tsgo (TS 7 native preview)
pnpm lint          # oxlint
pnpm format        # oxfmt (format:check to verify)
```

- Extensions ship `.ts` source directly — no build step. `@earendil-works/*` are peer deps; pi's runtime aliases them at load time.
- Cross-package helpers go in `packages/shared` (`@nicknisi/pi-shared`, `workspace:*`).
- Runtime configs live in `~/.pi/agent/configs/`, not in this repo.

## Releases

Changesets + npm trusted publishing (OIDC). Merging the "chore: version packages" PR publishes to npm and tags. Details: `.github/workflows/release.yml`.
