import Foundation
import PrototypeCore
import Testing

@MainActor
struct PrototypeInteractionTests {
    @Test func plannedCountNeedsOneConfirmation() {
        let store = PrototypeStore()
        store.startBreak()
        store.confirm(store.drafts[0].id)
        #expect(store.completedCount == 1)
        #expect(store.drafts[0].actual == 10)
        #expect(store.phase == .active)
    }

    @Test func editedCountIsRecordedAndUndoAllowsCorrection() {
        let store = PrototypeStore()
        store.startBreak()
        let id = store.drafts[0].id
        store.setInput("8", for: id)
        store.confirm(id)
        #expect(store.drafts[0].actual == 8)
        store.undo(id)
        store.setInput("9", for: id)
        store.confirm(id)
        #expect(store.drafts[0].actual == 9)
        #expect(store.completedCount == 1)
    }

    @Test(arguments: ["", "-1", "0", "1000", "abc", "1.5", " 3", "٣"])
    func invalidInputCannotBeConfirmed(input: String) {
        let store = PrototypeStore()
        store.startBreak()
        let id = store.drafts[0].id
        store.setInput(input, for: id)
        store.confirm(id)
        #expect(store.completedCount == 0)
    }

    @Test func plusMinusUsesBoundsAndCanRecoverInvalidInput() {
        let store = PrototypeStore()
        store.startBreak()
        let id = store.drafts[0].id
        store.setInput("999", for: id)
        store.adjustRepetitions(for: id, by: 1)
        #expect(store.drafts[0].input == "999")
        store.setInput("1", for: id)
        store.adjustRepetitions(for: id, by: -1)
        #expect(store.drafts[0].input == "1")
        store.setInput("", for: id)
        store.adjustRepetitions(for: id, by: 1)
        #expect(store.drafts[0].input == "11")
    }

    @Test func lastConfirmationShowsCompletionAndFullInterval() {
        let store = PrototypeStore()
        store.changeInterval(to: 45)
        store.startBreak()
        for id in store.drafts.map(\.id) { store.confirm(id) }
        #expect(store.phase == .countdown)
        #expect(store.lastOutcome == .completed)
        #expect(store.countdownText == "45:00")
        #expect(store.history[0].completedCount == 3)
    }

    @Test func duplicateConfirmationDoesNotCreateAnotherRecord() {
        let store = PrototypeStore()
        store.startBreak()
        let ids = store.drafts.map(\.id)
        store.confirm(ids[0])
        store.confirm(ids[0])
        #expect(store.completedCount == 1)
        store.confirm(ids[1])
        store.confirm(ids[2])
        let count = store.history.count
        store.confirm(ids[2])
        #expect(store.history.count == count)
    }

    @Test func skippingAllAndSkippingPartPreserveDifferentOutcomes() {
        let store = PrototypeStore()
        store.startBreak()
        store.skipBreak()
        #expect(store.lastOutcome == .skipped)
        #expect(store.history[0].exercises.allSatisfy { $0.actual == nil })
        store.startBreak()
        store.setInput("7", for: store.drafts[0].id)
        store.confirm(store.drafts[0].id)
        store.skipBreak()
        #expect(store.lastOutcome == .partial)
        #expect(store.history[0].exercises[0].actual == 7)
        #expect(store.history[0].exercises[1].actual == nil)
        #expect(store.countdownText == "60:00")
    }

    @Test func changingSettingsDoesNotRewriteAnOpenBreakOrHistory() {
        let store = PrototypeStore()
        store.startBreak()
        let originalName = store.drafts[0].name
        store.definitions[0].name = "Edited exercise"
        store.definitions[0].repetitions = 20
        store.changeInterval(to: 30)
        #expect(store.drafts[0].name == originalName)
        #expect(store.drafts[0].planned == 10)
        store.confirm(store.drafts[0].id)
        store.skipBreak()
        #expect(store.countdownText == "30:00")
        #expect(store.history[0].exercises[0].name == originalName)
        store.startBreak()
        #expect(store.drafts[0].name == "Edited exercise")
        #expect(store.drafts[0].planned == 20)
    }

    @Test func pauseResumeAndIntervalEditKeepVisibleStateCoherent() {
        let store = PrototypeStore()
        store.togglePause()
        let seconds = store.displayedSeconds
        #expect(store.isPaused)
        store.togglePause()
        #expect(!store.isPaused)
        #expect(store.displayedSeconds == seconds)
        store.togglePause()
        store.changeInterval(to: 90)
        #expect(store.isPaused)
        #expect(store.countdownText == "90:00")
        store.startBreak()
        store.togglePause()
        #expect(!store.isPaused)
    }

    @Test func exerciseListCanBeAddedReorderedAndRemoved() {
        let store = PrototypeStore()
        store.addExercise()
        let id = store.definitions.last!.id
        store.moveExercise(id, by: -1)
        #expect(store.definitions[2].id == id)
        store.removeExercise(id)
        #expect(store.definitions.count == 3)
        #expect(store.definitions.map(\.name) == ExerciseDefinition.samples.map(\.name))
    }

    @Test func emptyOrUnnamedExerciseListCannotStart() {
        let store = PrototypeStore()
        store.definitions = []
        store.startBreak()
        #expect(store.phase == .countdown)
        store.addExercise()
        store.definitions[0].name = "  "
        #expect(!store.canStart)
    }

    @Test func presetsReachEveryReviewStateAndResetEdits() {
        let store = PrototypeStore()
        for scenario in DemoScenario.allCases {
            store.showScenario(scenario)
            #expect(store.definitions.count == 3)
            #expect(store.intervalMinutes == 60)
            switch scenario {
            case .countdown: #expect(store.countdownText == "24:38")
            case .paused: #expect(store.isPaused)
            case .ready: #expect(store.phase == .ready)
            case .inProgress: #expect(store.completedCount == 1 && store.phase == .active)
            case .completed: #expect(store.lastOutcome == .completed)
            case .partial: #expect(store.lastOutcome == .partial)
            case .skipped: #expect(store.lastOutcome == .skipped)
            }
        }
        store.resetSamples()
        #expect(store.lastOutcome == nil)
        #expect(store.history.count == 5)
    }

    @Test func relaunchUsesFreshSamples() {
        let store = PrototypeStore()
        store.changeInterval(to: 15)
        store.notificationsEnabled = false
        store.startBreak()
        let relaunched = PrototypeStore()
        #expect(relaunched.intervalMinutes == 60)
        #expect(relaunched.notificationsEnabled)
        #expect(relaunched.phase == .countdown)
        #expect(relaunched.history.count == 5)
    }
}
