# StretchBreak

A native macOS app with an English interface. It runs in the menu bar, reminds you to take movement breaks, records actual repetition counts, and stores your history locally. Supports Apple Silicon and macOS 14 or later.

## Running the app and transferring it to another Mac

1. Transfer `dist/StretchBreak-1.0.0-arm64.zip` to the other Mac and extract it.
2. Move `StretchBreak.app` to Applications and open it. Xcode and additional libraries are not required.
3. Click the person icon in the menu bar to open the panel. When a break is ready, the icon changes to an exclamation mark.

The app has an ad hoc signature, but it is not signed with a Developer ID certificate or notarized. No signing identity is available in the build environment. If macOS blocks the first launch, after attempting to open this app you can use System Settings → Privacy & Security → Open Anyway. [Apple Support](https://support.apple.com/en-us/102445) explains the procedure. A managed Mac may restrict this option.

## Using the app

The default interval is 60 minutes. `Start break` starts a break immediately. For each exercise, enter a repetition count, use the plus/minus buttons, or press `Done` to record the planned count. Valid values are whole numbers from 1 to 999. `Undo` reverses a confirmation while the break remains open. Confirming the last exercise completes the break and starts a new interval.

Closing the panel preserves the unfinished break. `Skip & restart` records confirmed exercises, marks the others as skipped, and starts a new interval. Pausing preserves the remaining time, even after restarting the app.

In Settings, you can change the interval from 1 to 240 minutes, system notifications, and the exercise list. Press `Save changes` to save your edits. Changing the interval restarts the countdown and keeps it paused if it was already paused. If a break is open, the new interval and exercise set apply after it closes. History preserves the original names, planned counts, and recorded results.

| Shortcut | Action |
| --- | --- |
| ⌘1 | Open the panel when the app is active |
| Enter | Start a break or confirm a valid repetition count |
| ⌘P | Pause / Resume in the panel |
| ⌘⇧S | Skip & restart in the panel |
| ⌘, | Settings |
| ⌘S | Save Settings |
| ⌘⇧H | History |
| Escape | Close the panel |
| ⌘W | Close a separate window |
| ⌘Q | Quit the app |

The timer uses a saved deadline. Time spent with the Mac asleep or the app closed counts toward the interval. When you return, at most one current break is created. Reminders do not open the panel automatically. Notifications depend on macOS permissions; denying them does not block other features. The app does not add itself to login items.

## Data

All data is stored in `~/Library/Application Support/StretchBreak/StretchBreak.sqlite`. The database contains settings, the saved deadline or paused state, the unfinished break including entered values, and history. The app requires no account or internet connection and does not sync data.

Data is stored separately from the `.app` bundle and survives app updates. To transfer data, quit the app on both Macs, back up any existing data on the destination Mac, and copy the entire `StretchBreak` folder to the same location. You can also find the folder through About StretchBreak → Show data in Finder. Transferring only the `.app` starts with fresh local data on the other Mac.

State changes and any corresponding history entry are saved in a single SQLite transaction. The interface confirms success only after the write completes. If saving fails, the app preserves the previously saved state, blocks further changes, and offers `Retry saving`. It warns about unsaved changes when you quit. It does not overwrite an invalid database with new data.

## Building from source

The source project is in this directory and in `dist/StretchBreak-1.0.0-source.zip`. It requires Swift 6 and the macOS SDK. It depends only on system libraries.

```sh
swift test --cache-path .build/cache
./Scripts/build-app.sh
./Scripts/package-app.sh
./Scripts/verify-package.sh
```

The build produces `dist/Release/StretchBreak.app`. The packaging script creates a portable application ZIP, a source ZIP, and SHA-256 checksums. Only `arm64` is built.

## GitHub releases

Pushing a new tag, such as `v1.0.0`, runs the tests, builds the app, and verifies the packages. If all steps succeed, the workflow publishes a GitHub release with the Apple Silicon app, source archive, and checksums. The app version and filenames come from the tag. [Docs/Releasing.md](Docs/Releasing.md) describes setup, publishing, and local verification.

## App structure

`StretchBreakCore` contains break rules, the model, the time source, and SQLite storage. `StretchBreakMac` handles system notifications. `StretchBreak` contains the SwiftUI interface and AppKit integration for the menu bar, panel, windows, and waking from sleep. Tests can replace the time source, storage, and reminder delivery.

## Verification

All 31 automated tests passed. They cover controlled time, real SQLite transactions and write failures, restoration after restart, and notification integration with a replaceable system client. The main flows were verified in the running app, including the actual anchored panel and restoration after terminating the process.

See [Docs/Verification.md](Docs/Verification.md) for details and limitations. Verified on Apple Silicon with macOS 27.0.1, Xcode 27.0, and Swift 6.4. Another physical Mac and older supported macOS versions were not available. System notifications are denied on this Mac, so delivery of an actual banner and clicking it have not been verified.

To repeat the UI tests, run `./Scripts/build-ui-test-app.sh` and open `dist/UITests/StretchBreak UI Tests.app`. This copy uses its own database in `.build/ui-test-data`, controlled time, and does not send system notifications. The `Open menu bar panel` button opens the actual production popover. This development build is not included in the portable ZIP. See [UI scenarios](Docs/UITests.md) for the steps and expected results.

The original prototype is preserved on the `codex/ui-prototype` branch. The previews in `Previews` belong to the approved phase 0; they do not demonstrate the functionality of the current app.
