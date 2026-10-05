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

EXPECTED_ASSETS="$STRETCHBREAK_APP_ARCHIVE"$'\n'"$STRETCHBREAK_SOURCE_ARCHIVE"$'\n'"$STRETCHBREAK_UPDATE_ARCHIVE"$'\n'appcast.xml
[[ $(awk '{ print $2 }' "$PUBLISHED_DIR/SHA256SUMS.txt") == "$EXPECTED_ASSETS" ]]
cmp dist/SHA256SUMS.txt "$PUBLISHED_DIR/SHA256SUMS.txt"
(cd "$PUBLISHED_DIR" && shasum -a 256 -c SHA256SUMS.txt)
swift -module-cache-path .build/update-module-cache Scripts/verify-update.swift "$STRETCHBREAK_VERSION" "$PUBLISHED_DIR"

# The downloaded archive is authenticated before it is extracted.
ditto -x -k "$PUBLISHED_DIR/$STRETCHBREAK_UPDATE_ARCHIVE" "$PUBLISHED_DIR/update"
[[ $(ls -A "$PUBLISHED_DIR/update") == StretchBreak.app ]]
APP_PATH="$PUBLISHED_DIR/update/StretchBreak.app"
codesign --verify --deep --strict "$APP_PATH"
[[ $(lipo -archs "$APP_PATH/Contents/MacOS/StretchBreak") == arm64 ]]
cmp dist/Release/StretchBreak.app/Contents/Info.plist "$APP_PATH/Contents/Info.plist"
print "Verified published archives, the latest feed, and the signed update for $STRETCHBREAK_VERSION."
