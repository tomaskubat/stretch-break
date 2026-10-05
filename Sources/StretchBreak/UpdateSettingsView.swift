import SwiftUI

struct UpdateSettingsView: View {
    @ObservedObject var updater: AppUpdater

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Updates").font(.system(size: 14, weight: .semibold))
            Toggle("Automatically check for updates", isOn: Binding(
                get: { updater.automaticallyChecksForUpdates },
                set: { updater.setAutomaticallyChecksForUpdates($0) }
            ))
            Toggle("Automatically download and install updates", isOn: Binding(
                get: { updater.automaticallyDownloadsUpdates },
                set: { updater.setAutomaticallyDownloadsUpdates($0) }
            )).disabled(!updater.automaticallyChecksForUpdates)
            Text("New versions come from GitHub Releases. Your settings and history stay on this Mac.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Check for Updates…") { updater.checkForUpdates() }
                .disabled(!updater.canCheckForUpdates)
                .accessibilityIdentifier("check-for-updates")
        }.padding(18).cardStyle()
    }
}
