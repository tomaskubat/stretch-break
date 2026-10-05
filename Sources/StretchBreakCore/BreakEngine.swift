import Foundation
import Observation

public enum PanelPhase { case countdown, active }

@MainActor @Observable
public final class BreakEngine {
    public private(set) var state: AppState
    public private(set) var history: [BreakRecord]
    public private(set) var now: Date
    public private(set) var persistenceError: String?
    @ObservationIgnored private let repository: any StateRepository
    @ObservationIgnored private let clock: any TimeSource
    @ObservationIgnored private let reminders: any ReminderDelivering
    private var pending: PendingChange?
    @ObservationIgnored public var onChange: (() -> Void)?

    private struct PendingChange {
        let state: AppState
        let record: BreakRecord?
        let sendReminder: Bool
    }

    public init(repository: any StateRepository, clock: any TimeSource,
                reminders: any ReminderDelivering = SilentReminders()) throws {
        self.repository = repository
        self.clock = clock
        self.reminders = reminders
        now = clock.now
        if let loaded = try repository.load() {
            guard loaded.state.isValid, loaded.history.allSatisfy(\.isValid) else { throw EngineError.invalidStoredData }
            state = loaded.state
            history = loaded.history
        } else {
            let initial = AppState(now: clock.now)
            try repository.save(state: initial, record: nil)
            state = initial
            history = []
        }
        tick()
    }

    public var settings: AppSettings { state.settings }
    public var intervalMinutes: Int { settings.intervalMinutes }
    public var definitions: [ExerciseDefinition] { settings.exercises }
    public var notificationsEnabled: Bool { settings.notificationsEnabled }
    public var activeBreak: ActiveBreak? { state.schedule.activeBreak }
    public var drafts: [ExerciseDraft] { activeBreak?.exercises ?? [] }
    public var phase: PanelPhase { activeBreak == nil ? .countdown : .active }
    public var isPaused: Bool { if case .paused = state.schedule { true } else { false } }
    public var completedCount: Int { activeBreak?.completedCount ?? 0 }
    public var lastOutcome: BreakOutcome? { state.receipt?.outcome }
    public var canStart: Bool { pending == nil && activeBreak == nil && settings.isValid }
    public var hasUnsavedChange: Bool { pending != nil }
    public var remainingSeconds: TimeInterval {
        switch state.schedule {
        case .counting(let deadline): max(0, min(Double(intervalMinutes * 60), deadline.timeIntervalSince(now)))
        case .paused(let seconds): seconds
        case .open: 0
        }
    }
    public var countdownText: String {
        let seconds = Int(ceil(remainingSeconds))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    public func tick() {
        now = clock.now
        guard pending == nil, case .counting(let deadline) = state.schedule else { return }
        let remaining = deadline.timeIntervalSince(now)
        if remaining <= 0 {
            var next = state
            next.schedule = .open(ActiveBreak(started: now, definitions: definitions))
            next.receipt = nil
            commit(next, sendReminder: true)
        } else if remaining > Double(intervalMinutes * 60) {
            // A backward wall-clock change can never extend a countdown past a full interval.
            var next = state
            next.schedule = .counting(deadline: now.addingTimeInterval(Double(intervalMinutes * 60)))
            commit(next)
        }
    }

    public func startBreak() {
        tick()
        guard canStart else { return }
        var next = state
        next.schedule = .open(ActiveBreak(started: now, definitions: definitions))
        next.receipt = nil
        commit(next)
    }

    public func togglePause() {
        tick()
        guard pending == nil else { return }
        var next = state
        switch state.schedule {
        case .counting: next.schedule = .paused(remainingSeconds: remainingSeconds)
        case .paused(let seconds): next.schedule = .counting(deadline: now.addingTimeInterval(seconds))
        case .open: return
        }
        commit(next)
    }

    @discardableResult
    public func updateSettings(_ settings: AppSettings) -> Bool {
        tick()
        guard pending == nil, settings.isValid else { return false }
        var next = state
        let intervalChanged = settings.intervalMinutes != intervalMinutes
        next.settings = settings
        if intervalChanged {
            switch next.schedule {
            case .counting: next.schedule = .counting(deadline: now.addingTimeInterval(Double(settings.intervalMinutes * 60)))
            case .paused: next.schedule = .paused(remainingSeconds: Double(settings.intervalMinutes * 60))
            case .open: break
            }
        }
        return commit(next)
    }

    public func setInput(_ text: String, for id: UUID) {
        changeExercise(id) { exercise in
            guard exercise.actual == nil else { return }
            exercise.input = text
        }
    }

    public func adjustRepetitions(for id: UUID, by difference: Int) {
        guard let draft = drafts.first(where: { $0.id == id }), draft.actual == nil else { return }
        let number = draft.validRepetitions ?? draft.planned
        setInput(String(min(999, max(1, number + difference))), for: id)
    }

    public func confirm(_ id: UUID) {
        guard pending == nil, var session = activeBreak,
              let index = session.exercises.firstIndex(where: { $0.id == id }),
              session.exercises[index].actual == nil,
              let number = session.exercises[index].validRepetitions else { return }
        session.exercises[index].actual = number
        if session.completedCount == session.exercises.count {
            close(session)
        } else {
            var next = state
            next.schedule = .open(session)
            commit(next)
        }
    }

    public func undo(_ id: UUID) {
        changeExercise(id) { $0.actual = nil }
    }

    public func skipBreak() {
        guard pending == nil, let session = activeBreak else { return }
        close(session)
    }

    public func retrySaving() {
        guard let pending else { return }
        commit(pending.state, record: pending.record, sendReminder: pending.sendReminder)
        if self.pending == nil { tick() }
    }

    private func changeExercise(_ id: UUID, change: (inout ExerciseDraft) -> Void) {
        guard pending == nil, var session = activeBreak,
              let index = session.exercises.firstIndex(where: { $0.id == id }) else { return }
        change(&session.exercises[index])
        var next = state
        next.schedule = .open(session)
        commit(next)
    }

    private func close(_ session: ActiveBreak) {
        now = clock.now
        let record = BreakRecord(session: session, ended: now)
        var next = state
        next.schedule = .counting(deadline: now.addingTimeInterval(Double(intervalMinutes * 60)))
        next.receipt = BreakReceipt(record: record)
        commit(next, record: record)
    }

    @discardableResult
    private func commit(_ next: AppState, record: BreakRecord? = nil, sendReminder: Bool = false) -> Bool {
        guard next != state || record != nil else { return true }
        do {
            try repository.save(state: next, record: record)
            let previousSession = activeBreak
            state = next
            if let record { history.insert(record, at: 0) }
            pending = nil
            persistenceError = nil
            if let previousSession, activeBreak == nil || !notificationsEnabled {
                reminders.cancelReminder(id: previousSession.id)
            }
            if sendReminder, notificationsEnabled, let session = activeBreak {
                reminders.sendReminder(for: session)
            }
            onChange?()
            return true
        } catch {
            pending = PendingChange(state: next, record: record, sendReminder: sendReminder)
            persistenceError = error.localizedDescription
            onChange?()
            return false
        }
    }

    public enum EngineError: LocalizedError {
        case invalidStoredData
        public var errorDescription: String? { "The saved data is invalid or from an unsupported version. Your database has not been replaced." }
    }
}
