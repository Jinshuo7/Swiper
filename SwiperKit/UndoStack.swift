import Foundation

/// One reversible decision, recorded so ``UndoStack`` can reverse it exactly.
public struct UndoEntry: Codable, Equatable, Sendable {
    public enum Effect: Codable, Equatable, Sendable {
        /// The asset was added to the deletion queue.
        case queuedDeletion
        /// The asset was kept (no library mutation).
        case kept
        /// The asset was favorited; `previousValue` restores the prior state.
        case favorited(previousValue: Bool)
    }

    public let assetID: String
    public let effect: Effect
    public let displacedAssetID: String?

    public init(assetID: String, effect: Effect, displacedAssetID: String? = nil) {
        self.assetID = assetID
        self.effect = effect
        self.displacedAssetID = displacedAssetID
    }
}

/// A bounded LIFO history of decisions.
public struct UndoStack: Codable, Equatable, Sendable {
    public private(set) var entries: [UndoEntry]
    /// Oldest entries are dropped once this depth is exceeded, so a very long
    /// session cannot grow the persisted state without bound.
    public let capacity: Int

    public static let empty = UndoStack()

    public init(entries: [UndoEntry] = [], capacity: Int = 1_000) {
        self.capacity = max(1, capacity)
        self.entries = Array(entries.suffix(max(1, capacity)))
    }

    public var canUndo: Bool { !entries.isEmpty }
    public var count: Int { entries.count }
    public var last: UndoEntry? { entries.last }

    public mutating func push(_ entry: UndoEntry) {
        entries.append(entry)
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }

    public mutating func pop() -> UndoEntry? {
        entries.popLast()
    }

    public mutating func removeAll() {
        entries.removeAll()
    }

    public mutating func removeEntries(forAssetIDs ids: [String]) {
        let set = Set(ids)
        entries.removeAll { set.contains($0.assetID) }
    }
}
