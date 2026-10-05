import AppKit
import StretchBreakCore
import StretchBreakMac
import SwiftUI

@main
@MainActor
struct StretchBreakApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

enum AppDestination: String { case settings, history, about }

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var runtime: AppRuntime?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let identifier = Bundle.main.bundleIdentifier ?? "local.stretchbreak.app"
        if let existing = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existing.activate(options: [.activateAllWindows])
            NSApplication.shared.terminate(nil)
            return
        }
        let runtime = AppRuntime()
        self.runtime = runtime
        runtime.start()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        runtime?.showPanel()
        return false
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let engine = runtime?.engine, engine.hasUnsavedChange else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Your latest change has not been saved"
        alert.informativeText = "Previously recorded results are safe. Retry saving before quitting, or quit without the latest change."
        alert.addButton(withTitle: "Retry saving")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Quit without latest change")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            engine.retrySaving()
            return engine.hasUnsavedChange ? .terminateCancel : .terminateNow
        case .alertThirdButtonReturn: return .terminateNow
        default: return .terminateCancel
        }
    }
    func applicationWillTerminate(_ notification: Notification) { runtime?.stop() }
}

@MainActor
final class AppRuntime: NSObject, NSMenuItemValidation {
    private(set) var engine: BreakEngine?
    private let testDataDirectory: String?
    private var testing: Bool { testDataDirectory != nil || ProcessInfo.processInfo.arguments.contains("--ui-testing") }
    private lazy var updater = AppUpdater(enabled: !testing && Bundle.main.bundleURL.pathExtension == "app")
    private lazy var reminders = MacReminders(testing: testing)
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var host: NSHostingController<AnyView>?
    private var windows: [String: NSWindow] = [:]
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var appearanceObserver: NSKeyValueObservation?
    private var statusAppearanceObserver: NSKeyValueObservation?
    private var statusItemAppearance: NSAppearance.Name?
    private var notificationSetting: Bool?
    private var testClock: AdjustableClock?
    private var dataURL: URL?

