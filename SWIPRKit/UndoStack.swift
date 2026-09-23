import Foundation

/// One reversible decision, recorded so ``UndoStack`` can reverse it exactly.
public struct UndoEntry: Codable, Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        /// The asset was added to the deletion queue.
        case queuedDeletion
        /// The asset was kept (no library mutation).
        case kept
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

extension UndoEntry.Effect: Codable {
    private enum CodingKeys: String, CodingKey {
        case queuedDeletion
        case kept
        /// Written by schema version 2, which could record a favourite. The key
        /// is here to read those sessions; nothing writes it.
        case favorited
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.queuedDeletion) {
            self = .queuedDeletion
        } else if container.contains(.kept) {
            self = .kept
        } else if container.contains(.favorited) {
            // SWIPR no longer favourites, so undoing a stored favourite only
            // returns to the photo, which is exactly what `.kept` reverses to.
            self = .kept
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown undo effect"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .queuedDeletion:
            try container.encode([String: String](), forKey: .queuedDeletion)
        case .kept:
            try container.encode([String: String](), forKey: .kept)
        }
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
