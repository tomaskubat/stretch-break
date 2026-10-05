import AppKit
import CSQLite
import StretchBreakCore
import Testing
import UserNotifications
@testable import StretchBreak
@testable import StretchBreakMac

@Suite(.serialized) @MainActor
struct StatusItemTests {
    @Test func unchangedAppearanceNotificationsDoNotFeedBackIntoImageUpdates() async throws {
        let session = try RuntimeSession()
        defer { session.close() }
        try await Task.sleep(for: .milliseconds(100))
        let button = session.button
        let changes = ImageChanges()
        let observer = button.observe(\.image) { button, _ in
            MainActor.assumeIsolated {
                changes.count += 1
                // Replay AppKit's appearance notification after an image assignment.
                // Cap the replay so the original bug cannot keep the test running forever.
                if changes.count < 100 {
                    notifyAppearance(button)
                }
            }
        }
        defer { observer.invalidate() }

        for _ in 0..<10 {
            notifyAppearance(button)
        }
        try await Task.sleep(for: .milliseconds(100))

        // A timer tick is allowed. Repeated appearance callbacks must settle.
        #expect(changes.count <= 2)
    }

    @Test func changedButtonAppearanceRefreshesTheIcon() async throws {
        let session = try RuntimeSession()
        defer { session.close() }
        try await Task.sleep(for: .milliseconds(100))
        let lightImage = try #require(session.button.image?.tiffRepresentation)

        session.button.appearance = NSAppearance(named: .darkAqua)
        try await Task.sleep(for: .milliseconds(100))
        let darkImage = try #require(session.button.image?.tiffRepresentation)
        #expect(darkImage != lightImage)

        session.button.appearance = NSAppearance(named: .aqua)
        try await Task.sleep(for: .milliseconds(100))
        #expect(session.button.image?.tiffRepresentation == lightImage)
    }

    @Test func timerAndStateChangesStillRefreshAnUnchangedAppearance() async throws {
        let session = try RuntimeSession()
        defer { session.close() }
        let engine = try #require(session.runtime.engine)
        let initialTooltip = session.button.toolTip
        try await Task.sleep(for: .milliseconds(1200))
        #expect(session.button.toolTip != initialTooltip)

        engine.togglePause()
        #expect(session.button.image?.isTemplate == true)
        #expect(session.button.toolTip?.contains("paused") == true)
        engine.togglePause()
        #expect(session.button.image?.isTemplate == false)
        #expect(session.button.toolTip?.contains("until next break") == true)

        engine.startBreak()
        #expect(session.button.toolTip == "StretchBreak: break ready")
        engine.skipBreak()
        #expect(session.button.toolTip?.contains("until next break") == true)

        var database: OpaquePointer?
        let databasePath = session.directory.appendingPathComponent("StretchBreak.sqlite").path
        #expect(sqlite3_open(databasePath, &database) == SQLITE_OK)
        defer { sqlite3_close(database) }
        #expect(sqlite3_exec(database, "CREATE TRIGGER fail_update BEFORE UPDATE ON app_state BEGIN SELECT RAISE(ABORT, 'test write failure'); END;", nil, nil, nil) == SQLITE_OK)
        engine.togglePause()
        #expect(engine.hasUnsavedChange)
        #expect(session.button.image?.isTemplate == true)
        #expect(session.button.toolTip == "StretchBreak: data needs attention")
    }
}

@MainActor
private func notifyAppearance(_ button: NSStatusBarButton) {
    button.willChangeValue(forKey: "effectiveAppearance")
    button.didChangeValue(forKey: "effectiveAppearance")
}

@MainActor
private final class ImageChanges {
    var count = 0
}

@MainActor
private final class RuntimeSession {
    let directory: URL
    let statusItem: NSStatusItem
    let button: NSStatusBarButton
    let runtime: AppRuntime
    private let previousWindows: [NSWindow]

    init() throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        previousWindows = NSApplication.shared.windows
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        button = try #require(statusItem.button)
        button.appearance = NSAppearance(named: .aqua)
        runtime = AppRuntime(statusItem: statusItem, testDataDirectory: directory.path,
                             reminders: MacReminders(client: NotificationStub(), testing: true))
        runtime.start()
        _ = try #require(runtime.engine)
    }

    func close() {
        runtime.stop()
        for window in NSApplication.shared.windows where !previousWindows.contains(window) {
            window.close()
        }
        NSStatusBar.system.removeStatusItem(statusItem)
        try? FileManager.default.removeItem(at: directory)
    }
}

@MainActor
private final class NotificationStub: NotificationClient {
    func authorizationStatus() async -> UNAuthorizationStatus { .denied }
    func requestAuthorization() async throws {}
    func addReminder(id: UUID, exerciseCount: Int) async throws {}
    func removeReminder(id: UUID) {}
}
