import Foundation

/// Everything needed to resume an unfinished sorting session. Identifiers only —
/// no images and no PhotoKit objects.
///
/// The deletion list deliberately does **not** live here: it outlives individual
/// sorting sessions and is stored in ``PersistedState/marks``.
public struct PersistedSession: Codable, Equatable, Sendable {
    public var currentAssetID: String?
    /// Last known creation date of the current asset, used to recover
    /// gracefully if that asset was removed outside SWIPR.
    public var currentAssetDate: Date?
    public var direction: TraversalDirection
    public var mode: SessionMode
    public var decidedIDs: [String]
    public var keptIDs: [String]
    public var undoEntries: [UndoEntry]
    public var tumbler: TumblerPlan?
    /// The media categories selected when the session started, or `nil` for a
    /// legacy session that predates persisted filters.
    public var filterCategories: Set<MediaCategory>?
    /// The fixed set of stable library identifiers captured at session
    /// creation, or `nil` for a legacy session that walks the whole library.
    /// An empty array means a captured-but-empty pool.
    public var poolIDs: [String]?
    public var updatedAt: Date
    public var isFinished: Bool

    public init(
        currentAssetID: String? = nil,
        currentAssetDate: Date? = nil,
        direction: TraversalDirection = .older,
        mode: SessionMode = .sequential,
        decidedIDs: [String] = [],
        keptIDs: [String] = [],
        undoEntries: [UndoEntry] = [],
        tumbler: TumblerPlan? = nil,
        filterCategories: Set<MediaCategory>? = nil,
        poolIDs: [String]? = nil,
        updatedAt: Date = Date(),
        isFinished: Bool = false
    ) {
        self.currentAssetID = currentAssetID
        self.currentAssetDate = currentAssetDate
        self.direction = direction
        self.mode = mode
        self.decidedIDs = decidedIDs
        self.keptIDs = keptIDs
        self.undoEntries = undoEntries
        self.tumbler = tumbler
        self.filterCategories = filterCategories
        self.poolIDs = poolIDs
        self.updatedAt = updatedAt
        self.isFinished = isFinished
    }

    /// A session remains resumable until its explicit completion clears the
    /// persisted state.
    public var isResumable: Bool {
        currentAssetID != nil || !decidedIDs.isEmpty || tumbler != nil
    }
}

/// The whole persisted application state: the durable deletion list, the
/// optional sorting session on top of it, and the schema version they were
/// written with.
///
/// Marks and session are stored together on purpose. They are one piece of
/// user intent, so they are written and replaced atomically rather than being
/// committed piecemeal and left incoherent after a crash.
public struct PersistedState: Codable, Equatable, Sendable {
    /// The version this build writes. Bump it whenever the stored shape
    /// changes, and teach ``FileSessionStore`` how to migrate from every older
    /// version.
    ///
    /// Version 4 added the captured session pool and its filter categories.
    /// Version 3 removed favouriting. A version 2 session can therefore contain a
    /// favourite undo entry, which ``UndoEntry/Effect`` still decodes, mapping it
    /// to `.kept` so undoing it only returns to the photo.
    public static let currentSchemaVersion = 4

    public var schemaVersion: Int
    /// The ordered list of assets marked for deletion, oldest mark first.
    public var marks: [String]
    /// The active sorting session, or `nil` when the user is between sessions.
    public var session: PersistedSession?
    public var updatedAt: Date

    public init(
        schemaVersion: Int = PersistedState.currentSchemaVersion,
        marks: [String] = [],
        session: PersistedSession? = nil,
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.marks = marks
        self.session = session
        self.updatedAt = updatedAt
    }

    public var isResumable: Bool { session?.isResumable ?? false }

    /// Whether there is anything at all worth keeping on disk.
    public var isEmpty: Bool { marks.isEmpty && session == nil }
}

