#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
source Scripts/release-version.sh
resolve_release_version "$@"

swift build -c release --arch arm64 --cache-path .build/cache
BIN_PATH=$(swift build -c release --arch arm64 --show-bin-path --cache-path .build/cache)
APP_PATH="$PWD/dist/Release/StretchBreak.app"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_PATH/StretchBreak" "$APP_PATH/Contents/MacOS/StretchBreak"
# SwiftPM may add an unused search path into the local Xcode toolchain.
# Distribution binaries use only the runtime supplied by macOS.
while IFS= read -r DEVELOPMENT_RPATH; do
    install_name_tool -delete_rpath "$DEVELOPMENT_RPATH" "$APP_PATH/Contents/MacOS/StretchBreak"
done < <(otool -l "$APP_PATH/Contents/MacOS/StretchBreak" | awk '
    /cmd LC_RPATH/ { rpath=1; next }
    rpath && /^[[:space:]]*path / {
        sub(/^[[:space:]]*path /, ""); sub(/ \(offset.*$/, "")
        if ($0 ~ /^\// && $0 !~ /^\/usr\/lib\// && $0 !~ /^\/System\/Library\//) print
        rpath=0
    }')
cp Resources/Info.plist "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $STRETCHBREAK_VERSION" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $STRETCHBREAK_VERSION" "$APP_PATH/Contents/Info.plist"
swift -module-cache-path .build/icon-module-cache Scripts/MakeIcon.swift "$APP_PATH/Contents/Resources"
codesign --force --sign - "$APP_PATH"
codesign --verify --strict "$APP_PATH"
print "Built $APP_PATH"
