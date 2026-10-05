#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
source Scripts/release-version.sh
resolve_release_version "$@"

swift build -c release --arch arm64 --cache-path .build/cache -Xlinker -rpath -Xlinker @executable_path/../Frameworks
BIN_PATH=$(swift build -c release --arch arm64 --show-bin-path --cache-path .build/cache)
APP_PATH="$PWD/dist/Release/StretchBreak.app"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$APP_PATH/Contents/Frameworks"
SPARKLE_FRAMEWORK="$APP_PATH/Contents/Frameworks/Sparkle.framework"
ditto .build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework "$SPARKLE_FRAMEWORK"
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
cp .build/artifacts/sparkle/Sparkle/LICENSE "$APP_PATH/Contents/Resources/Sparkle-LICENSE.txt"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $STRETCHBREAK_VERSION" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $STRETCHBREAK_VERSION" "$APP_PATH/Contents/Info.plist"
swift -module-cache-path .build/icon-module-cache Scripts/MakeIcon.swift "$APP_PATH/Contents/Resources"
for HELPER in "$SPARKLE_FRAMEWORK"/Versions/B/XPCServices/*.xpc \
              "$SPARKLE_FRAMEWORK/Versions/B/Updater.app" "$SPARKLE_FRAMEWORK/Versions/B/Autoupdate"; do
    codesign --force --sign - --options=0 "$HELPER"
done
codesign --force --sign - --options=0 "$SPARKLE_FRAMEWORK"
codesign --force --sign - "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
print "Built $APP_PATH"