/// The outcome of reading persisted state.
///
/// The important distinction is between "the user has no saved work" and "there
/// is saved work this build cannot read": the second must never be silently
/// treated as the first, or an update would erase the user's choices.
public enum SessionLoadResult: Equatable, Sendable {
    /// Nothing has been stored yet.
    case absent
    /// State written by this schema version.
    case loaded(PersistedState)
    /// Older state was upgraded in memory. The caller should persist it to
    /// finish the migration; the previous bytes stay untouched until that write
    /// succeeds.
    case migrated(PersistedState)
    /// Bytes exist but are not readable in any known format. They must be
    /// preserved, not overwritten as an empty session.
    case unreadable(reason: String)
    /// Written by a newer version of SWIPR than this build understands. It
    /// must not be overwritten.
    case unsupportedVersion(found: Int, supported: Int)

    /// The state usable right now, when there is one.
    public var state: PersistedState? {
        switch self {
        case .loaded(let state), .migrated(let state): return state
        case .absent, .unreadable, .unsupportedVersion: return nil
        }
    }

    /// Whether writing over the stored data is currently allowed.
    public var allowsWrites: Bool {
        switch self {
        case .absent, .loaded, .migrated: return true
        case .unreadable, .unsupportedVersion: return false
        }
    }
}

/// Persistence failures a caller must handle, never swallow.
public enum SessionStoreError: Error, Equatable, LocalizedError {
    /// Stored data could not be read, so writing would destroy it. Quarantine
    /// the unreadable data first.
    case stateIsUnreadable
    /// Stored data comes from a newer SWIPR version and must not be replaced.
    case stateIsFromNewerVersion(found: Int, supported: Int)
    /// The write itself failed (disk full, permissions, removal).
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .stateIsUnreadable:
            return "SWIPR could not read your saved progress, so it will not overwrite it."
        case .stateIsFromNewerVersion(let found, let supported):
            return "Your saved progress was written by a newer version of SWIPR (format \(found); this build understands \(supported))."
        case .writeFailed(let reason):
            return "SWIPR could not save your progress: \(reason)"
        }
    }
}

/// Local-only persistence for the deletion list, session progress, statistics
/// and preferences. All data stays on device.
public protocol SessionStoring: AnyObject {
    /// The state as read when this store was created.
    func loadState() -> SessionLoadResult

    /// Persists marks and session together. Throws when the write fails, or when
    /// unreadable or newer-version data is in the way.
    func saveState(_ state: PersistedState) async throws

    /// Removes stored state, for example once a session is explicitly finished
    /// and there is nothing left to resume.
    func clearState() async throws

    /// Moves unreadable stored data aside so it is preserved for the user while
    /// the app can start working again. Returns where it was moved, if anything
    /// was.
    @discardableResult
    func quarantineUnreadableState() throws -> URL?

    func loadStatistics() -> SessionStatistics
    func saveStatistics(_ statistics: SessionStatistics)

    func loadPreferences() -> ControlPreferences
    func savePreferences(_ preferences: ControlPreferences)
}

/// JSON-on-disk implementation.
///
/// * Writes are atomic: a failed or interrupted write leaves the previous file
///   in place, so a partially written file is never observable.
/// * Data this build cannot read is never overwritten. It stays until the
///   caller explicitly quarantines it.
public final class FileSessionStore: SessionStoring, @unchecked Sendable {
    public let directory: URL
    private let fileManager: FileManager
    private let writeQueue = DispatchQueue(label: "SWIPR.session-persistence", qos: .utility)
    private let policyLock = NSLock()
    private var policy: SessionLoadResult

    public init(directory: URL = FileSessionStore.defaultDirectory, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.policy = SessionLoadResult.absent
        self.policy = Self.readState(
            at: directory.appendingPathComponent(File.session.rawValue),
            fileManager: fileManager
        )
    }

    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("SWIPR", isDirectory: true)
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

    // MARK: - State

    public func loadState() -> SessionLoadResult {
        policyLock.withLock { policy }
    }

