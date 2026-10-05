import CSQLite
import Foundation

public final class SQLiteRepository: StateRepository {
    public let url: URL
    private var database: OpaquePointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public static func applicationURL() throws -> URL {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        return support.appendingPathComponent("StretchBreak", isDirectory: true)
            .appendingPathComponent("StretchBreak.sqlite")
    }

    public init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let result = sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
        guard result == SQLITE_OK else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Could not open the database."
            if let database { sqlite3_close(database) }
            database = nil
            throw StorageError(message: message)
        }
        do {
            sqlite3_busy_timeout(database, 1000)
            try execute("PRAGMA journal_mode = DELETE")
            try execute("PRAGMA synchronous = EXTRA")
            try execute("CREATE TABLE IF NOT EXISTS app_state (id INTEGER PRIMARY KEY CHECK (id = 1), payload BLOB NOT NULL)")
            try execute("CREATE TABLE IF NOT EXISTS history (sequence INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL UNIQUE, payload BLOB NOT NULL)")
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            sqlite3_close(database)
            database = nil
            throw error
        }
    }

    deinit { if let database { sqlite3_close(database) } }

    public func load() throws -> LoadedData? {
        let states = try blobs("SELECT payload FROM app_state WHERE id = 1")
        let records = try blobs("SELECT payload FROM history ORDER BY sequence DESC")
        guard let payload = states.first else {
            guard records.isEmpty else { throw StorageError(message: "The saved state is missing. Existing history has been preserved.") }
            return nil
        }
        let state = try decoder.decode(AppState.self, from: payload)
        let history = try records.map { try decoder.decode(BreakRecord.self, from: $0) }
        guard state.isValid, history.allSatisfy(\.isValid) else {
            throw BreakEngine.EngineError.invalidStoredData
        }
        return LoadedData(state: state, history: history)
    }

    public func save(state: AppState, record: BreakRecord?) throws {
        guard state.isValid, record?.isValid != false else { throw BreakEngine.EngineError.invalidStoredData }
        let stateData = try encoder.encode(state)
        let recordData = try record.map(encoder.encode)
        try execute("BEGIN IMMEDIATE")
        do {
            try write("INSERT INTO app_state(id, payload) VALUES (1, ?) ON CONFLICT(id) DO UPDATE SET payload = excluded.payload", data: stateData)
            if let record, let recordData {
                try write("INSERT INTO history(id, payload) VALUES (?, ?)", data: recordData, id: record.id.uuidString)
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else { throw currentError() }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw currentError() }
        return statement
    }

    private func write(_ sql: String, data: Data, id: String? = nil) throws {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if let id {
            guard sqlite3_bind_text(statement, 1, id, -1, transient) == SQLITE_OK else { throw currentError() }
        }
        let binding = data.withUnsafeBytes {
            sqlite3_bind_blob(statement, id == nil ? 1 : 2, $0.baseAddress, Int32($0.count), transient)
        }
        guard binding == SQLITE_OK, sqlite3_step(statement) == SQLITE_DONE else { throw currentError() }
    }

    private func blobs(_ sql: String) throws -> [Data] {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        var data: [Data] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                guard let bytes = sqlite3_column_blob(statement, 0) else { throw StorageError(message: "A saved record is empty.") }
                data.append(Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0))))
            case SQLITE_DONE: return data
            default: throw currentError()
            }
        }
    }

    private func currentError() -> StorageError {
        StorageError(message: database.map { String(cString: sqlite3_errmsg($0)) } ?? "The database is closed.")
    }

    public struct StorageError: LocalizedError {
        public let message: String
        public init(message: String) { self.message = message }
        public var errorDescription: String? { message }
    }
}
