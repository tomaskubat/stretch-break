import Foundation
import Observation
import StretchBreakCore
import Testing

@MainActor
struct EngineTests {
    @Test func savingFailureUpdatesObservedUIState() throws {
        let repository = MemoryRepository()
        let engine = try BreakEngine(repository: repository, clock: TestClock())
        engine.startBreak()
        let flag = ObservationFlag()
        withObservationTracking { _ = engine.hasUnsavedChange } onChange: {
            MainActor.assumeIsolated { flag.changed = true }
        }
        repository.failSave = true
        engine.confirm(engine.drafts[0].id)
        #expect(flag.changed && engine.hasUnsavedChange)
        #expect(engine.completedCount == 0)
    }
    @Test func firstLaunchStartsAndPersistsFullInterval() throws {
        let repository = MemoryRepository()
        let clock = TestClock()
        let engine = try BreakEngine(repository: repository, clock: clock)
        #expect(engine.countdownText == "60:00")
        #expect(engine.history.isEmpty)
        #expect(repository.data?.state == engine.state)
        #expect(repository.saves == 1)
    }

    @Test func expiryCreatesExactlyOneBreakAndReminder() throws {
        let clock = TestClock()
        let reminders = ReminderSpy()
        let repository = MemoryRepository()
        let engine = try BreakEngine(repository: repository, clock: clock, reminders: reminders)
        clock.advance(3599)
        engine.tick()
        #expect(engine.activeBreak == nil && engine.countdownText == "00:01")
        clock.advance(1)
        engine.tick()
        let id = try #require(engine.activeBreak?.id)
        clock.advance(86400 * 30)
        for _ in 0..<100 { engine.tick() }
        #expect(engine.activeBreak?.id == id)
        #expect(reminders.delivered == [id])
        #expect(repository.saves == 2)
    }

    @Test func manualStartDoesNotSendReminderAndRetainsExerciseSnapshot() throws {
        let clock = TestClock()
        let reminders = ReminderSpy()
        let engine = try BreakEngine(repository: MemoryRepository(), clock: clock, reminders: reminders)
        clock.advance(60)
        engine.startBreak()
        let session = try #require(engine.activeBreak)
        #expect(session.started == clock.now)
        #expect(session.exercises.map(\.planned) == [10, 12, 15])
        #expect(reminders.attempts.isEmpty)
        engine.startBreak()
        #expect(engine.activeBreak?.id == session.id)
    }

    @Test func completionRecordsEditedCountAndRestartsFromClosingMoment() throws {
        let clock = TestClock()
        let engine = try BreakEngine(repository: MemoryRepository(), clock: clock)
        engine.startBreak()
        let ids = engine.drafts.map(\.id)
        engine.setInput("8", for: ids[0])
        engine.confirm(ids[0])
        engine.confirm(ids[1])
        clock.advance(123)
        engine.confirm(ids[2])
        #expect(engine.activeBreak == nil)
        #expect(engine.history.count == 1 && engine.lastOutcome == .completed)
        #expect(engine.history[0].exercises.map(\.actual) == [8, 12, 15])
        #expect(engine.history[0].ended == clock.now)
        #expect(engine.state.schedule == .counting(deadline: clock.now.addingTimeInterval(3600)))
        clock.advance(3599)
        engine.tick()
        #expect(engine.activeBreak == nil)
        clock.advance(1)
        engine.tick()
        #expect(engine.activeBreak != nil)
    }

    @Test func skippedAndPartialOutcomesPreserveRecordedResults() throws {
        let engine = try BreakEngine(repository: MemoryRepository(), clock: TestClock())
        engine.startBreak()
        engine.skipBreak()
        #expect(engine.history[0].outcome == .skipped)
        #expect(engine.history[0].exercises.allSatisfy { $0.actual == nil && $0.status == .skipped })
        engine.startBreak()
        engine.setInput("7", for: engine.drafts[0].id)
        engine.confirm(engine.drafts[0].id)
        engine.skipBreak()
        #expect(engine.history.map(\.outcome) == [.partial, .skipped])
        #expect(engine.history[0].exercises.map(\.actual) == [7, nil, nil])
        #expect(engine.countdownText == "60:00")
    }