    public func saveState(_ state: PersistedState) async throws {
        try ensureWritesAllowed()
        let url = url(for: .session)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writeQueue.async {
                do {
                    let data = try JSONEncoder().encode(state)
                    try data.write(to: url, options: .atomic)
                    continuation.resume()
                } catch {
                    continuation.resume(
                        throwing: SessionStoreError.writeFailed(error.localizedDescription)
                    )
                }
            }
        }
        policyLock.withLock { policy = .loaded(state) }
    }

    public func clearState() async throws {
        try ensureWritesAllowed()
        let url = url(for: .session)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writeQueue.async {
                do {
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(
                        throwing: SessionStoreError.writeFailed(error.localizedDescription)
                    )
                }
            }
        }
        policyLock.withLock { policy = .absent }
    }

    @discardableResult
    public func quarantineUnreadableState() throws -> URL? {
        let source = url(for: .session)
        guard fileManager.fileExists(atPath: source.path) else {
            policyLock.withLock { policy = .absent }
            return nil
        }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destination = directory.appendingPathComponent("session-unreadable-\(stamp).json")
        do {
            try fileManager.moveItem(at: source, to: destination)
        } catch {
            throw SessionStoreError.writeFailed(error.localizedDescription)
        }
        policyLock.withLock { policy = .absent }
        return destination
    }

    private func ensureWritesAllowed() throws {
        switch loadState() {
        case .absent, .loaded, .migrated:
            return
        case .unreadable:
            throw SessionStoreError.stateIsUnreadable
        case .unsupportedVersion(let found, let supported):
            throw SessionStoreError.stateIsFromNewerVersion(found: found, supported: supported)
        }
    }

    // MARK: - Statistics and preferences

    public func loadStatistics() -> SessionStatistics { read(SessionStatistics.self, from: .statistics) ?? .empty }
    public func saveStatistics(_ statistics: SessionStatistics) { write(statistics, to: .statistics) }

    public func loadPreferences() -> ControlPreferences { read(ControlPreferences.self, from: .preferences) ?? .default }
    public func savePreferences(_ preferences: ControlPreferences) { write(preferences, to: .preferences) }

    // MARK: - Reading

    /// The unversioned shape written before ``PersistedState`` existed. Kept
    /// only so those files can be migrated rather than discarded.
    private struct LegacyPersistedSession: Decodable {
        var currentAssetID: String?
        var currentAssetDate: Date?
        var direction: TraversalDirection?
        var mode: SessionMode?
        var decidedIDs: [String]?
        var keptIDs: [String]?
        var queueIDs: [String]?
        var undoEntries: [UndoEntry]?
        var tumbler: TumblerPlan?
        var updatedAt: Date?
        var isFinished: Bool?

        func migrated(updatedAt now: Date) -> PersistedState {
            let session = PersistedSession(
                currentAssetID: currentAssetID,
                currentAssetDate: currentAssetDate,
                direction: direction ?? .older,
                mode: mode ?? .sequential,
                decidedIDs: decidedIDs ?? [],
                keptIDs: keptIDs ?? [],
                undoEntries: undoEntries ?? [],
                tumbler: tumbler,
                updatedAt: updatedAt ?? now,
                isFinished: isFinished ?? false
            )
            return PersistedState(
                schemaVersion: PersistedState.currentSchemaVersion,
                marks: queueIDs ?? [],
                session: session,
                updatedAt: updatedAt ?? now
            )
        }
    }

    /// Reads only the version field, so a newer schema is recognised even when
    /// the rest of its shape is unknown to this build.
    private struct SchemaProbe: Decodable {
        var schemaVersion: Int
    }

    static func readState(at url: URL, fileManager: FileManager) -> SessionLoadResult {
        guard fileManager.fileExists(atPath: url.path) else { return .absent }
        guard let data = try? Data(contentsOf: url) else {
            return .unreadable(reason: "the saved file could not be opened")
        }
        let decoder = JSONDecoder()

        if let probe = try? decoder.decode(SchemaProbe.self, from: data) {
            if probe.schemaVersion > PersistedState.currentSchemaVersion {
                return .unsupportedVersion(
                    found: probe.schemaVersion,
                    supported: PersistedState.currentSchemaVersion
                )
            }
            guard let state = try? decoder.decode(PersistedState.self, from: data) else {
                return .unreadable(reason: "the saved file is damaged")
            }
            if probe.schemaVersion < PersistedState.currentSchemaVersion {
                guard backupBeforeMigration(at: url, fileManager: fileManager) else {
                    return .unreadable(reason: "the saved file could not be backed up before migration")
                }
                return .migrated(migrate(state))
            }
            return .loaded(state)
        }

        // No usable `schemaVersion`. A file is the old unversioned shape only
        // when it carries at least one legacy-only key with the right value type
        // and none of the keys the versioned shape owns. A legacy key that is
        // present but null or the wrong type, or a legacy file with nothing to
        // restore, is damaged: reporting it as unreadable keeps it on disk
        // instead of overwriting it with the empty state an all-optional legacy
        // decode would produce.
        let versionedKeys: Set<String> = ["schemaVersion", "marks", "session"]
        guard let object = topLevelObject(in: data),
              Set(object.keys).isDisjoint(with: versionedKeys),
              isValidLegacyShape(object) else {
            return .unreadable(reason: "the saved file is not in a known format")
        }

        guard let legacy = try? decoder.decode(LegacyPersistedSession.self, from: data) else {
            return .unreadable(reason: "the saved file is not in a known format")
        }
        let migrated = legacy.migrated(updatedAt: Date())
        guard hasSomethingToRestore(migrated) else {
            return .unreadable(reason: "the saved file has nothing to restore")
        }
        guard backupBeforeMigration(at: url, fileManager: fileManager) else {
            return .unreadable(reason: "the saved file could not be backed up before migration")
        }
        return .migrated(migrated)
    }

    private static let legacyOnlyKeys: Set<String> = [
        "queueIDs", "decidedIDs", "currentAssetID", "keptIDs", "undoEntries"
    ]

    /// The top-level JSON object, or `nil` when the data is not a JSON object.
    /// Used to tell a real legacy file from damaged or unknown data.
    private static func topLevelObject(in data: Data) -> [String: Any]? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return object as? [String: Any]
    }

    /// True when the object is the old unversioned shape: at least one
    /// legacy-only key is present, and every legacy-only key it does have holds
    /// a non-null value of the expected type. A present-but-null or wrong-typed
    /// legacy key means the file is damaged, not legacy.
    private static func isValidLegacyShape(_ object: [String: Any]) -> Bool {
        var sawLegacyKey = false
        for key in legacyOnlyKeys {
            guard let value = object[key] else { continue }
            sawLegacyKey = true
            if value is NSNull { return false }
            switch key {
            case "queueIDs", "decidedIDs", "keptIDs":
                guard let array = value as? [Any], array.allSatisfy({ $0 is String }) else {
                    return false
                }
            case "currentAssetID":
                guard value is String else { return false }
            case "undoEntries":
                guard value is [Any] else { return false }
            default:
                return false
            }
        }
        return sawLegacyKey
    }

    /// Whether a migrated legacy state carries any work worth keeping: marks, a
    /// current asset, decided IDs or undo entries.
    private static func hasSomethingToRestore(_ state: PersistedState) -> Bool {
        if !state.marks.isEmpty { return true }
        guard let session = state.session else { return false }
        return session.currentAssetID != nil
            || !session.decidedIDs.isEmpty
            || !session.undoEntries.isEmpty
    }

    /// Copies the original file next to itself before a migration overwrites it,
    /// and reports whether the copy succeeded. A failed copy stops the migration
    /// so the original bytes are never lost.
    private static func backupBeforeMigration(at url: URL, fileManager: FileManager) -> Bool {
        let directory = url.deletingLastPathComponent()
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        var destination = directory.appendingPathComponent("session-premigration-\(stamp).json")
        var suffix = 1
        while fileManager.fileExists(atPath: destination.path) {
            destination = directory.appendingPathComponent("session-premigration-\(stamp)-\(suffix).json")
            suffix += 1
        }
        do {
            try fileManager.copyItem(at: url, to: destination)
            return true
        } catch {
            return false
        }
    }

    /// Brings older in-memory state up to the current schema version.
    private static func migrate(_ state: PersistedState) -> PersistedState {
        var migrated = state
        migrated.schemaVersion = PersistedState.currentSchemaVersion
        return migrated
    }
}

