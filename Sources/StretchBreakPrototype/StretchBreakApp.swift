import AppKit
import PrototypeCore
import SwiftUI

@main
struct StretchBreakApp: App {
    @NSApplicationDelegateAdaptor(PrototypeAppDelegate.self) private var delegate
    @State private var store = PrototypeStore()

    var body: some Scene {
        Window("StretchBreak · Prototype controls", id: "prototype") {
            PrototypeControlsView(store: store)
                .preferredColorScheme(store.appearance.colorScheme)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) {
                PrototypeWindowCommands()
            }
        }

        MenuBarExtra {
            BreakPanelView(store: store)
                .preferredColorScheme(store.appearance.colorScheme)
        } label: {
            Image(systemName: store.phase == .countdown ? "figure.stand" : "exclamationmark.circle.fill")
                .accessibilityLabel("StretchBreak")
        }
        .menuBarExtraStyle(.window)

        Window("StretchBreak · Panel preview", id: "panel") {
            BreakPanelView(store: store)
                .preferredColorScheme(store.appearance.colorScheme)
        }
        .windowResizability(.contentSize)

        Window("StretchBreak · Settings", id: "settings") {
            SettingsView(store: store)
                .preferredColorScheme(store.appearance.colorScheme)
        }
        .windowResizability(.contentSize)

        Window("StretchBreak · History", id: "history") {
            HistoryView(store: store)
                .preferredColorScheme(store.appearance.colorScheme)
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
final class PrototypeAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--export-previews"), arguments.indices.contains(index + 1) {
            NSApplication.shared.setActivationPolicy(.regular)
            DispatchQueue.main.async {
                do {
                    try SnapshotExporter.export(to: URL(fileURLWithPath: arguments[index + 1]))
                    NSApplication.shared.terminate(nil)
                } catch {
                    FileHandle.standardError.write(Data("Preview export failed: \(error)\n".utf8))
                    exit(1)
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct PrototypeWindowCommands: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Prototype controls") { openWindow(id: "prototype") }
            .keyboardShortcut("0")
        Button("Panel preview") { openWindow(id: "panel") }
            .keyboardShortcut("1")
        Button("Settings…") { openWindow(id: "settings") }
            .keyboardShortcut(",")
        Button("History") { openWindow(id: "history") }
            .keyboardShortcut("h", modifiers: [.command, .shift])
    }
}

extension DemoAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
