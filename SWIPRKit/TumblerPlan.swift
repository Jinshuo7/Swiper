import Foundation

/// A persistable, repeat-free random traversal.
///
/// The plan stores only asset identifiers (never images). It is created once
/// from a seed and the current library, then consumed one identifier at a time.
/// `handled` guarantees an asset can never be served twice even if the plan is
/// reconciled against a changed library.
public struct TumblerPlan: Codable, Equatable, Sendable {
    public let seed: UInt64
    public private(set) var remaining: [String]
    public private(set) var handled: Set<String>

    public init(assetIDs: [String], seed: UInt64) {
        self.seed = seed
        var generator = SeededGenerator(seed: seed)
        var ids = assetIDs
        if ids.count > 1 {
            for index in stride(from: ids.count - 1, through: 1, by: -1) {
                let pick = Int(generator.next() % UInt64(index + 1))
                ids.swapAt(index, pick)
            }
        }
        self.remaining = ids
        self.handled = []
    }

    public var isEmpty: Bool { remaining.isEmpty }

    /// Returns the next unseen identifier, or `nil` when the plan is exhausted.
    public mutating func next() -> String? {
        while let id = remaining.popLast() {
            if handled.insert(id).inserted {
                return id
            }
        }
        return nil
    }

    public func peek(limit: Int, availableIDs: Set<String>, excluding excludedIDs: Set<String>) -> [String] {
        guard limit > 0 else { return [] }
        var result: [String] = []
        for id in remaining.reversed()
            where availableIDs.contains(id) && !handled.contains(id) && !excludedIDs.contains(id)
        {
            result.append(id)
            if result.count == limit { break }
        }
        return result
    }

    public mutating func requeue(_ id: String) {
        guard handled.remove(id) != nil, !remaining.contains(id) else { return }
        remaining.append(id)
    }

    /// Drops identifiers that left the library.
    public mutating func reconcile(withAvailableIDs available: Set<String>) {
        remaining.removeAll { !available.contains($0) }
    }
}
