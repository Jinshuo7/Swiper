import Foundation

/// The ordered set of assets queued for deletion.
///
/// Queueing is always reversible. Swiper never deletes from this structure;
/// the only destructive call is the final, explicit, system-backed commit in
/// `DeletionReviewViewModel`.
public struct DeletionQueue: Codable, Equatable, Sendable {
    public private(set) var orderedIDs: [String]
    private var idSet: Set<String>

    public static let empty = DeletionQueue()

    public init(orderedIDs: [String] = []) {
        var seen = Set<String>()
        var out = [String]()
        out.reserveCapacity(orderedIDs.count)
        for id in orderedIDs where !seen.contains(id) {
            seen.insert(id)
            out.append(id)
        }
        self.orderedIDs = out
        self.idSet = seen
    }

    public var ids: [String] { orderedIDs }
    public var count: Int { orderedIDs.count }
    public var isEmpty: Bool { orderedIDs.isEmpty }

    public func contains(_ id: String) -> Bool { idSet.contains(id) }

    public mutating func add(_ id: String) {
        guard idSet.insert(id).inserted else { return }
        orderedIDs.append(id)
    }

    public mutating func remove(_ id: String) {
        guard idSet.remove(id) != nil else { return }
        orderedIDs.removeAll { $0 == id }
    }

    public mutating func removeAll() {
        orderedIDs.removeAll()
        idSet.removeAll()
    }

    private enum CodingKeys: String, CodingKey { case orderedIDs }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(orderedIDs: try container.decode([String].self, forKey: .orderedIDs))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(orderedIDs, forKey: .orderedIDs)
    }
}
