#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
./Scripts/build-app.sh "$@"
TEST_APP="$PWD/dist/UITests/StretchBreak UI Tests.app"
ditto "$PWD/dist/Release/StretchBreak.app" "$TEST_APP"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier local.stretchbreak.uitests' "$TEST_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName StretchBreak UI Tests' "$TEST_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :StretchBreakUITestDataDirectory string $PWD/.build/ui-test-data" "$TEST_APP/Contents/Info.plist"
codesign --force --sign - "$TEST_APP"
print "Built isolated UI tests at $TEST_APP"
