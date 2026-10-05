import AppKit
import PrototypeCore
import SwiftUI

/// Developer-only export of the real SwiftUI views, including native AppKit controls.
@MainActor
enum SnapshotExporter {
    static func export(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for appearance in [DemoAppearance.light, .dark] {
            let store = PrototypeStore()
            store.appearance = appearance
            for scenario in DemoScenario.allCases {
                store.showScenario(scenario)
                let name: String
                switch scenario {
                case .countdown: name = "countdown"
                case .paused: name = "paused"
                case .ready: name = "ready"
                case .inProgress: name = "break"
                case .completed: name = "completed"
                case .partial: name = "partial"
                case .skipped: name = "skipped"
                }
                try capture(BreakPanelView(store: store), name: "\(name)-\(appearance.rawValue.lowercased())",
                            appearance: appearance, directory: directory)
            }
            store.resetSamples()
            try capture(SettingsView(store: store), name: "settings-\(appearance.rawValue.lowercased())",
                        appearance: appearance, directory: directory)
            try capture(HistoryView(store: store, selectedID: store.history[1].id),
                        name: "history-\(appearance.rawValue.lowercased())",
                        appearance: appearance, directory: directory)
            try capture(PrototypeControlsView(store: store), name: "controls-\(appearance.rawValue.lowercased())",
                        appearance: appearance, directory: directory)
        }
    }

    private static func capture<V: View>(_ view: V, name: String, appearance: DemoAppearance,
                                         directory: URL) throws {
        let content = view.environment(\.colorScheme, appearance == .dark ? .dark : .light)
            .environment(\.controlActiveState, .key)
            .preferredColorScheme(appearance.colorScheme)
        let hosting = NSHostingView(rootView: content)
        hosting.appearance = NSAppearance(named: appearance == .dark ? .darkAqua : .aqua)
        let size = hosting.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = hosting.appearance
        window.contentView = hosting
        window.setFrameOrigin(NSPoint(x: 40, y: 40))
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        let bounds = hosting.bounds
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: bounds) else {
            throw ExportError.bitmapUnavailable
        }
        hosting.cacheDisplay(in: bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw ExportError.bitmapUnavailable
        }
        try png.write(to: directory.appendingPathComponent("\(name).png"))
        window.orderOut(nil)
    }

    private enum ExportError: Error { case bitmapUnavailable }
}
