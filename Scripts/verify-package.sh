#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
source Scripts/release-version.sh
resolve_release_version "$@"
TRANSFER_DIR=$(mktemp -d "$PWD/.build/transfer.XXXXXX")
ditto -x -k "dist/$STRETCHBREAK_APP_ARCHIVE" "$TRANSFER_DIR"
APP_PATH="$TRANSFER_DIR/StretchBreak/StretchBreak.app"
codesign --verify --strict "$APP_PATH"
plutil -lint "$APP_PATH/Contents/Info.plist"
[[ $(lipo -archs "$APP_PATH/Contents/MacOS/StretchBreak") == arm64 ]]
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist") == local.stretchbreak.app ]]
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist") == "$STRETCHBREAK_VERSION" ]]
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist") == "$STRETCHBREAK_VERSION" ]]
[[ $(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP_PATH/Contents/Info.plist") == 14.0 ]]
[[ $(head -n 1 "$TRANSFER_DIR/StretchBreak/Install.md") == "# StretchBreak $STRETCHBREAK_VERSION pro Apple Silicon" ]]
if /usr/libexec/PlistBuddy -c 'Print :StretchBreakUITestDataDirectory' "$APP_PATH/Contents/Info.plist" >/dev/null 2>&1; then
    print -u2 'The distribution contains a UI test configuration.'
    exit 1
fi
cmp dist/Release/StretchBreak.app/Contents/MacOS/StretchBreak "$APP_PATH/Contents/MacOS/StretchBreak"
otool -L "$APP_PATH/Contents/MacOS/StretchBreak" | awk 'NR > 1 && $1 !~ /^\/System\/Library\// && $1 !~ /^\/usr\/lib\// { print "Unexpected dependency: " $1; failed=1 } END { exit failed }'
if otool -l "$APP_PATH/Contents/MacOS/StretchBreak" | awk '/path \/(Applications|Users)\// { found=1 } END { exit !found }'; then
    print -u2 'The executable contains a development search path.'
    exit 1
fi
if zipinfo -1 "dist/$STRETCHBREAK_APP_ARCHIVE" | awk '/\.sqlite$/ { found=1 } END { exit !found }'; then
    print -u2 'The distribution contains a database.'
    exit 1
fi
ditto -x -k "dist/$STRETCHBREAK_SOURCE_ARCHIVE" "$TRANSFER_DIR"
for ITEM in Package.swift README.md .gitignore .github Sources Tests Scripts Resources Docs Previews; do
    diff -qr "$PWD/$ITEM" "$TRANSFER_DIR/StretchBreak-source/$ITEM"
done
[[ $(awk '{ print $2 }' dist/SHA256SUMS.txt) == "$STRETCHBREAK_APP_ARCHIVE"$'\n'"$STRETCHBREAK_SOURCE_ARCHIVE" ]]
(cd dist && shasum -a 256 -c SHA256SUMS.txt)
print "Verified the portable application and matching source archive."
print "Extracted application: $APP_PATH"
