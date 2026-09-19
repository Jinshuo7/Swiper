import Foundation

/// An immutable, index-backed view of the library sorted oldest → newest.
///
/// Shipping a full sort of `AssetDescriptor` values (small structs) is cheap
/// even for very large libraries; decoded images are never part of this type.
public struct LibraryOrder: Equatable, Sendable {
    /// Assets sorted by `creationDate` ascending (oldest first).
    public let assets: [AssetDescriptor]
    private let indexByID: [String: Int]

    public init(_ descriptors: [AssetDescriptor]) {
        let sorted = descriptors.sorted { lhs, rhs in
            let l = lhs.creationDate ?? .distantPast
            let r = rhs.creationDate ?? .distantPast
            if l != r { return l < r }
            return lhs.id < rhs.id
        }
        self.assets = sorted
        var map = [String: Int]()
        map.reserveCapacity(sorted.count)
        for (index, asset) in sorted.enumerated() {
            map[asset.id] = index
        }
        self.indexByID = map
    }

    public static let empty = LibraryOrder([])

    public var count: Int { assets.count }
    public var isEmpty: Bool { assets.isEmpty }
    public var ids: [String] { assets.map(\.id) }
    public var idSet: Set<String> { Set(indexByID.keys) }

    public func index(of id: String) -> Int? { indexByID[id] }

    public func asset(at index: Int) -> AssetDescriptor? {
        assets.indices.contains(index) ? assets[index] : nil
    }

    public func asset(byID id: String) -> AssetDescriptor? {
        guard let index = indexByID[id] else { return nil }
        return assets[index]
    }

    public func contains(id: String) -> Bool { indexByID[id] != nil }

    /// The immediate neighbour in `direction`, or `nil` at the end of the list.
    public func neighborIndex(from index: Int, direction: TraversalDirection) -> Int? {
        let step = direction == .older ? -1 : 1
        let next = index + step
        return assets.indices.contains(next) ? next : nil
    }

    /// Finds the still-present asset closest to `date` in the requested
    /// direction. Used to recover when the persisted current asset was removed
    /// outside Swiper.
    public func nearestIndex(toDate date: Date?, direction: TraversalDirection) -> Int? {
        guard !assets.isEmpty else { return nil }
        guard let date else {
            return direction == .older ? assets.count - 1 : 0
        }
        if direction == .older {
            var best: Int?
            for (index, asset) in assets.enumerated() {
                let candidate = asset.creationDate ?? .distantPast
                if candidate <= date { best = index } else { break }
            }
            return best ?? 0
        } else {
            var best: Int?
            for (index, asset) in assets.enumerated().reversed() {
                let candidate = asset.creationDate ?? .distantPast
                if candidate >= date { best = index } else { break }
            }
            return best ?? (assets.count - 1)
        }
    }
}