    @Test func duplicateConfirmationCannotCreateDuplicateResult() throws {
        let repository = MemoryRepository()
        let engine = try BreakEngine(repository: repository, clock: TestClock())
        engine.startBreak()
        let ids = engine.drafts.map(\.id)
        engine.confirm(ids[0])
        let saved = repository.saves
        engine.confirm(ids[0])
        #expect(repository.saves == saved && engine.completedCount == 1)
        engine.confirm(ids[1])
        engine.confirm(ids[2])
        engine.confirm(ids[2])
        engine.skipBreak()
        #expect(engine.history.count == 1)
    }

    @Test(arguments: ["", "-1", "0", "1000", "abc", "1.5", " 3", "٣", "+3", "3\n"])
    func invalidRepetitionsCannotBeConfirmed(input: String) throws {
        let engine = try BreakEngine(repository: MemoryRepository(), clock: TestClock())
        engine.startBreak()
        let id = engine.drafts[0].id
        engine.setInput(input, for: id)
        engine.confirm(id)
        #expect(engine.drafts[0].actual == nil && engine.completedCount == 0)
    }

    @Test(arguments: [1, 999])
    func repetitionBoundariesAreAccepted(value: Int) throws {
        let engine = try BreakEngine(repository: MemoryRepository(), clock: TestClock())
        engine.startBreak()
        engine.setInput(String(value), for: engine.drafts[0].id)
        engine.confirm(engine.drafts[0].id)
        #expect(engine.drafts[0].actual == value)
    }

    @Test func undoAndPlusMinusAllowCorrectionWithinBounds() throws {
        let engine = try BreakEngine(repository: MemoryRepository(), clock: TestClock())
        engine.startBreak()
        let id = engine.drafts[0].id
        engine.confirm(id)
        engine.setInput("9", for: id)
        #expect(engine.drafts[0].actual == 10)
        engine.undo(id)
        engine.setInput("999", for: id)
        engine.adjustRepetitions(for: id, by: 1)
        #expect(engine.drafts[0].input == "999")
        engine.setInput("1", for: id)
        engine.adjustRepetitions(for: id, by: -1)
        #expect(engine.drafts[0].input == "1")
        engine.setInput("", for: id)
        engine.adjustRepetitions(for: id, by: 1)
        #expect(engine.drafts[0].input == "11")
        engine.confirm(id)
        #expect(engine.drafts[0].actual == 11)
    }

    @Test func pausePreservesRemainingTimeAcrossSleepAndRestart() throws {
        let repository = MemoryRepository()
        let clock = TestClock()
        let engine = try BreakEngine(repository: repository, clock: clock)
        clock.advance(600)
        engine.togglePause()
        #expect(engine.remainingSeconds == 3000)
        clock.advance(86400)
        let restored = try BreakEngine(repository: repository, clock: clock)
        #expect(restored.isPaused && restored.remainingSeconds == 3000)
        restored.togglePause()
        clock.advance(2999)
        restored.tick()
        #expect(restored.activeBreak == nil)
        clock.advance(1)
        restored.tick()
        #expect(restored.activeBreak != nil)
    }

    @Test func intervalChangesRestartFullCountdownAndKeepPause() throws {
        let clock = TestClock()
        let engine = try BreakEngine(repository: MemoryRepository(), clock: clock)
        clock.advance(100)
        var settings = engine.settings
        settings.intervalMinutes = 30
        #expect(engine.updateSettings(settings))
        #expect(engine.countdownText == "30:00")
        engine.togglePause()
        settings.intervalMinutes = 45
        #expect(engine.updateSettings(settings))
        #expect(engine.isPaused && engine.countdownText == "45:00")
    }

    @Test func settingsDuringOpenBreakApplyToNextBreakOnly() throws {
        let engine = try BreakEngine(repository: MemoryRepository(), clock: TestClock())
        engine.startBreak()
        let original = engine.drafts
        var settings = engine.settings
        settings.intervalMinutes = 15
        settings.exercises[0].name = "Edited exercise"
        settings.exercises[0].repetitions = 20
        settings.exercises.reverse()
        #expect(engine.updateSettings(settings))
        #expect(engine.drafts == original)
        engine.confirm(original[0].id)
        engine.skipBreak()
        #expect(engine.history[0].exercises[0].name == original[0].name)
        #expect(engine.countdownText == "15:00")
        engine.startBreak()
        #expect(engine.drafts.last?.name == "Edited exercise")
        #expect(engine.drafts.last?.planned == 20)
    }

