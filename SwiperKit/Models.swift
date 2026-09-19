import Foundation

/// The kinds of library items Swiper can present.
///
/// The first version intentionally supports only still images and Live Photos.
/// There is deliberately no `video` case, so ordinary videos can never enter a
/// session, the deletion queue, or any statistic.
public enum MediaKind: String, Codable, CaseIterable, Sendable {
    case photo
    case livePhoto
}

/// A lightweight, `Codable` description of one photo-library asset.
///
/// Swiper persists **descriptors**, never decoded images, so sessions survive
/// relaunches even for very large libraries. `id` is the stable
/// `PHAsset.localIdentifier`, which PhotoKit guarantees across launches for the
/// same library on the same device.
public struct AssetDescriptor: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let creationDate: Date?
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let isFavorite: Bool
    public let kind: MediaKind

    public init(
        id: String,
        creationDate: Date?,
        pixelWidth: Int,
        pixelHeight: Int,
        isFavorite: Bool,
        kind: MediaKind
    ) {
        self.id = id
        self.creationDate = creationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.isFavorite = isFavorite
        self.kind = kind
    }

    /// Estimated on-disk size. See ``StorageEstimate`` for the documented
    /// public-API-only calculation.
    public var estimatedBytes: Int64 {
        StorageEstimate.bytes(width: pixelWidth, height: pixelHeight, kind: kind)
    }

    public var isLivePhoto: Bool { kind == .livePhoto }
}

/// Which way through `creationDate` time the user prefers to browse.
///
/// Swiper defaults to ``older`` so a session keeps moving into the past.
public enum TraversalDirection: String, Codable, CaseIterable, Sendable {
    case older
    case newer

    public var reversed: TraversalDirection { self == .older ? .newer : .older }

    public var title: String { self == .older ? "Older first" : "Newer first" }
}

/// How the next asset is chosen.
public enum SessionMode: String, Codable, Sendable {
    /// Walk the library in `creationDate` order in the preferred direction.
    case sequential
    /// Randomised traversal that never repeats an asset within a session.
    case tumbler
}

/// A decision the user can make about the current asset.
public enum SessionAction: String, Codable, CaseIterable, Sendable {
    /// Queue the photo for deletion. No library mutation happens here.
    case queueDeletion
    /// Keep the photo and advance.
    case keep
    /// Mark the photo as an Apple Photos favorite, keep it, and advance.
    case favorite
    /// Reverse the most recent decision.
    case undo

    public var title: String {
        switch self {
        case .queueDeletion: return "Delete"
        case .keep: return "Keep"
        case .favorite: return "Favorite"
        case .undo: return "Undo"
        }
    }
}

/// A side effect the engine asks the host app to perform against the real
/// photo library. The engine itself never touches PhotoKit, which keeps it
/// pure and unit-testable.
public enum SessionEffect: Equatable, Sendable {
    case setFavorite(id: String, isFavorite: Bool)
    case queuedDeletion(id: String)
    case unqueuedDeletion(id: String)
    case advanced
    case undoApplied(assetID: String)
    case sessionFinished
    case noOp
}
