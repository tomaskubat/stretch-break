import PrototypeCore
import SwiftUI

struct SettingsView: View {
    @Bindable var store: PrototypeStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeading(title: "Settings", subtitle: "Make room for movement in your day.")
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Break interval").font(.system(size: 13, weight: .medium))
                            Text("Time between movement breaks.").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        TextField("Minutes", value: interval, format: .number.grouping(.never))
                            .textFieldStyle(.roundedBorder).frame(width: 50)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Break interval in minutes")
                        Text("min").foregroundStyle(.secondary)
                        Stepper("Break interval", value: interval, in: 1...240).labelsHidden()
                    }
                    Divider()
                    Toggle(isOn: $store.notificationsEnabled) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("System notifications").font(.system(size: 13, weight: .medium))
                            Text("Show a notification when a break is ready.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .toggleStyle(.switch)
                }
                .padding(18).cardStyle()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Your exercises").font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Button { store.addExercise() } label: { Label("Add exercise", systemImage: "plus") }
                            .accessibilityIdentifier("add-exercise")
                    }
                    Text("Changes apply to your next break.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    VStack(spacing: 0) {
                        HStack {
                            Text("EXERCISE").frame(maxWidth: .infinity, alignment: .leading)
                            Text("REPS").frame(width: 88, alignment: .leading)
                            Text("ORDER").frame(width: 60)
                            Spacer().frame(width: 22)
                        }
                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        Divider()
                        if store.definitions.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "figure.stand").font(.title2).foregroundStyle(.secondary)
                                Text("Add your first exercise").font(.callout)
                                Text("You'll need at least one to start a break.").font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity).padding(24)
                        }
                        ForEach($store.definitions) { $exercise in
                            let index = store.definitions.firstIndex(where: { $0.id == exercise.id }) ?? 0
                            HStack(spacing: 10) {
                                TextField("Exercise name", text: $exercise.name)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("Exercise \(index + 1) name")
                                TextField("Reps", value: $exercise.repetitions, format: .number.grouping(.never))
                                    .textFieldStyle(.roundedBorder).frame(width: 48)
                                    .multilineTextAlignment(.trailing)
                                    .accessibilityLabel("Exercise \(index + 1) planned repetitions")
                                Stepper("Repetitions", value: $exercise.repetitions, in: 1...999)
                                    .labelsHidden().fixedSize()
                                    .accessibilityLabel("Adjust \(exercise.name) planned reps")
                                HStack(spacing: 2) {
                                    Button { store.moveExercise(exercise.id, by: -1) } label: { Image(systemName: "chevron.up") }
                                        .disabled(index == 0).accessibilityLabel("Move \(exercise.name) up")
                                    Button { store.moveExercise(exercise.id, by: 1) } label: { Image(systemName: "chevron.down") }
                                        .disabled(index == store.definitions.count - 1)
                                        .accessibilityLabel("Move \(exercise.name) down")
                                }.frame(width: 60)
                                Button { store.removeExercise(exercise.id) } label: { Image(systemName: "minus.circle") }
                                    .foregroundStyle(.secondary).frame(width: 22)
                                    .accessibilityLabel("Remove \(exercise.name)")
                            }
                            .buttonStyle(.borderless)
                            .padding(.horizontal, 14).padding(.vertical, 13)
                            if index < store.definitions.count - 1 { Divider().padding(.horizontal, 14) }
                        }
                    }.cardStyle()
                    if !store.canStart && !store.definitions.isEmpty {
                        Label("Give each exercise a name and 1 to 999 reps.", systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                    Text("Intervals range from 1 to 240 minutes. The menu bar stays available when notifications are off.")
                }
                .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(28)
        }
        .frame(width: 620, height: 570)
        .background(Palette.background)
    }

    private var interval: Binding<Int> {
        Binding(get: { store.intervalMinutes }, set: { store.changeInterval(to: $0) })
    }
}
