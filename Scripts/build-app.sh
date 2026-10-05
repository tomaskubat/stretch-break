#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

swift build -c release --cache-path .build/cache
BIN_PATH=$(swift build -c release --show-bin-path --cache-path .build/cache)
APP_PATH="$PWD/dist/StretchBreak.app"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_PATH/StretchBreakPrototype" "$APP_PATH/Contents/MacOS/StretchBreakPrototype"
cp Resources/Info.plist "$APP_PATH/Contents/Info.plist"
swift -module-cache-path .build/icon-module-cache Scripts/MakeIcon.swift "$APP_PATH/Contents/Resources"
codesign --force --sign - "$APP_PATH"
print "Built $APP_PATH"
