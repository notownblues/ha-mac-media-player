#!/usr/bin/env bash
#
# Update the Homebrew cask in the tap repo with a new version + sha256.
#
# Usage: ./scripts/update-cask.sh <version> <sha256>
#
# Requires the TAP_REPO_TOKEN env var: a GitHub token with write access to
# notownblues/homebrew-ha-mac-media-player. In CI, store it as a repo secret
# named TAP_REPO_TOKEN (a fine-grained PAT scoped to the tap repo).

set -euo pipefail

VERSION="${1:?usage: update-cask.sh <version> <sha256>}"
SHA256="${2:?usage: update-cask.sh <version> <sha256>}"

: "${TAP_REPO_TOKEN:?TAP_REPO_TOKEN must be set}"

TAP_REPO="notownblues/homebrew-ha-mac-media-player"
CASK_PATH="Casks/macmediaplayer.rb"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

git clone --depth 1 \
  "https://x-access-token:${TAP_REPO_TOKEN}@github.com/${TAP_REPO}.git" \
  "$WORKDIR/tap"

CASK="$WORKDIR/tap/$CASK_PATH"

# Replace the version "..." and sha256 "..." lines in place.
/usr/bin/sed -i '' \
  -e "s/^\( *version \)\".*\"/\1\"${VERSION}\"/" \
  -e "s/^\( *sha256 \)\".*\"/\1\"${SHA256}\"/" \
  "$CASK"

cd "$WORKDIR/tap"

if git diff --quiet; then
  echo "Cask already up to date for $VERSION"
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add "$CASK_PATH"
git commit -m "macmediaplayer ${VERSION}"
git push
echo "✓ Bumped cask to $VERSION"
