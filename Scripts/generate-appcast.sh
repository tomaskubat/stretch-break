#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
source Scripts/release-version.sh
resolve_release_version "$@"
TOOLS="$PWD/.build/artifacts/sparkle/Sparkle/bin"
UPDATES_DIR=$(mktemp -d "$PWD/.build/appcast.XXXXXX")
trap 'rm -rf "$UPDATES_DIR"' EXIT
cp "dist/$STRETCHBREAK_UPDATE_ARCHIVE" "$UPDATES_DIR/"
APPCAST_ARGUMENTS=(--maximum-deltas 0 --download-url-prefix
    "https://github.com/tomaskubat/stretch-break/releases/download/v${STRETCHBREAK_VERSION}/"
    --link "https://github.com/tomaskubat/stretch-break/releases/tag/v${STRETCHBREAK_VERSION}"
    "$UPDATES_DIR")
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    print -r -- "$SPARKLE_PRIVATE_KEY" | "$TOOLS/generate_appcast" --ed-key-file - "${APPCAST_ARGUMENTS[@]}"
else
    "$TOOLS/generate_appcast" --account local.stretchbreak.app "${APPCAST_ARGUMENTS[@]}"
fi
cp "$UPDATES_DIR/appcast.xml" dist/appcast.xml
swift -module-cache-path .build/update-module-cache Scripts/verify-update.swift "$STRETCHBREAK_VERSION"
(cd dist && shasum -a 256 "$STRETCHBREAK_APP_ARCHIVE" "$STRETCHBREAK_SOURCE_ARCHIVE" "$STRETCHBREAK_UPDATE_ARCHIVE" appcast.xml > SHA256SUMS.txt)
print "Generated and verified dist/appcast.xml."
