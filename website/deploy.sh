#!/bin/bash
# Deploy the ShamarrConnect website to Cloudflare Pages.
# - site/ (committed) + private/ (server-only, gitignored) are merged into a
#   temp directory and uploaded via wrangler. private/ content is never committed.
# - Token: ~/sc-website/.cf-pages-token (chmod 600), scope: Pages:Edit
set -e

WEBSITE_DIR="$(cd "$(dirname "$0")" && pwd)"
TOKEN_FILE="$HOME/sc-website/.cf-pages-token"

if [ ! -s "$TOKEN_FILE" ]; then
  echo "ERROR: put a Pages-scoped API token in $TOKEN_FILE (chmod 600) first." >&2
  exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

cp -r "$WEBSITE_DIR/site/." "$TMPDIR/"
if [ -d "$WEBSITE_DIR/private" ]; then
  cp -r "$WEBSITE_DIR/private/." "$TMPDIR/"
fi

export CLOUDFLARE_API_TOKEN="$(cat "$TOKEN_FILE")"
export CLOUDFLARE_ACCOUNT_ID="00000000000000000000000000000000"

cd "$WEBSITE_DIR"
npx -y wrangler@4 pages deploy "$TMPDIR" --project-name shamarrconnect --branch main 2>&1
