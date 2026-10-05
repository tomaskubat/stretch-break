import Foundation

@MainActor
public protocol TimeSource: AnyObject {
    var now: Date { get }
}

@MainActor
public final class SystemTimeSource: TimeSource {
    public init() {}
    public var now: Date { Date() }
}

public protocol StateRepository: AnyObject {
    func load() throws -> LoadedData?
    func save(state: AppState, record: BreakRecord?) throws
}

@MainActor
public protocol ReminderDelivering: AnyObject {
    func sendReminder(for session: ActiveBreak)
    func cancelReminder(id: UUID)
}

@MainActor
public final class SilentReminders: ReminderDelivering {
    public init() {}
    public func sendReminder(for session: ActiveBreak) {}
    public func cancelReminder(id: UUID) {}
}