    init(statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength),
         testDataDirectory: String? = Bundle.main.object(forInfoDictionaryKey: "StretchBreakUITestDataDirectory") as? String,
         reminders: MacReminders? = nil) {
        self.statusItem = statusItem
        self.testDataDirectory = testDataDirectory
        super.init()
        if let reminders { self.reminders = reminders }
    }

    func start() {
        installMenu()
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePanel)
            button.setAccessibilityIdentifier("stretchbreak-status-item")
            button.setAccessibilityLabel("StretchBreak")
        }
        popover.behavior = .transient
        popover.animates = !testing
        appearanceObserver = NSApplication.shared.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in
                self?.popover.appearance = NSApplication.shared.effectiveAppearance
                self?.updateStatusItem()
            }
        }
        statusAppearanceObserver = statusItem.button?.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in
                guard let self, let button = self.statusItem.button,
                      button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) != self.statusItemAppearance else { return }
                self.updateStatusItem()
            }
        }
        loadData()
        updater.start()
    }

    private func loadData() {
        do {
            let arguments = ProcessInfo.processInfo.arguments
            let url: URL
            if testing {
                let argumentDirectory = arguments.firstIndex(of: "--data-directory").flatMap { index in
                    arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
                }
                guard let directory = testDataDirectory ?? argumentDirectory else {
                    throw SQLiteRepository.StorageError(message: "UI tests require a separate data directory.")
                }
                url = URL(fileURLWithPath: directory, isDirectory: true).appendingPathComponent("StretchBreak.sqlite")
            } else {
                url = try SQLiteRepository.applicationURL()
            }
            dataURL = url
            let clock: any TimeSource
            if testing {
                let adjustable = AdjustableClock()
                testClock = adjustable
                clock = adjustable
            } else { clock = SystemTimeSource() }
            let store = try BreakEngine(repository: SQLiteRepository(url: url), clock: clock, reminders: reminders)
            engine = store
            host = NSHostingController(rootView: AnyView(BreakPanelView(store: store, updater: updater, openWindow: { [weak self] in self?.open($0) })))
            popover.contentViewController = host
            store.onChange = { [weak self] in self?.refresh() }
            reminders.onOpenBreak = { [weak self] in self?.showPanel() }
            refresh()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.engine?.tick()
                    self?.updateStatusItem()
                }
            }
            observeTimeChanges()
            if testing { openTestControls() } else { showPanel() }
        } catch {
            let errorText = error.localizedDescription
            showWindow(id: "error", title: "StretchBreak · Unable to open data", view: AnyView(
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeading(title: "Your data could not be opened", subtitle: "Existing files have not been replaced.")
                    Text(errorText).font(.callout).textSelection(.enabled)
                    HStack {
                        Button("Retry") { [weak self] in self?.windows["error"]?.close(); self?.loadData() }
                        Button("Quit") { NSApplication.shared.terminate(nil) }
                    }
                }.padding(28).frame(width: 480)
            ))
            refresh()
        }
    }

    private func refresh() {
        updateStatusItem()
        if let engine, notificationSetting != engine.notificationsEnabled {
            notificationSetting = engine.notificationsEnabled
            reminders.configure(enabled: engine.notificationsEnabled, requestPermission: true)
        }
        if popover.isShown {
            DispatchQueue.main.async { [weak self] in
                guard let self, let host else { return }
                host.view.layoutSubtreeIfNeeded()
                self.popover.contentSize = host.view.fittingSize
            }
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let appearance = button.effectiveAppearance
        // Record the appearance before assigning the image, which can notify the observer again.
        statusItemAppearance = appearance.bestMatch(from: [.aqua, .darkAqua])
        button.image = MenuBarIcon.image(for: engine, appearance: appearance)
        let hasError = engine?.hasUnsavedChange == true || engine == nil
        let description = hasError ? "StretchBreak: data needs attention" :
            engine?.activeBreak != nil ? "StretchBreak: break ready" :
            engine?.isPaused == true ? "StretchBreak: paused, \(engine?.countdownText ?? "") remaining" :
            "StretchBreak: \(engine?.countdownText ?? "") until next break"
        button.toolTip = description
        button.setAccessibilityLabel(description)
    }

    @objc private func togglePanel() {
        if popover.isShown { popover.performClose(nil) } else { showPanel() }
    }

    func showPanel() {
        guard engine != nil, let button = statusItem.button else { windows["error"]?.makeKeyAndOrderFront(nil); return }
        engine?.tick()
        updateStatusItem()
        popover.appearance = NSApplication.shared.effectiveAppearance
        host?.view.layoutSubtreeIfNeeded()
        if let host { popover.contentSize = host.view.fittingSize }
        NSApplication.shared.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        host?.view.window?.title = "StretchBreak"
        host?.view.window?.makeKey()
    }

    private func open(_ destination: AppDestination) {
        popover.performClose(nil)
        guard let engine else { return }
        let view: AnyView
        switch destination {
        case .settings: view = AnyView(SettingsView(store: engine, reminders: reminders, updater: updater))
        case .history: view = AnyView(HistoryView(store: engine))
        case .about: view = AnyView(AboutView(databaseURL: dataURL))
        }
        showWindow(id: destination.rawValue, title: "StretchBreak · \(destination.rawValue.capitalized)", view: view)
    }

    private func showWindow(id: String, title: String, view: AnyView) {
        if let window = windows[id] {
            window.makeKeyAndOrderFront(nil)
        } else {
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.title = title
            window.setContentSize(controller.view.fittingSize)
            window.center()
            windows[id] = window
            window.makeKeyAndOrderFront(nil)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func observeTimeChanges() {
        let workspace = NSWorkspace.shared.notificationCenter
        for (center, name) in [(workspace, NSWorkspace.didWakeNotification),
                               (NotificationCenter.default, Notification.Name.NSSystemClockDidChange),
                               (NotificationCenter.default, NSApplication.didBecomeActiveNotification)] {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.engine?.tick()
                    self?.updateStatusItem()
                    if let self, let engine = self.engine { self.reminders.configure(enabled: engine.notificationsEnabled, requestPermission: false) }
                }
            }
            observers.append((center, observer))
        }
    }

    func stop() {
        timer?.invalidate()
        for (center, observer) in observers { center.removeObserver(observer) }
        observers.removeAll()
        appearanceObserver = nil
        statusAppearanceObserver = nil
    }

    private func installMenu() {
        let main = NSMenu()
        let item = NSMenuItem()
        let app = NSMenu(title: "StretchBreak")
        func action(_ title: String, _ selector: Selector, _ key: String, modifiers: NSEvent.ModifierFlags = .command) {
            let entry = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            entry.target = self
            entry.keyEquivalentModifierMask = modifiers
            app.addItem(entry)
        }
        action("Show StretchBreak", #selector(showFromMenu), "1")
        action("Settings…", #selector(settingsFromMenu), ",")
        action("History", #selector(historyFromMenu), "h", modifiers: [.command, .shift])
        action("About StretchBreak", #selector(aboutFromMenu), "")
        if updater.isEnabled { action("Check for Updates…", #selector(checkForUpdatesFromMenu), "") }
        app.addItem(.separator())
        let quit = NSMenuItem(title: "Quit StretchBreak", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        app.addItem(quit)
        item.submenu = app
        main.addItem(item)
        let fileItem = NSMenuItem()
        let file = NSMenu(title: "File")
        file.addItem(NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        fileItem.submenu = file
        main.addItem(fileItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        for (title, selector, key) in [("Cut", #selector(NSText.cut(_:)), "x"), ("Copy", #selector(NSText.copy(_:)), "c"),
                                       ("Paste", #selector(NSText.paste(_:)), "v"), ("Select All", #selector(NSText.selectAll(_:)), "a")] {
            edit.addItem(NSMenuItem(title: title, action: selector, keyEquivalent: key))
        }
        editItem.submenu = edit
        main.addItem(editItem)
        NSApplication.shared.mainMenu = main
    }

    @objc private func showFromMenu() { showPanel() }
    @objc private func settingsFromMenu() { open(.settings) }
    @objc private func historyFromMenu() { open(.history) }
    @objc private func aboutFromMenu() { open(.about) }
    @objc private func checkForUpdatesFromMenu() { popover.performClose(nil); updater.checkForUpdates() }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        menuItem.action != #selector(checkForUpdatesFromMenu) || updater.canCheckForUpdates
    }

    private func openTestControls() {
        guard let engine, let testClock else { return }
        showWindow(id: "test-controls", title: "StretchBreak · Isolated UI tests", view: AnyView(
            VStack(alignment: .leading, spacing: 16) {
                SectionHeading(title: "Isolated UI test session", subtitle: "Uses a separate database and controlled time.")
                Text(dataURL?.path ?? "").font(.caption).textSelection(.enabled)
                TimelineView(.periodic(from: .now, by: 1)) { [weak self] _ in
                    HStack(spacing: 12) {
                        if let image = self?.statusItem.button?.image { Image(nsImage: image).frame(width: 24, height: 24) }
                        Text(self?.statusItem.button?.toolTip ?? "").font(.caption)
                    }
                }
                Button("Open menu bar panel") { [weak self] in self?.showPanel() }
                Button("Advance to next break") {
                    testClock.advance(engine.remainingSeconds + 1)
                    engine.tick()
                }
                Button("Advance 10 minutes") { testClock.advance(600); engine.tick() }
                HStack {
                    Button("Light appearance") { NSApplication.shared.appearance = NSAppearance(named: .aqua) }
                    Button("Dark appearance") { NSApplication.shared.appearance = NSAppearance(named: .darkAqua) }
                }
                Text("This window is available only in an isolated test build.").font(.caption).foregroundStyle(.secondary)
            }.padding(28).frame(width: 480)
        ))
    }
}

@MainActor
private final class AdjustableClock: TimeSource {
    private var offset: TimeInterval = 0
    var now: Date { Date().addingTimeInterval(offset) }
    func advance(_ seconds: TimeInterval) { offset += seconds }
}

private struct AboutView: View {
    let databaseURL: URL?
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "StretchBreak", subtitle: "Version \(version) · Movement breaks for your Mac")
            Text("Your settings, history, and current break are stored locally on this Mac.")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            if let databaseURL {
                Text(databaseURL.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Show data in Finder") { NSWorkspace.shared.activateFileViewerSelecting([databaseURL]) }
            }
        }.padding(28).frame(width: 440).background(Palette.background)
    }
}
