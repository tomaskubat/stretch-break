import Combine
import Sparkle

@MainActor
final class AppUpdater: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var automaticallyDownloadsUpdates = false
    private let controller: SPUStandardUpdaterController?

    init(enabled: Bool) {
        guard enabled else { controller = nil; return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$automaticallyChecksForUpdates)
        controller.updater.publisher(for: \.automaticallyDownloadsUpdates).assign(to: &$automaticallyDownloadsUpdates)
    }

    var isEnabled: Bool { controller != nil }
    func start() { controller?.startUpdater() }
    func checkForUpdates() { controller?.checkForUpdates(nil) }
    func setAutomaticallyChecksForUpdates(_ enabled: Bool) { controller?.updater.automaticallyChecksForUpdates = enabled }
    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) { controller?.updater.automaticallyDownloadsUpdates = enabled }
}
