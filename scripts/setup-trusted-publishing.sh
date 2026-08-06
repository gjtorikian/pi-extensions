#!/usr/bin/env bash
# One-time setup: publish all packages to npm (creating them), then attach
# a GitHub Actions trusted publisher to each via `npm trust`.
#
# Prereqs:
#   npm >= 11.15.0
#   npm login --registry=https://registry.npmjs.org   (interactive, account 2FA on)
#
# The first `npm trust` call prompts for 2FA — choose the "skip for 5 minutes"
# option on the npm website and the remaining packages go through unattended.
set -euo pipefail

REGISTRY="https://registry.npmjs.org"
REPO="nicknisi/pi-extensions"
WORKFLOW="release.yml"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

npm whoami --registry="$REGISTRY" >/dev/null 2>&1 || {
  echo "not logged in: run  npm login --registry=$REGISTRY" >&2
  exit 1
}

# Phase 1: publish packages that don't exist on npm yet.
# `pnpm publish` (not npm) so workspace:* ranges rewrite to real versions.
publish_pkg() {
  local dir="$1" name
  name="$(node -p "require('$ROOT/packages/$dir/package.json').name")"
  if npm view "$name" version --registry="$REGISTRY" >/dev/null 2>&1; then
    echo "== $name already on npm, skipping publish"
  else
    echo "== publishing $name"
    (cd "$ROOT/packages/$dir" && pnpm publish --access public --no-git-checks --registry="$REGISTRY")
    sleep 2
  fi
}

# shared first — six packages depend on it
publish_pkg shared
for dir in "$ROOT"/packages/*/; do
  dir="$(basename "$dir")"
  [ "$dir" = "shared" ] && continue
  publish_pkg "$dir"
done

# Phase 2: attach the trusted publisher to each package.
for dir in "$ROOT"/packages/*/; do
  dir="$(basename "$dir")"
  name="$(node -p "require('$ROOT/packages/$dir/package.json').name")"
  if npm trust list "$name" --registry="$REGISTRY" 2>/dev/null | grep -q "$WORKFLOW"; then
    echo "== $name already trusts $REPO/$WORKFLOW, skipping"
    continue
  fi
  echo "== trusting $name -> $REPO ($WORKFLOW)"
  npm trust github "$name" --file "$WORKFLOW" --repo "$REPO" --allow-publish --yes --registry="$REGISTRY"
  sleep 2
done

echo "done — all packages published and trusting $REPO via $WORKFLOW"
