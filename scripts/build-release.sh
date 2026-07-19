#!/usr/bin/env bash
#
# Build a release .app bundle and package it as a zip for the Homebrew cask.
#
# Usage: ./scripts/build-release.sh [version]
#   version  Version string to stamp into the build (default: value in Makefile)
#
# Produces:
#   .build/release/MacMediaPlayer.app
#   .build/release/MacMediaPlayer-<version>.zip   (ditto archive, cask-ready)
#
# Prints the zip's sha256 on the last line so it can be captured by CI.

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-}"

if [ -n "$VERSION" ]; then
  make bundle VERSION="$VERSION"
else
  make bundle
  # Fall back to the version baked into the Makefile.
  VERSION="$(awk -F'= *' '/^VERSION/{print $2; exit}' Makefile | tr -d '[:space:]')"
fi

APP=".build/release/MacMediaPlayer.app"
ZIP=".build/release/MacMediaPlayer-${VERSION}.zip"

if [ ! -d "$APP" ]; then
  echo "error: expected app bundle not found at $APP" >&2
  exit 1
fi

rm -f "$ZIP"
# ditto preserves the bundle's symlinks/metadata — the format Homebrew expects.
ditto -c -k --keepParent "$APP" "$ZIP"

SHA256="$(shasum -a 256 "$ZIP" | awk '{print $1}')"

echo ""
echo "✓ Packaged $ZIP"
echo "  version: $VERSION"
echo "  sha256:  $SHA256"
