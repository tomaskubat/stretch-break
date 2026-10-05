import AppKit
import PrototypeCore
import SwiftUI

struct PrototypeControlsView: View {
    @Bindable var store: PrototypeStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "figure.stand").font(.system(size: 40)).foregroundStyle(Palette.accent)
                VStack(alignment: .leading, spacing: 6) {
                    Text("StretchBreak").font(.system(size: 24, weight: .semibold))
                    Text("UI prototype · Phase 0").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Text("Try the menu bar icon above, or open the same panel in a preview window.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Open panel preview") { openWindow(id: "panel") }
                    .buttonStyle(.borderedProminent).keyboardShortcut("1")
                Button("Settings") { openWindow(id: "settings") }
                Button("History") { openWindow(id: "history") }
            }.controlSize(.large)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("Load a sample state").font(.system(size: 13, weight: .semibold))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(DemoScenario.allCases) { scenario in
                        Button {
                            store.showScenario(scenario)
                            openWindow(id: "panel")
                        } label: {
                            HStack {
                                Text(scenario.rawValue)
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                        .accessibilityIdentifier("scenario-\(scenario.id)")
                    }
                }
                Text("Loading a state resets the sample exercises and history.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            HStack {
                Text("Appearance").font(.system(size: 12, weight: .medium))
                Spacer()
                Picker("Appearance", selection: $store.appearance) {
                    ForEach(DemoAppearance.allCases) { appearance in Text(appearance.rawValue).tag(appearance) }
                }
                .labelsHidden().pickerStyle(.segmented).frame(width: 230)
            }
            VStack(alignment: .leading, spacing: 6) {
                Label("Preview only", systemImage: "hammer").font(.system(size: 11, weight: .semibold))
                Text("The countdown is static. Changes stay in memory, and notifications are not sent. Relaunch to restore the samples.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).cardStyle()
            HStack {
                Button("Reset samples") { store.resetSamples() }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
            }.font(.system(size: 11))
        }
        .padding(28).frame(width: 480).background(Palette.background)
    }
}
