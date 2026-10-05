#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
TRANSFER_DIR=$(mktemp -d "$PWD/.build/transfer.XXXXXX")
ditto -x -k dist/StretchBreak-1.0.0-arm64.zip "$TRANSFER_DIR"
APP_PATH="$TRANSFER_DIR/StretchBreak/StretchBreak.app"
codesign --verify --strict "$APP_PATH"
plutil -lint "$APP_PATH/Contents/Info.plist"
[[ $(lipo -archs "$APP_PATH/Contents/MacOS/StretchBreak") == arm64 ]]
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist") == local.stretchbreak.app ]]
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
if zipinfo -1 dist/StretchBreak-1.0.0-arm64.zip | awk '/\.sqlite$/ { found=1 } END { exit !found }'; then
    print -u2 'The distribution contains a database.'
    exit 1
fi
ditto -x -k dist/StretchBreak-1.0.0-source.zip "$TRANSFER_DIR"
for ITEM in Package.swift README.md .gitignore Sources Tests Scripts Resources Docs Previews; do
    diff -qr "$PWD/$ITEM" "$TRANSFER_DIR/StretchBreak-source/$ITEM"
done
(cd dist && shasum -a 256 -c SHA256SUMS.txt)
print "Verified the portable application and matching source archive."
print "Extracted application: $APP_PATH"