    @Test func invalidSettingsAreRejectedWithoutChangingSavedState() throws {
        let repository = MemoryRepository()
        let engine = try BreakEngine(repository: repository, clock: TestClock())
        let original = engine.state
        var settings = engine.settings
        settings.intervalMinutes = 0
        #expect(!engine.updateSettings(settings))
        settings = engine.settings
        settings.exercises = []
        #expect(!engine.updateSettings(settings))
        settings.exercises = [ExerciseDefinition(name: " ", repetitions: 10)]
        #expect(!engine.updateSettings(settings))
        settings.exercises = [ExerciseDefinition(name: "One", repetitions: 1000)]
        #expect(!engine.updateSettings(settings))
        #expect(engine.state == original && repository.data?.state == original)
    }

    @Test func backwardAndForwardClockChangesNeverDuplicateBreaks() throws {
        let clock = TestClock()
        let reminders = ReminderSpy()
        let engine = try BreakEngine(repository: MemoryRepository(), clock: clock, reminders: reminders)
        clock.advance(-86400)
        engine.tick()
        #expect(engine.countdownText == "60:00" && engine.state.isValid)
        clock.advance(86400 * 3)
        engine.tick()
        let id = engine.activeBreak?.id
        clock.advance(-86400 * 7)
        engine.tick()
        #expect(engine.activeBreak?.id == id)
        engine.skipBreak()
        #expect(engine.history[0].ended >= engine.history[0].started)
        #expect(engine.history[0].isValid && engine.countdownText == "60:00")
        #expect(reminders.delivered.count == 1)
    }

    @Test func confirmationFailureKeepsCommittedResultsAndCanBeRetried() throws {
        let repository = MemoryRepository()
        let engine = try BreakEngine(repository: repository, clock: TestClock())
        engine.startBreak()
        let ids = engine.drafts.map(\.id)
        engine.confirm(ids[0])
        engine.confirm(ids[1])
        repository.failSave = true
        engine.confirm(ids[2])
        #expect(engine.hasUnsavedChange && engine.persistenceError != nil)
        #expect(engine.completedCount == 2 && engine.history.isEmpty)
        #expect(repository.data?.state.schedule.activeBreak?.completedCount == 2)
        engine.skipBreak()
        engine.undo(ids[0])
        #expect(engine.completedCount == 2)
        repository.failSave = false
        engine.retrySaving()
        engine.retrySaving()
        #expect(!engine.hasUnsavedChange && engine.history.count == 1)
        #expect(engine.history[0].outcome == .completed)
    }

    @Test func expirySaveFailureCannotDeliverAnUncommittedReminder() throws {
        let repository = MemoryRepository()
        let clock = TestClock()
        let reminders = ReminderSpy()
        let engine = try BreakEngine(repository: repository, clock: clock, reminders: reminders)
        repository.failSave = true
        clock.advance(3600)
        engine.tick()
        #expect(engine.activeBreak == nil && reminders.attempts.isEmpty)
        #expect(engine.hasUnsavedChange)
        repository.failSave = false
        engine.retrySaving()
        #expect(engine.activeBreak != nil && reminders.delivered.count == 1)
        let restored = try BreakEngine(repository: repository, clock: clock, reminders: reminders)
        restored.tick()
        #expect(restored.activeBreak?.id == engine.activeBreak?.id && reminders.delivered.count == 1)
    }

    @Test func deniedOrDisabledNotificationsDoNotBlockTheBreak() throws {
        let clock = TestClock()
        let reminders = ReminderSpy()
        reminders.permissionGranted = false
        let engine = try BreakEngine(repository: MemoryRepository(), clock: clock, reminders: reminders)
        clock.advance(3600)
        engine.tick()
        #expect(engine.activeBreak != nil && reminders.delivered.isEmpty)
        engine.skipBreak()
        var settings = engine.settings
        settings.notificationsEnabled = false
        engine.updateSettings(settings)
        clock.advance(3600)
        engine.tick()
        #expect(engine.activeBreak != nil && reminders.attempts.count == 1)
    }

    @Test func loadFailureNeverResetsSavedData() throws {
        let repository = MemoryRepository()
        repository.failLoad = true
        #expect(throws: (any Error).self) { try BreakEngine(repository: repository, clock: TestClock()) }
        #expect(repository.saves == 0)
    }
}

@MainActor private final class ObservationFlag { var changed = false }
