import Foundation
import Observation

public struct ExerciseDefinition: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var repetitions: Int

    public init(id: UUID = UUID(), name: String, repetitions: Int) {
        self.id = id
        self.name = name
        self.repetitions = repetitions
    }

    public static let samples = [
        ExerciseDefinition(name: "Shoulder rolls", repetitions: 10),
        ExerciseDefinition(name: "Wall push-ups", repetitions: 12),
        ExerciseDefinition(name: "Calf raises", repetitions: 15)
    ]
}

public struct ExerciseDraft: Identifiable, Equatable, Sendable {
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
        actual = nil
    }

    public var validRepetitions: Int? {
        guard !input.isEmpty, input.allSatisfy({ $0.isASCII && $0.isNumber }),
              let number = Int(input), (1...999).contains(number) else { return nil }
        return number
    }
}

public enum BreakOutcome: String, CaseIterable, Sendable {
    case completed = "Completed"
    case skipped = "Skipped"
    case partial = "Partially completed"
}

public struct RecordedExercise: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let planned: Int
    public let actual: Int?

    public init(_ draft: ExerciseDraft) {
        id = draft.id
        name = draft.name
        planned = draft.planned
        actual = draft.actual
    }
}

public struct BreakRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let started: Date
    public let ended: Date
    public let outcome: BreakOutcome
    public let exercises: [RecordedExercise]

    public init(id: UUID = UUID(), started: Date, ended: Date, outcome: BreakOutcome,
                exercises: [RecordedExercise]) {
        self.id = id
        self.started = started
        self.ended = ended
        self.outcome = outcome
        self.exercises = exercises
    }

    public var completedCount: Int { exercises.filter { $0.actual != nil }.count }
}

public enum DemoScenario: String, CaseIterable, Identifiable, Sendable {
    case countdown = "Counting down"
    case paused = "Paused"
    case ready = "Break ready"
    case inProgress = "In progress"
    case completed = "Completed"
    case partial = "Partially skipped"
    case skipped = "Skipped"

    public var id: String { rawValue }
}

public enum DemoAppearance: String, CaseIterable, Identifiable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    public var id: String { rawValue }
}

public enum PanelPhase: Equatable, Sendable {
    case countdown
    case ready
    case active
}

/// In-memory interactions for design review. No clock, storage, or notification service.
@MainActor @Observable
public final class PrototypeStore {
    public var intervalMinutes = 60
    public var notificationsEnabled = true
    public var definitions = ExerciseDefinition.samples
    public var appearance = DemoAppearance.system
    public private(set) var phase = PanelPhase.countdown
    public private(set) var isPaused = false
    public private(set) var displayedSeconds = 24 * 60 + 38
    public private(set) var drafts: [ExerciseDraft] = []
    public private(set) var history: [BreakRecord] = []
    public private(set) var lastOutcome: BreakOutcome?
    public private(set) var startedAt: Date?

    public init() { history = Self.sampleHistory() }

    public var completedCount: Int { drafts.filter { $0.actual != nil }.count }
    public var countdownText: String {
        String(format: "%02d:%02d", displayedSeconds / 60, displayedSeconds % 60)
    }
    public var canStart: Bool {
        !definitions.isEmpty && definitions.allSatisfy {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (1...999).contains($0.repetitions)
        }
    }

    public func startBreak() {
        guard phase != .active, canStart else { return }
        drafts = definitions.map(ExerciseDraft.init)
        phase = .active
        isPaused = false
        lastOutcome = nil
        startedAt = Date()
    }

    public func togglePause() {
        guard phase == .countdown else { return }
        isPaused.toggle()
    }

    public func changeInterval(to minutes: Int) {
        intervalMinutes = min(240, max(1, minutes))
        if phase == .countdown { displayedSeconds = intervalMinutes * 60 }
    }

    public func setInput(_ text: String, for id: UUID) {
        guard phase == .active, let index = drafts.firstIndex(where: { $0.id == id }),
              drafts[index].actual == nil else { return }
        drafts[index].input = text
    }

