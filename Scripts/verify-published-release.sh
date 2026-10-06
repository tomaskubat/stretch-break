#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
source Scripts/release-version.sh
resolve_release_version "$@"

PUBLISHED_DIR=$(mktemp -d "$PWD/.build/published.XXXXXX")
trap 'rm -rf "$PUBLISHED_DIR"' EXIT
RELEASE_URL="https://github.com/tomaskubat/stretch-break/releases/download/v${STRETCHBREAK_VERSION}"
ASSETS=("$STRETCHBREAK_APP_ARCHIVE" "$STRETCHBREAK_SOURCE_ARCHIVE" "$STRETCHBREAK_UPDATE_ARCHIVE")
for ASSET in "${ASSETS[@]}" SHA256SUMS.txt; do
    curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
        --connect-timeout 15 --max-time 120 \
        --output "$PUBLISHED_DIR/$ASSET" "$RELEASE_URL/$ASSET"
done
# Fetch the stable URL used by installed applications, including its redirect.
curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
    --connect-timeout 15 --max-time 120 \
    --output "$PUBLISHED_DIR/appcast.xml" \
    https://github.com/tomaskubat/stretch-break/releases/latest/download/appcast.xml

swift -module-cache-path .build/update-module-cache Scripts/verify-release.swift published "$STRETCHBREAK_VERSION" "$PWD" "$PUBLISHED_DIR"
print "Verified published archives, the latest feed, and the signed update for $STRETCHBREAK_VERSION."
