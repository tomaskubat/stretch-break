import Foundation
import Observation
import StretchBreakCore
import UserNotifications

@MainActor
protocol NotificationClient: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws
    func addReminder(id: UUID, exerciseCount: Int) async throws
    func removeReminder(id: UUID)
}

@MainActor
private final class SystemNotificationClient: NotificationClient {
    let center = UNUserNotificationCenter.current()
    func authorizationStatus() async -> UNAuthorizationStatus { await center.notificationSettings().authorizationStatus }
    func requestAuthorization() async throws { _ = try await center.requestAuthorization(options: [.alert, .sound]) }
    func addReminder(id: UUID, exerciseCount: Int) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Time for a movement break"
        content.body = "\(exerciseCount) exercises are ready. Open StretchBreak when you're ready to move."
        content.sound = .default
        try await center.add(UNNotificationRequest(identifier: id.uuidString, content: content, trigger: nil))
    }
    func removeReminder(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        center.removeDeliveredNotifications(withIdentifiers: [id.uuidString])
    }
}

@MainActor @Observable
public final class MacReminders: NSObject, ReminderDelivering, UNUserNotificationCenterDelegate {
    public private(set) var permissionDescription = "Notifications will be requested when this setting is saved."
    @ObservationIgnored public var onOpenBreak: (() -> Void)?
    @ObservationIgnored private let client: any NotificationClient
    @ObservationIgnored private let testing: Bool
    @ObservationIgnored private var sessionID: UUID?
    @ObservationIgnored private var deliveryTask: Task<Void, Never>?

    public convenience init(testing: Bool = false) {
        let client = SystemNotificationClient()
        self.init(client: client, testing: testing)
        client.center.delegate = self
    }

    init(client: any NotificationClient, testing: Bool = false) {
        self.client = client
        self.testing = testing
        super.init()
    }

    @discardableResult
    public func configure(enabled: Bool, requestPermission: Bool) -> Task<Void, Never> {
        Task {
            guard !testing else {
                permissionDescription = "Notifications are disabled in the isolated UI test session."
                return
            }
            var status = await client.authorizationStatus()
            if enabled && requestPermission && status == .notDetermined {
                do { try await client.requestAuthorization() }
                catch { permissionDescription = "Notifications are unavailable. The menu bar will still remind you."; return }
                status = await client.authorizationStatus()
            }
            switch status {
            case .authorized, .provisional: permissionDescription = "Notifications are allowed on this Mac."
            case .denied: permissionDescription = "Notifications are blocked in System Settings. The menu bar will still remind you."
            default: permissionDescription = "macOS will ask for permission to show notifications."
            }
        }
    }

    public func sendReminder(for session: ActiveBreak) {
        guard !testing else { return }
        deliveryTask?.cancel()
        sessionID = session.id
        deliveryTask = Task {
            let status = await client.authorizationStatus()
            guard !Task.isCancelled, sessionID == session.id,
                  status == .authorized || status == .provisional else { return }
            do {
                try await client.addReminder(id: session.id, exerciseCount: session.exercises.count)
                // Cancellation can happen while the system is accepting the request.
                if Task.isCancelled || sessionID != session.id { client.removeReminder(id: session.id) }
            } catch {
                if !Task.isCancelled {
                    permissionDescription = "The notification could not be delivered. Your break is ready in the menu bar."
                }
            }
        }
    }

    public func cancelReminder(id: UUID) {
        guard !testing else { return }
        if sessionID == id {
            sessionID = nil
            deliveryTask?.cancel()
        }
        client.removeReminder(id: id)
    }

    func waitForDelivery() async { await deliveryTask?.value }

    public nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                                   didReceive response: UNNotificationResponse) async {
        await openCurrentBreak()
    }

    // Both the delegate and tests use this path; notification clicks never create a break.
    func openCurrentBreak() { onOpenBreak?() }

    public nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                                   willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