    public func adjustRepetitions(for id: UUID, by difference: Int) {
        guard let draft = drafts.first(where: { $0.id == id }), draft.actual == nil else { return }
        let number = draft.validRepetitions ?? draft.planned
        setInput(String(min(999, max(1, number + difference))), for: id)
    }

    public func confirm(_ id: UUID) {
        guard phase == .active, let index = drafts.firstIndex(where: { $0.id == id }),
              drafts[index].actual == nil, let number = drafts[index].validRepetitions else { return }
        drafts[index].actual = number
        if completedCount == drafts.count { closeBreak(outcome: .completed) }
    }

    public func undo(_ id: UUID) {
        guard phase == .active, let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[index].actual = nil
    }

    public func skipBreak() {
        guard phase == .active else { return }
        closeBreak(outcome: completedCount == 0 ? .skipped : .partial)
    }

    private func closeBreak(outcome: BreakOutcome) {
        let ended = Date()
        history.insert(BreakRecord(started: startedAt ?? ended, ended: ended, outcome: outcome,
                                   exercises: drafts.map(RecordedExercise.init)), at: 0)
        phase = .countdown
        isPaused = false
        displayedSeconds = intervalMinutes * 60
        lastOutcome = outcome
        startedAt = nil
    }

    public func addExercise() {
        definitions.append(ExerciseDefinition(name: "New exercise", repetitions: 10))
    }

    public func removeExercise(_ id: UUID) { definitions.removeAll { $0.id == id } }

    public func moveExercise(_ id: UUID, by offset: Int) {
        guard let index = definitions.firstIndex(where: { $0.id == id }),
              definitions.indices.contains(index + offset) else { return }
        definitions.swapAt(index, index + offset)
    }

    public func showScenario(_ scenario: DemoScenario) {
        // Scenarios reset sample data so every state remains one click away.
        definitions = ExerciseDefinition.samples
        intervalMinutes = 60
        history = Self.sampleHistory()
        drafts = []
        phase = .countdown
        isPaused = false
        lastOutcome = nil
        startedAt = nil
        displayedSeconds = 24 * 60 + 38
        switch scenario {
        case .countdown: break
        case .paused: isPaused = true
        case .ready:
            phase = .ready
            displayedSeconds = 0
        case .inProgress:
            startBreak()
            setInput("8", for: drafts[0].id)
            confirm(drafts[0].id)
        case .completed:
            startBreak()
            for id in drafts.map(\.id) { confirm(id) }
        case .partial:
            startBreak()
            confirm(drafts[0].id)
            skipBreak()
        case .skipped:
            startBreak()
            skipBreak()
        }
    }

    public func resetSamples() {
        notificationsEnabled = true
        showScenario(.countdown)
    }

    private static func sampleHistory() -> [BreakRecord] {
        let anchor = Date().addingTimeInterval(-3600)
        func sample(minutesAgo: Int, outcome: BreakOutcome, actuals: [Int?]) -> BreakRecord {
            let start = anchor.addingTimeInterval(TimeInterval(-minutesAgo * 60))
            var drafts = ExerciseDefinition.samples.map(ExerciseDraft.init)
            for index in drafts.indices { drafts[index].actual = actuals[index] }
            return BreakRecord(started: start, ended: start.addingTimeInterval(120), outcome: outcome,
                               exercises: drafts.map(RecordedExercise.init))
        }
        return [
            sample(minutesAgo: 0, outcome: .completed, actuals: [10, 12, 15]),
            sample(minutesAgo: 60, outcome: .partial, actuals: [8, nil, 15]),
            sample(minutesAgo: 120, outcome: .skipped, actuals: [nil, nil, nil]),
            sample(minutesAgo: 1080, outcome: .completed, actuals: [10, 10, 15]),
            sample(minutesAgo: 1200, outcome: .completed, actuals: [12, 12, 15])
        ]
    }
}
