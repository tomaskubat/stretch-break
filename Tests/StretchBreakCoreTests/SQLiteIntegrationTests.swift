import CSQLite
import Foundation
import StretchBreakCore
import Testing

@MainActor
struct SQLiteIntegrationTests {
    @Test func roundTripRestoresSettingsHistoryAndUnfinishedBreak() throws {
        let url = try temporaryDatabase()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let clock = TestClock()
        let engine = try BreakEngine(repository: SQLiteRepository(url: url), clock: clock)
        var settings = engine.settings
        settings.intervalMinutes = 17
        settings.notificationsEnabled = false
        settings.exercises[0].name = "Custom movement"
        engine.updateSettings(settings)
        engine.startBreak()
        engine.skipBreak()
        engine.startBreak()
        engine.setInput("8", for: engine.drafts[0].id)
        engine.confirm(engine.drafts[0].id)
        engine.setInput("5", for: engine.drafts[1].id)
        let restored = try BreakEngine(repository: SQLiteRepository(url: url), clock: clock)
        #expect(restored.settings == settings)
        #expect(restored.state == engine.state)
        #expect(restored.drafts[0].actual == 8 && restored.drafts[1].input == "5")
        #expect(restored.history == engine.history)
    }

    @Test func restartBeforeAndAfterDeadlineUsesPersistedWallClockDeadline() throws {
        let url = try temporaryDatabase()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let clock = TestClock()
        _ = try BreakEngine(repository: SQLiteRepository(url: url), clock: clock)
        clock.advance(600)
        let before = try BreakEngine(repository: SQLiteRepository(url: url), clock: clock)
        #expect(before.countdownText == "50:00")
        clock.advance(86400 * 5)
        let reminders = ReminderSpy()
        let after = try BreakEngine(repository: SQLiteRepository(url: url), clock: clock, reminders: reminders)
        #expect(after.activeBreak != nil && after.history.isEmpty)
        let again = try BreakEngine(repository: SQLiteRepository(url: url), clock: clock, reminders: reminders)
        #expect(after.activeBreak?.id == again.activeBreak?.id && reminders.delivered.count == 1)
    }

    @Test func pausedStateAndNewIntervalSurviveReopening() throws {
        let url = try temporaryDatabase()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let clock = TestClock()
        let engine = try BreakEngine(repository: SQLiteRepository(url: url), clock: clock)
        clock.advance(123)
        engine.togglePause()
        let remaining = engine.remainingSeconds
        clock.advance(86400)
        let restored = try BreakEngine(repository: SQLiteRepository(url: url), clock: clock)
        #expect(restored.isPaused && restored.remainingSeconds == remaining)
        var settings = restored.settings
        settings.intervalMinutes = 9
        restored.updateSettings(settings)
        let changed = try BreakEngine(repository: SQLiteRepository(url: url), clock: clock)
        #expect(changed.isPaused && changed.countdownText == "09:00")
    }

    @Test func failedHistoryInsertRollsBackStateInTheSameTransaction() throws {
        let url = try temporaryDatabase()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = try SQLiteRepository(url: url)
        let clock = TestClock()
        let engine = try BreakEngine(repository: repository, clock: clock)
        engine.startBreak()
        engine.skipBreak()
        let saved = try #require(try repository.load())
        var candidate = saved.state
        candidate.settings.intervalMinutes = 10
        candidate.schedule = .counting(deadline: clock.now.addingTimeInterval(600))
        #expect(throws: (any Error).self) { try repository.save(state: candidate, record: saved.history[0]) }
        #expect(try repository.load() == saved)
    }

    @Test func actualSQLiteWriteFailureKeepsConfirmedResults() throws {
        let url = try temporaryDatabase()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = try SQLiteRepository(url: url)
        let engine = try BreakEngine(repository: repository, clock: TestClock())
        engine.startBreak()
        engine.confirm(engine.drafts[0].id)
        var connection: OpaquePointer?
        #expect(sqlite3_open(url.path, &connection) == SQLITE_OK)
        defer { sqlite3_close(connection) }
        #expect(sqlite3_exec(connection, "CREATE TRIGGER fail_update BEFORE UPDATE ON app_state BEGIN SELECT RAISE(ABORT, 'Simulated disk failure'); END", nil, nil, nil) == SQLITE_OK)
        engine.confirm(engine.drafts[1].id)
        #expect(engine.hasUnsavedChange && engine.completedCount == 1)
        #expect(try repository.load()?.state.schedule.activeBreak?.completedCount == 1)
        #expect(sqlite3_exec(connection, "DROP TRIGGER fail_update", nil, nil, nil) == SQLITE_OK)
        engine.retrySaving()
        #expect(!engine.hasUnsavedChange && engine.completedCount == 2)
        let reopened = try BreakEngine(repository: SQLiteRepository(url: url), clock: TestClock())
        #expect(reopened.completedCount == 2)
    }

    @Test func corruptPayloadIsReportedAndNeverReplaced() throws {
        let url = try temporaryDatabase()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = try SQLiteRepository(url: url)
        _ = try BreakEngine(repository: repository, clock: TestClock())
        var connection: OpaquePointer?
        #expect(sqlite3_open(url.path, &connection) == SQLITE_OK)
        defer { sqlite3_close(connection) }
        #expect(sqlite3_exec(connection, "UPDATE app_state SET payload = x'7b'", nil, nil, nil) == SQLITE_OK)
        #expect(throws: (any Error).self) { try BreakEngine(repository: SQLiteRepository(url: url), clock: TestClock()) }
        #expect(throws: (any Error).self) { try repository.load() }
    }
}