/// In-memory store for tests, previews and UI-test runs.
///
/// It can be told to fail saves or to hold unreadable/newer data, so recovery
/// paths are exercised without a real file system.
public final class InMemorySessionStore: SessionStoring {
    /// What the store pretends to find on disk.
    public enum StoredContent {
        case empty
        case state(PersistedState)
        /// State reported as already migrated by the store (as `FileSessionStore`
        /// does after upgrading older bytes in memory).
        case migrated(PersistedState)
        case unreadable
        case unsupportedVersion(found: Int)
    }

    public var content: StoredContent
    /// When true, ``saveState(_:)`` and ``clearState()`` fail until it is reset.
    public var failsWrites = false
    /// When set, exactly that numbered save attempt fails and later ones succeed
    /// again, so a test can watch a real failure turn into a real retry.
    public var failSaveAttempt: Int?
    public private(set) var statistics: SessionStatistics
    public private(set) var preferences: ControlPreferences
    /// Every state that was successfully written, in order.
    public private(set) var savedStates: [PersistedState] = []
    public private(set) var saveAttempts = 0
    public private(set) var quarantined = false

    public init(
        content: StoredContent = .empty,
        statistics: SessionStatistics = .empty,
        preferences: ControlPreferences = .default
    ) {
        self.content = content
        self.statistics = statistics
        self.preferences = preferences
    }

