import PrototypeCore
import SwiftUI

struct HistoryView: View {
    let store: PrototypeStore
    @State private var selectedID: UUID?

    init(store: PrototypeStore, selectedID: UUID? = nil) {
        self.store = store
        _selectedID = State(initialValue: selectedID ?? store.history.first?.id)
    }

    private var selected: BreakRecord? {
        store.history.first(where: { $0.id == selectedID }) ?? store.history.first
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("History").font(.system(size: 22, weight: .semibold))
                    Text("Your movement breaks").font(.system(size: 12)).foregroundStyle(.secondary)
                }.padding(22)
                List(selection: $selectedID) {
                    ForEach(store.history) { record in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(record.started, format: .dateTime.hour().minute())
                                    .font(.system(size: 14, weight: .medium)).monospacedDigit()
                                Spacer()
                                Text(dayLabel(record.started)).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            OutcomeLabel(outcome: record.outcome, usesColor: false)
                            Text("\(record.completedCount) of \(record.exercises.count) exercises")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .tag(record.id)
                        .accessibilityLabel("\(record.outcome.rawValue), \(record.started.formatted(date: .abbreviated, time: .shortened))")
                    }
                }
                .listStyle(.sidebar)
                Divider()
                Text("\(store.history.count) breaks recorded").font(.system(size: 11)).foregroundStyle(.secondary)
                    .padding(18)
            }
            .frame(width: 260)
            Divider()
            if let record = selected {
                recordDetail(record)
            } else {
                ContentUnavailableView("No breaks yet", systemImage: "clock.arrow.circlepath",
                                       description: Text("Completed and skipped breaks will appear here."))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 790, height: 550)
        .background(Palette.background)
    }

    private func recordDetail(_ record: BreakRecord) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 9) {
                Text(record.started, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.system(size: 20, weight: .semibold))
                HStack(spacing: 6) {
                    Text(record.started, format: .dateTime.hour().minute())
                    Image(systemName: "arrow.right").font(.system(size: 9))
                    Text(record.ended, format: .dateTime.hour().minute())
                }.font(.system(size: 12)).foregroundStyle(.secondary)
                OutcomeLabel(outcome: record.outcome).padding(.top, 2)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(record.completedCount)").font(.system(size: 30, weight: .light, design: .rounded))
                Text("of \(record.exercises.count) exercises completed").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                HStack {
                    Text("EXERCISE").frame(maxWidth: .infinity, alignment: .leading)
                    Text("PLANNED").frame(width: 64, alignment: .trailing)
                    Text("RECORDED").frame(width: 84, alignment: .trailing)
                }
                .font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                .padding(14)
                Divider()
                ForEach(Array(record.exercises.enumerated()), id: \.element.id) { index, exercise in
                    HistoryExerciseRow(exercise: exercise)
                    if index < record.exercises.count - 1 { Divider().padding(.horizontal, 14) }
                }
            }.cardStyle()
            Label("Skipped exercises have no recorded repetitions.", systemImage: "info.circle")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(26).frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

private struct HistoryExerciseRow: View {
    let exercise: RecordedExercise
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: exercise.actual == nil ? "arrow.forward.circle" : "checkmark.circle.fill")
                .foregroundStyle(exercise.actual == nil ? Color.secondary : Color.green)
                .accessibilityHidden(true)
            Text(exercise.name).font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(exercise.planned)").font(.system(size: 12)).monospacedDigit()
                .foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
            if let actual = exercise.actual {
                Text("\(actual) reps").font(.system(size: 12, weight: .medium)).monospacedDigit()
                    .frame(width: 84, alignment: .trailing)
            } else {
                Text("Skipped").font(.system(size: 11)).foregroundStyle(.secondary)
                    .frame(width: 84, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 18)
    }
}
