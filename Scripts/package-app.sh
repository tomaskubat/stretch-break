#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
APP_PATH="$PWD/dist/Release/StretchBreak.app"
codesign --verify --strict "$APP_PATH"
[[ $(lipo -archs "$APP_PATH/Contents/MacOS/StretchBreak") == arm64 ]]
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist") == local.stretchbreak.app ]]
STAGING_DIR=$(mktemp -d "$PWD/.build/package.XXXXXX")
mkdir -p "$STAGING_DIR/StretchBreak" "$STAGING_DIR/StretchBreak-source"
ditto "$APP_PATH" "$STAGING_DIR/StretchBreak/StretchBreak.app"
cp Docs/Install.md "$STAGING_DIR/StretchBreak/Install.md"
ditto -c -k --sequesterRsrc --keepParent "$STAGING_DIR/StretchBreak" "$PWD/dist/StretchBreak-1.0.0-arm64.zip"
for ITEM in Package.swift README.md .gitignore Sources Tests Scripts Resources Docs Previews; do
    ditto --norsrc --noextattr "$PWD/$ITEM" "$STAGING_DIR/StretchBreak-source/$ITEM"
done
ditto -c -k --norsrc --noextattr --keepParent "$STAGING_DIR/StretchBreak-source" "$PWD/dist/StretchBreak-1.0.0-source.zip"
(cd dist && shasum -a 256 StretchBreak-1.0.0-arm64.zip StretchBreak-1.0.0-source.zip > SHA256SUMS.txt)
print "Packaged dist/StretchBreak-1.0.0-arm64.zip and dist/StretchBreak-1.0.0-source.zip"
