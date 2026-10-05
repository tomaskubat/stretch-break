import StretchBreakCore
import StretchBreakMac
import SwiftUI

private struct EditableExercise: Identifiable, Equatable {
    let id: UUID
    var name: String
    var repetitions: String
    init(_ definition: ExerciseDefinition) {
        id = definition.id
        name = definition.name
        repetitions = String(definition.repetitions)
    }
    var definition: ExerciseDefinition? {
        guard let reps = ExerciseDraft.repetitions(from: repetitions),
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return ExerciseDefinition(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), repetitions: reps)
    }
}

struct SettingsView: View {
    let store: BreakEngine
    let reminders: MacReminders
    let updater: AppUpdater
    @State private var intervalText: String
    @State private var notifications: Bool
    @State private var exercises: [EditableExercise]
    @State private var saved = false

    init(store: BreakEngine, reminders: MacReminders, updater: AppUpdater) {
        self.store = store
        self.reminders = reminders
        self.updater = updater
        _intervalText = State(initialValue: String(store.intervalMinutes))
        _notifications = State(initialValue: store.notificationsEnabled)
        _exercises = State(initialValue: store.definitions.map(EditableExercise.init))
    }

    private var candidate: AppSettings? {
        guard let minutes = Int(intervalText), intervalText.allSatisfy({ $0.isASCII && $0.isNumber }),
              (1...240).contains(minutes), !exercises.isEmpty else { return nil }
        let definitions = exercises.compactMap(\.definition)
        guard definitions.count == exercises.count else { return nil }
        return AppSettings(intervalMinutes: minutes, notificationsEnabled: notifications, exercises: definitions)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionHeading(title: "Settings", subtitle: "Make room for movement in your day.")
                    if store.hasUnsavedChange { StorageErrorBanner(store: store) }
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Break interval").font(.system(size: 13, weight: .medium))
                                Text("Time between movement breaks.").font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            TextField("Minutes", text: $intervalText).textFieldStyle(.roundedBorder)
                                .frame(width: 55).multilineTextAlignment(.trailing)
                                .accessibilityLabel("Break interval in minutes")
                                .accessibilityIdentifier("interval-minutes")
                            Text("min").foregroundStyle(.secondary)
                            Stepper("Break interval", value: Binding(get: { Int(intervalText) ?? store.intervalMinutes },
                                                                     set: { intervalText = String($0) }), in: 1...240)
                                .labelsHidden()
                        }
                        Divider()
                        Toggle(isOn: $notifications) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("System notifications").font(.system(size: 13, weight: .medium))
                                Text("Show a notification when a break is ready.").font(.system(size: 11)).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.toggleStyle(.switch).accessibilityLabel("System notifications")
                        if notifications {
                            Text(reminders.permissionDescription).font(.system(size: 11)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }.padding(18).cardStyle().disabled(store.hasUnsavedChange)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Your exercises").font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Button {
                                exercises.append(EditableExercise(ExerciseDefinition(name: "New exercise", repetitions: 10)))
                            } label: { Label("Add exercise", systemImage: "plus") }
                            .accessibilityIdentifier("add-exercise")
                        }
                        Text("Changes apply to your next break.").font(.system(size: 11)).foregroundStyle(.secondary)
                        VStack(spacing: 0) {
                            HStack {
                                Text("EXERCISE").frame(maxWidth: .infinity, alignment: .leading)
                                Text("REPS").frame(width: 88, alignment: .leading)
                                Text("ORDER").frame(width: 60)
                                Spacer().frame(width: 22)
                            }.font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                                .padding(.horizontal, 14).padding(.vertical, 12)
                            Divider()
                            ForEach($exercises) { $exercise in
                                let index = exercises.firstIndex(where: { $0.id == exercise.id }) ?? 0
                                HStack(spacing: 10) {
                                    TextField("Exercise name", text: $exercise.name).textFieldStyle(.roundedBorder)
                                        .accessibilityLabel("Exercise \(index + 1) name")
                                    TextField("Reps", text: $exercise.repetitions).textFieldStyle(.roundedBorder)
                                        .frame(width: 48).multilineTextAlignment(.trailing)
                                        .accessibilityLabel("Exercise \(index + 1) planned repetitions")
                                    Stepper("Repetitions", value: Binding(get: { Int(exercise.repetitions) ?? 10 },
                                                                         set: { exercise.repetitions = String($0) }), in: 1...999)
                                        .labelsHidden().fixedSize()
                                    HStack(spacing: 2) {
                                        Button { exercises.swapAt(index, index - 1) } label: { Image(systemName: "chevron.up") }
                                            .disabled(index == 0).accessibilityLabel("Move \(exercise.name) up")
                                        Button { exercises.swapAt(index, index + 1) } label: { Image(systemName: "chevron.down") }
                                            .disabled(index == exercises.count - 1).accessibilityLabel("Move \(exercise.name) down")
                                    }.frame(width: 60)
                                    Button { exercises.removeAll { $0.id == exercise.id } } label: { Image(systemName: "minus.circle") }
                                        .disabled(exercises.count == 1).foregroundStyle(.secondary).frame(width: 22)
                                        .accessibilityLabel("Remove \(exercise.name)")
                                }.buttonStyle(.borderless).padding(.horizontal, 14).padding(.vertical, 13)
                                if index < exercises.count - 1 { Divider().padding(.horizontal, 14) }
                            }
                        }.cardStyle()
                        if candidate == nil {
                            Label("Use 1 to 240 minutes, named exercises, and 1 to 999 reps.", systemImage: "exclamationmark.circle")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.disabled(store.hasUnsavedChange)
                    if updater.isEnabled { UpdateSettingsView(updater: updater) }
                }.padding(28)
            }
            Divider()
            HStack {
                if saved && candidate == store.settings {
                    Label("Changes saved", systemImage: "checkmark.circle").font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    Text("Keep at least one exercise.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Save changes") {
                    if let candidate { saved = store.updateSettings(candidate) }
                }
                .buttonStyle(.borderedProminent).keyboardShortcut("s")
                .disabled(candidate == nil || candidate == store.settings || store.hasUnsavedChange)
                .accessibilityIdentifier("save-settings")
            }.padding(.horizontal, 28).padding(.vertical, 16)
        }.frame(width: 620, height: 620).background(Palette.background)
    }
}
