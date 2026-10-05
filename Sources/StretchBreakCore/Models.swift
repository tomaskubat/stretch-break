import Foundation

public struct ExerciseDefinition: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var repetitions: Int

    public init(id: UUID = UUID(), name: String, repetitions: Int) {
        self.id = id
        self.name = name
        self.repetitions = repetitions
    }

    public static let defaults = [
        ExerciseDefinition(name: "Shoulder rolls", repetitions: 10),
        ExerciseDefinition(name: "Wall push-ups", repetitions: 12),
        ExerciseDefinition(name: "Calf raises", repetitions: 15)
    ]

    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (1...999).contains(repetitions)
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var intervalMinutes: Int
    public var notificationsEnabled: Bool
    public var exercises: [ExerciseDefinition]

    public init(intervalMinutes: Int = 60, notificationsEnabled: Bool = true,
                exercises: [ExerciseDefinition] = ExerciseDefinition.defaults) {
        self.intervalMinutes = intervalMinutes
        self.notificationsEnabled = notificationsEnabled
        self.exercises = exercises
    }

    public var isValid: Bool {
        (1...240).contains(intervalMinutes) && !exercises.isEmpty && exercises.allSatisfy(\.isValid)
            && Set(exercises.map(\.id)).count == exercises.count
    }
}

public struct ExerciseDraft: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let planned: Int
    public var input: String
    public var actual: Int?

    public init(definition: ExerciseDefinition) {
        id = definition.id
        name = definition.name
        planned = definition.repetitions
        input = String(definition.repetitions)
    }

    public var validRepetitions: Int? { Self.repetitions(from: input) }

    public static func repetitions(from text: String) -> Int? {
        guard !text.isEmpty, text.allSatisfy({ $0.isASCII && $0.isNumber }),
              let number = Int(text), (1...999).contains(number) else { return nil }
        return number
    }

    public var isValidSnapshot: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (1...999).contains(planned)
            && (actual == nil || (1...999).contains(actual!))
    }
}

public struct ActiveBreak: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let started: Date
    public var exercises: [ExerciseDraft]

    public init(id: UUID = UUID(), started: Date, definitions: [ExerciseDefinition]) {
        self.id = id
        self.started = started
        exercises = definitions.map(ExerciseDraft.init)
    }

    public var completedCount: Int { exercises.filter { $0.actual != nil }.count }
    public var isValid: Bool {
        started.timeIntervalSince1970.isFinite && !exercises.isEmpty
            && exercises.allSatisfy(\.isValidSnapshot)
            && Set(exercises.map(\.id)).count == exercises.count
            && completedCount < exercises.count
    }
}

public enum BreakOutcome: String, Codable, CaseIterable, Sendable {
    case completed = "Completed"
    case skipped = "Skipped"
    case partial = "Partially completed"
}

public enum RecordedExerciseStatus: String, Codable, Sendable {
    case completed
    case skipped
}

public struct RecordedExercise: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let planned: Int
    public let actual: Int?
    public let status: RecordedExerciseStatus

    public init(_ draft: ExerciseDraft) {
        id = draft.id
        name = draft.name
        planned = draft.planned
        actual = draft.actual
        status = actual == nil ? .skipped : .completed
    }

    public var isValid: Bool {
        !name.isEmpty && (1...999).contains(planned)
            && ((actual == nil && status == .skipped)
                || (actual != nil && (1...999).contains(actual!) && status == .completed))
    }
}

public struct BreakRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let started: Date
    public let ended: Date
    public let outcome: BreakOutcome
    public let exercises: [RecordedExercise]

    public init(session: ActiveBreak, ended: Date) {
        id = session.id
        started = session.started
        self.ended = max(ended, session.started)
        exercises = session.exercises.map(RecordedExercise.init)
        outcome = session.completedCount == exercises.count ? .completed :
            session.completedCount == 0 ? .skipped : .partial
    }

    public var completedCount: Int { exercises.filter { $0.status == .completed }.count }
    public var isValid: Bool {
        let expected: BreakOutcome = completedCount == exercises.count ? .completed :
            completedCount == 0 ? .skipped : .partial
        return !exercises.isEmpty && exercises.allSatisfy(\.isValid)
            && Set(exercises.map(\.id)).count == exercises.count
            && started.timeIntervalSince1970.isFinite && ended.timeIntervalSince1970.isFinite
            && ended >= started && outcome == expected
    }
}

public enum ScheduleState: Codable, Equatable, Sendable {
    case counting(deadline: Date)
    case paused(remainingSeconds: TimeInterval)
    case open(ActiveBreak)

    public var activeBreak: ActiveBreak? {
        if case .open(let session) = self { return session }
        return nil
    }
}

public struct BreakReceipt: Codable, Equatable, Sendable {
    public let outcome: BreakOutcome
    public let completed: Int
    public let total: Int

    public init(record: BreakRecord) {
        outcome = record.outcome
        completed = record.completedCount
        total = record.exercises.count
    }
}

public struct AppState: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var settings: AppSettings
    public var schedule: ScheduleState
    public var receipt: BreakReceipt?

    public init(settings: AppSettings = AppSettings(), now: Date) {
        self.settings = settings
        schedule = .counting(deadline: now.addingTimeInterval(TimeInterval(settings.intervalMinutes * 60)))
    }

    public var isValid: Bool {
        guard schemaVersion == 1, settings.isValid else { return false }
        switch schedule {
        case .counting(let deadline): return deadline.timeIntervalSince1970.isFinite
        case .paused(let seconds): return seconds.isFinite && seconds >= 0 && seconds <= Double(settings.intervalMinutes * 60)
        case .open(let session): return session.isValid
        }
    }
}

public struct LoadedData: Equatable, Sendable {
    public let state: AppState
    public let history: [BreakRecord]
    public init(state: AppState, history: [BreakRecord]) { self.state = state; self.history = history }
}
