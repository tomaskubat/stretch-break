import AppKit
import StretchBreakCore
import SwiftUI

struct BreakPanelView: View {
    @Bindable var store: BreakEngine
    @ObservedObject var updater: AppUpdater
    var openWindow: (AppDestination) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "figure.stand").font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Palette.accent)
                Text("StretchBreak").font(.system(size: 14, weight: .semibold))
                Spacer()
                if store.phase == .active {
                    Text("BREAK IN PROGRESS").font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else if store.isPaused {
                    Label("Paused", systemImage: "pause.fill").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)
            Divider()

            if store.hasUnsavedChange {
                StorageErrorBanner(store: store).padding(12)
                Divider()
            }

            Group {
                if store.phase == .active { activeBreak } else { countdown }
            }
            .disabled(store.hasUnsavedChange)

            Divider()
            HStack(spacing: 16) {
                Button { openWindow(.settings) } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .keyboardShortcut(",")
                Button { openWindow(.history) } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                Spacer()
                Menu {
                    Button("About StretchBreak…") { openWindow(.about) }
                    if updater.isEnabled {
                        Button("Check for Updates…") { updater.checkForUpdates() }
                            .disabled(!updater.canCheckForUpdates)
                    }
                    Divider()
                    Button("Quit StretchBreak") { NSApplication.shared.terminate(nil) }
                        .keyboardShortcut("q")
                } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("More options")
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20).padding(.vertical, 14)
        }
        .frame(width: 380)
        .background(Palette.background)
    }

    private var countdown: some View {
        VStack(spacing: 0) {
            if let outcome = store.lastOutcome {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: outcome == .completed ? "checkmark.circle.fill" : "arrow.clockwise.circle.fill")
                        .font(.system(size: 21)).foregroundStyle(outcome == .completed ? Color.green : Color.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(outcome == .completed ? "Break complete. Nicely done." : "Next break, fresh start.")
                            .font(.system(size: 12, weight: .semibold))
                        Text(outcome == .partial ? "Your completed exercises were recorded." :
                                outcome == .skipped ? "Break skipped. Your interval has restarted." : "All \(store.state.receipt?.total ?? 0) exercises recorded.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12).cardStyle().padding(.bottom, 22)
                .accessibilityIdentifier("break-result")
            }

            Image(systemName: store.isPaused ? "pause.circle" : "timer")
                .font(.system(size: 30, weight: .light)).foregroundStyle(Palette.accent)
                .padding(.bottom, 12)
            Text(store.isPaused ? "Take your time" : "Your next movement break")
                .font(.system(size: 13)).foregroundStyle(.secondary)
            Text(store.countdownText)
                .font(.system(size: 44, weight: .light, design: .rounded))
                .monospacedDigit().padding(.top, 4)
                .accessibilityIdentifier("countdown")
            Text("Every \(store.intervalMinutes) \(store.intervalMinutes == 1 ? "minute" : "minutes") · \(store.definitions.count) \(store.definitions.count == 1 ? "exercise" : "exercises")")
                .font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 8)

            Button("Start break") { store.startBreak() }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .frame(maxWidth: .infinity).padding(.top, 24)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(!store.canStart)
                .accessibilityIdentifier("start-break")
            if store.phase == .countdown {
                Button { store.togglePause() } label: {
                    Label(store.isPaused ? "Resume" : "Pause", systemImage: store.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
                .padding(.top, 14)
                .keyboardShortcut("p")
            }
            if !store.canStart {
                Text("Add a named exercise in Settings to start a break.")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 10)
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 26)
    }

    private var activeBreak: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("A moment to move").font(.system(size: 22, weight: .semibold))
                Text("Keep the planned reps, or make them your own.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(store.drafts.enumerated()), id: \.element.id) { index, draft in
                        ExerciseRow(store: store, draft: draft, number: index + 1)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(330, CGFloat(store.drafts.reduce(0) { $0 + ($1.actual == nil ? 98 : 84) } + max(0, store.drafts.count - 1) * 8)))
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("\(store.completedCount) of \(store.drafts.count) completed")
                        .font(.system(size: 12, weight: .medium))
                        .accessibilityIdentifier("break-progress")
                    Spacer()
                    Text("\(Int(Double(store.completedCount) / Double(max(1, store.drafts.count)) * 100))%")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                ProgressView(value: Double(store.completedCount), total: Double(max(1, store.drafts.count)))
                    .tint(Palette.accent)
            }
            Button("Skip & restart") { store.skipBreak() }
                .buttonStyle(.bordered).controlSize(.large).frame(maxWidth: .infinity)
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .accessibilityIdentifier("skip-break")
        }
        .padding(20)
    }

}

private struct ExerciseRow: View {
    let store: BreakEngine
    let draft: ExerciseDraft
    let number: Int
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(draft.actual == nil ? Palette.accent.opacity(0.1) : Color.green.opacity(0.12))
                    if draft.actual != nil {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(.green)
                    } else {
                        Text(String(number)).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.accent)
                    }
                }.frame(width: 26, height: 26).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(draft.name).font(.system(size: 13, weight: .medium))
                        .lineLimit(2)
                    Text("Planned: \(draft.planned) reps").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if draft.actual != nil {
                    Button("Undo") { store.undo(draft.id) }.buttonStyle(.plain)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .accessibilityLabel("Undo \(draft.name)")
                }
            }
            if let actual = draft.actual {
                Label("Done · \(actual) reps recorded", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.green)
                    .accessibilityIdentifier("recorded-\(number)")
            } else {
                HStack(spacing: 6) {
                    Button { store.adjustRepetitions(for: draft.id, by: -1) } label: { Image(systemName: "minus") }
                        .accessibilityLabel("Decrease \(draft.name) reps")
                        .disabled(draft.validRepetitions == 1)
                    TextField("Reps", text: Binding(get: { draft.input }, set: { store.setInput($0, for: draft.id) }))
                        .textFieldStyle(.roundedBorder).multilineTextAlignment(.center)
                        .frame(width: 46).font(.system(size: 12).monospacedDigit())
                        .focused($inputFocused)
                        .onSubmit { if draft.validRepetitions != nil { inputFocused = false; store.confirm(draft.id) } }
                        .accessibilityLabel("\(draft.name) repetitions")
                        .accessibilityIdentifier("reps-\(number)")
                    Button { store.adjustRepetitions(for: draft.id, by: 1) } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Increase \(draft.name) reps")
                        .disabled(draft.validRepetitions == 999)
                    Text("reps").font(.system(size: 11)).foregroundStyle(.secondary).padding(.leading, 2)
                    Spacer()
                    Button("Done") { inputFocused = false; store.confirm(draft.id) }
                        .buttonStyle(.borderedProminent).disabled(draft.validRepetitions == nil)
                        .accessibilityLabel("Done \(draft.name)")
                        .accessibilityIdentifier("done-\(number)")
                }
                .controlSize(.regular)
                if draft.validRepetitions == nil {
                    Text("Enter a whole number from 1 to 999.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12).cardStyle()
    }
}
