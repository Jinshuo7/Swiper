import Foundation

/// Everything needed to resume an unfinished session. Identifiers only — no
/// images and no PhotoKit objects.
public struct PersistedSession: Codable, Equatable, Sendable {
    public var currentAssetID: String?
    /// Last known creation date of the current asset, used to recover
    /// gracefully if that asset was removed outside Swiper.
    public var currentAssetDate: Date?
    public var direction: TraversalDirection
    public var mode: SessionMode
    public var decidedIDs: [String]
    public var keptIDs: [String]
    public var queueIDs: [String]
    public var undoEntries: [UndoEntry]
    public var tumbler: TumblerPlan?
    public var updatedAt: Date
    public var isFinished: Bool

    public init(
        currentAssetID: String? = nil,
        currentAssetDate: Date? = nil,
        direction: TraversalDirection = .older,
        mode: SessionMode = .sequential,
        decidedIDs: [String] = [],
        keptIDs: [String] = [],
        queueIDs: [String] = [],
        undoEntries: [UndoEntry] = [],
        tumbler: TumblerPlan? = nil,
        updatedAt: Date = Date(),
        isFinished: Bool = false
    ) {
        self.currentAssetID = currentAssetID
        self.currentAssetDate = currentAssetDate
        self.direction = direction
        self.mode = mode
        self.decidedIDs = decidedIDs
        self.keptIDs = keptIDs
        self.queueIDs = queueIDs
        self.undoEntries = undoEntries
        self.tumbler = tumbler
        self.updatedAt = updatedAt
        self.isFinished = isFinished
    }

    /// A session remains resumable until its explicit completion clears the
    /// persisted state.
    public var isResumable: Bool {
        currentAssetID != nil || !decidedIDs.isEmpty || !queueIDs.isEmpty || tumbler != nil
    }
}

/// Local-only persistence for session progress, the deletion queue,
/// statistics and preferences. All data stays on device.
public protocol SessionStoring: AnyObject {
    func loadSession() -> PersistedSession?
    func saveSession(_ session: PersistedSession)
    func clearSession()

    func loadStatistics() -> SessionStatistics
    func saveStatistics(_ statistics: SessionStatistics)

    func loadPreferences() -> ControlPreferences
    func savePreferences(_ preferences: ControlPreferences)

    func flushSessionWrites()
}

/// JSON-on-disk implementation. Writes are atomic; failures are non-fatal
/// (persistence should never take the app down).
public final class FileSessionStore: SessionStoring, @unchecked Sendable {
    public let directory: URL
    private let fileManager: FileManager
    private let sessionWriteQueue = DispatchQueue(label: "Swiper.session-persistence", qos: .utility)
    private let pendingSessionLock = NSLock()
    private var pendingSessionWrite: SessionWrite?
    private var isSessionWriteScheduled = false

    private enum SessionWrite: Sendable {
        case save(PersistedSession)
        case clear
    }

    public init(directory: URL = FileSessionStore.defaultDirectory, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Swiper", isDirectory: true)
    }

    private enum File: String {
        case session = "session.json"
        case statistics = "statistics.json"
        case preferences = "preferences.json"
    }

    private func url(for file: File) -> URL {
        directory.appendingPathComponent(file.rawValue)
    }

    private func read<T: Decodable>(_ type: T.Type, from file: File) -> T? {
        guard let data = try? Data(contentsOf: url(for: file)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, to file: File) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url(for: file), options: .atomic)
    }

    public func loadSession() -> PersistedSession? {
        flushSessionWrites()
        return read(PersistedSession.self, from: .session)
    }

    public func saveSession(_ session: PersistedSession) { enqueue(.save(session)) }
    public func clearSession() { enqueue(.clear) }

    public func loadStatistics() -> SessionStatistics { read(SessionStatistics.self, from: .statistics) ?? .empty }
    public func saveStatistics(_ statistics: SessionStatistics) { write(statistics, to: .statistics) }

    public func loadPreferences() -> ControlPreferences { read(ControlPreferences.self, from: .preferences) ?? .default }
    public func savePreferences(_ preferences: ControlPreferences) { write(preferences, to: .preferences) }

    public func flushSessionWrites() {
        sessionWriteQueue.sync {}
    }

    private func enqueue(_ write: SessionWrite) {
        pendingSessionLock.lock()
        pendingSessionWrite = write
        let shouldSchedule = !isSessionWriteScheduled
        isSessionWriteScheduled = true
        pendingSessionLock.unlock()

        if shouldSchedule {
            sessionWriteQueue.async { [weak self] in
                self?.drainSessionWrites()
            }
        }
    }

    private func drainSessionWrites() {
        while true {
            pendingSessionLock.lock()
            guard let pendingSessionWrite else {
                isSessionWriteScheduled = false
                pendingSessionLock.unlock()
                return
            }
            self.pendingSessionWrite = nil
            pendingSessionLock.unlock()

            switch pendingSessionWrite {
            case .save(let session):
                write(session, to: .session)
            case .clear:
                try? fileManager.removeItem(at: url(for: .session))
            }
        }
    }
}

/// In-memory store for tests, previews and UI-test runs.
public final class InMemorySessionStore: SessionStoring {
    public private(set) var session: PersistedSession?
    public private(set) var statistics: SessionStatistics
    public private(set) var preferences: ControlPreferences

    public init(
        session: PersistedSession? = nil,
        statistics: SessionStatistics = .empty,
        preferences: ControlPreferences = .default
    ) {
        self.session = session
        self.statistics = statistics
        self.preferences = preferences
    }

    public func loadSession() -> PersistedSession? { session }
    public func saveSession(_ session: PersistedSession) { self.session = session }
    public func clearSession() { session = nil }
    public func loadStatistics() -> SessionStatistics { statistics }
    public func saveStatistics(_ statistics: SessionStatistics) { self.statistics = statistics }
    public func loadPreferences() -> ControlPreferences { preferences }
    public func savePreferences(_ preferences: ControlPreferences) { self.preferences = preferences }
    public func flushSessionWrites() {}
}
