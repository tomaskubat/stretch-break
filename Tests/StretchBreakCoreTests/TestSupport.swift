import Foundation
import StretchBreakCore

@MainActor
final class TestClock: TimeSource {
    var now: Date
    init(now: Date = Date(timeIntervalSince1970: 1_800_000_000)) { self.now = now }
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

final class MemoryRepository: StateRepository {
    var data: LoadedData?
    var failSave = false
    var failLoad = false
    var saves = 0
    func load() throws -> LoadedData? {
        if failLoad { throw TestFailure.storage }
        return data
    }
    func save(state: AppState, record: BreakRecord?) throws {
        if failSave { throw TestFailure.storage }
        var history = data?.history ?? []
        if let record { history.insert(record, at: 0) }
        data = LoadedData(state: state, history: history)
        saves += 1
    }
}

enum TestFailure: Error { case storage }

@MainActor
final class ReminderSpy: ReminderDelivering {
    var permissionGranted = true
    var attempts: [UUID] = []
    var delivered: [UUID] = []
    var cancelled: [UUID] = []
    func sendReminder(for session: ActiveBreak) {
        attempts.append(session.id)
        if permissionGranted { delivered.append(session.id) }
    }
    func cancelReminder(id: UUID) { cancelled.append(id) }
}

func temporaryDatabase() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("StretchBreakTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent("StretchBreak.sqlite")
}