    public convenience init(
        session: PersistedSession?,
        marks: [String] = [],
        statistics: SessionStatistics = .empty,
        preferences: ControlPreferences = .default
    ) {
        if session == nil && marks.isEmpty {
            self.init(content: .empty, statistics: statistics, preferences: preferences)
        } else {
            self.init(
                content: .state(PersistedState(marks: marks, session: session)),
                statistics: statistics,
                preferences: preferences
            )
        }
    }

    public var state: PersistedState? { content.state }

    public func loadState() -> SessionLoadResult {
        switch content {
        case .empty:
            return .absent
        case .state(let state):
            return .loaded(state)
        case .migrated(let state):
            return .migrated(state)
        case .unreadable:
            return .unreadable(reason: "test fixture")
        case .unsupportedVersion(let found):
            return .unsupportedVersion(found: found, supported: PersistedState.currentSchemaVersion)
        }
    }

    public func saveState(_ state: PersistedState) async throws {
        saveAttempts += 1
        if failsWrites || saveAttempts == failSaveAttempt {
            throw SessionStoreError.writeFailed("SWIPR is simulating a full disk.")
        }
        if !loadState().allowsWrites {
            throw SessionStoreError.stateIsUnreadable
        }
        content = .state(state)
        savedStates.append(state)
    }

    public func clearState() async throws {
        if failsWrites {
            throw SessionStoreError.writeFailed("SWIPR is simulating a full disk.")
        }
        content = .empty
    }

    @discardableResult
    public func quarantineUnreadableState() throws -> URL? {
        quarantined = true
        content = .empty
        return URL(fileURLWithPath: "/dev/null/swiper-quarantined")
    }

    public func loadStatistics() -> SessionStatistics { statistics }
    public func saveStatistics(_ statistics: SessionStatistics) { self.statistics = statistics }
    public func loadPreferences() -> ControlPreferences { preferences }
    public func savePreferences(_ preferences: ControlPreferences) { self.preferences = preferences }
}

private extension InMemorySessionStore.StoredContent {
    var state: PersistedState? {
        switch self {
        case .state(let state), .migrated(let state): return state
        case .empty, .unreadable, .unsupportedVersion: return nil
        }
    }
}
