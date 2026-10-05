#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
source Scripts/release-version.sh
resolve_release_version "$@"
APP_PATH="$PWD/dist/Release/StretchBreak.app"
codesign --verify --strict "$APP_PATH"
[[ $(lipo -archs "$APP_PATH/Contents/MacOS/StretchBreak") == arm64 ]]
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist") == local.stretchbreak.app ]]
if [[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist") != "$STRETCHBREAK_VERSION" ||
      $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist") != "$STRETCHBREAK_VERSION" ]]; then
    print -u2 "Build the application with version $STRETCHBREAK_VERSION before packaging it."
    exit 1
fi
STAGING_DIR=$(mktemp -d "$PWD/.build/package.XXXXXX")
mkdir -p "$STAGING_DIR/StretchBreak" "$STAGING_DIR/StretchBreak-source"
ditto "$APP_PATH" "$STAGING_DIR/StretchBreak/StretchBreak.app"
awk -v version="$STRETCHBREAK_VERSION" 'NR == 1 { print "# StretchBreak " version " pro Apple Silicon"; next } { print }' Docs/Install.md > "$STAGING_DIR/StretchBreak/Install.md"
ditto -c -k --sequesterRsrc --keepParent "$STAGING_DIR/StretchBreak" "$PWD/dist/$STRETCHBREAK_APP_ARCHIVE"
for ITEM in Package.swift README.md .gitignore .github Sources Tests Scripts Resources Docs Previews; do
    ditto --norsrc --noextattr "$PWD/$ITEM" "$STAGING_DIR/StretchBreak-source/$ITEM"
done
ditto -c -k --norsrc --noextattr --keepParent "$STAGING_DIR/StretchBreak-source" "$PWD/dist/$STRETCHBREAK_SOURCE_ARCHIVE"
(cd dist && shasum -a 256 "$STRETCHBREAK_APP_ARCHIVE" "$STRETCHBREAK_SOURCE_ARCHIVE" > SHA256SUMS.txt)
print "Packaged dist/$STRETCHBREAK_APP_ARCHIVE and dist/$STRETCHBREAK_SOURCE_ARCHIVE"
