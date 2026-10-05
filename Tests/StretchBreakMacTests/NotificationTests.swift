import Foundation
import StretchBreakCore
import Testing
import UserNotifications
@testable import StretchBreakMac

@MainActor
private final class NotificationStub: NotificationClient {
    var status: UNAuthorizationStatus = .authorized
    var requests = 0
    var added: [UUID] = []
    var removed: [UUID] = []
    var requestFails = false
    var addFails = false
    var beforeStatus: (() -> Void)?
    var beforeAdd: (() -> Void)?
    func authorizationStatus() async -> UNAuthorizationStatus { beforeStatus?(); return status }
    func requestAuthorization() async throws {
        requests += 1
        if requestFails { throw StubError.failed }
        status = .denied
    }
    func addReminder(id: UUID, exerciseCount: Int) async throws {
        beforeAdd?()
        if addFails { throw StubError.failed }
        added.append(id)
    }
    func removeReminder(id: UUID) { removed.append(id) }
    enum StubError: Error { case failed }
}

@Suite @MainActor
struct NotificationTests {
    private func session() -> ActiveBreak { ActiveBreak(started: Date(), definitions: ExerciseDefinition.defaults) }

    @Test func authorizedDeliveryAndClick() async {
        let client = NotificationStub()
        let reminders = MacReminders(client: client)
        var opened = 0
        reminders.onOpenBreak = { opened += 1 }
        let session = session()
        reminders.sendReminder(for: session)
        await reminders.waitForDelivery()
        #expect(client.added == [session.id])
        #expect(opened == 0)
        reminders.openCurrentBreak()
        #expect(opened == 1)
        reminders.cancelReminder(id: session.id)
        #expect(client.removed == [session.id])
    }

    @Test func deniedPermissionDoesNotDeliverOrRequestAgain() async {
        let client = NotificationStub()
        client.status = .denied
        let reminders = MacReminders(client: client)
        await reminders.configure(enabled: true, requestPermission: true).value
        reminders.sendReminder(for: session())
        await reminders.waitForDelivery()
        #expect(client.requests == 0)
        #expect(client.added.isEmpty)
        #expect(reminders.permissionDescription.contains("blocked"))
    }

    @Test func permissionRequestedOnlyWhenEnabledAndExplicit() async {
        let client = NotificationStub()
        client.status = .notDetermined
        let reminders = MacReminders(client: client)
        await reminders.configure(enabled: false, requestPermission: true).value
        await reminders.configure(enabled: true, requestPermission: false).value
        #expect(client.requests == 0)
        await reminders.configure(enabled: true, requestPermission: true).value
        #expect(client.requests == 1)
        #expect(reminders.permissionDescription.contains("blocked"))
    }

    @Test func cancellationWhileCheckingPermissionPreventsDelivery() async {
        let client = NotificationStub()
        let reminders = MacReminders(client: client)
        let session = session()
        client.beforeStatus = { reminders.cancelReminder(id: session.id) }
        reminders.sendReminder(for: session)
        await reminders.waitForDelivery()
        #expect(client.added.isEmpty)
        #expect(client.removed == [session.id])
    }

    @Test func cancellationWhileAddingRemovesLateNotification() async {
        let client = NotificationStub()
        let reminders = MacReminders(client: client)
        let session = session()
        client.beforeAdd = { reminders.cancelReminder(id: session.id) }
        reminders.sendReminder(for: session)
        await reminders.waitForDelivery()
        #expect(client.added == [session.id])
        #expect(client.removed == [session.id, session.id])
    }

    @Test func deliveryAndAuthorizationErrorsAreReported() async {
        let client = NotificationStub()
        let reminders = MacReminders(client: client)
        client.addFails = true
        reminders.sendReminder(for: session())
        await reminders.waitForDelivery()
        #expect(reminders.permissionDescription.contains("could not be delivered"))
        client.status = .notDetermined
        client.requestFails = true
        await reminders.configure(enabled: true, requestPermission: true).value
        #expect(reminders.permissionDescription.contains("unavailable"))
    }
}
