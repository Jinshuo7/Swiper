import Foundation

/// The kinds of library items SWIPR can represent.
///
/// `video` covers ordinary videos (not Live Photo motion clips). Ordinary
/// videos are represented so later milestones can filter and play them; whether
/// one enters a session is a filtering decision, not a property of this type.
public enum MediaKind: String, Codable, CaseIterable, Sendable {
    case photo
    case livePhoto
    case video
}

/// The five top-level media buckets the Home filter presents.
///
/// A single asset can belong to more than one category (for example a Live
/// Photo that is also a screenshot), so classification is expressed as a set
/// rather than a single value. Later exclusion-wins filtering can then resolve
/// which bucket wins without losing the overlap.
public enum MediaCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case screenshot
    case livePhoto
    case panorama
    case otherPhoto
    case video
}

/// A lightweight, `Codable` description of one photo-library asset.
///
/// SWIPR persists **descriptors**, never decoded images, so sessions survive
/// relaunches even for very large libraries. `id` is the stable
/// `PHAsset.localIdentifier`, which PhotoKit guarantees across launches for the
/// same library on the same device.
public struct AssetDescriptor: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let creationDate: Date?
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let kind: MediaKind
    /// Whether PhotoKit reports this asset as a screenshot
    /// (`PHAssetMediaSubtype.photoScreenshot`). A Live Photo can also be a
    /// screenshot, so this overlaps `isLivePhoto`.
    public let isScreenshot: Bool
    /// Whether PhotoKit reports this asset as a panorama
    /// (`PHAssetMediaSubtype.photoPanorama`).
    public let isPanorama: Bool

    public init(
        id: String,
        creationDate: Date?,
        pixelWidth: Int,
        pixelHeight: Int,
        kind: MediaKind,
        isScreenshot: Bool = false,
        isPanorama: Bool = false
    ) {
        self.id = id
        self.creationDate = creationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.kind = kind
        self.isScreenshot = isScreenshot
        self.isPanorama = isPanorama
    }

    /// Estimated on-disk size. See ``StorageEstimate`` for the documented
    /// public-API-only calculation.
    public var estimatedBytes: Int64 {
        StorageEstimate.bytes(width: pixelWidth, height: pixelHeight, kind: kind)
    }

    public var isLivePhoto: Bool { kind == .livePhoto }

    /// Whether this is an ordinary video (not a Live Photo motion clip).
    public var isVideo: Bool { kind == .video }

    /// The media categories this asset belongs to.
    ///
    /// Overlaps are retained: a Live Photo screenshot appears in both `.livePhoto`
    /// and `.screenshot`, so later exclusion-wins filtering can still decide which
    /// bucket wins. A photo with no distinguishing subtype is `.otherPhoto`, and
    /// an ordinary video is `.video`.
    public var categories: Set<MediaCategory> {
        if isVideo { return [.video] }
        var result: Set<MediaCategory> = []
        if isLivePhoto { result.insert(.livePhoto) }
        if isScreenshot { result.insert(.screenshot) }
        if isPanorama { result.insert(.panorama) }
        if result.isEmpty { result.insert(.otherPhoto) }
        return result
    }

    /// Width ÷ height in pixels. Used to contain the asset at its original
    /// aspect ratio; see ``PhotoLayout``.
    public var aspectRatio: CGFloat {
        guard pixelWidth > 0, pixelHeight > 0 else { return 1 }
        return CGFloat(pixelWidth) / CGFloat(pixelHeight)
    }
}

/// Which way through `creationDate` time the user prefers to browse.
///
/// SWIPR defaults to ``older`` so a session keeps moving into the past.
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
    /// Reverse the most recent decision.
    case undo

    public var title: String {
        switch self {
        case .queueDeletion: return "Delete"
        case .keep: return "Keep"
        case .undo: return "Undo"
        }
    }
}

/// A side effect the engine asks the host app to perform against the real
/// photo library. The engine itself never touches PhotoKit, which keeps it
/// pure and unit-testable.
public enum SessionEffect: Equatable, Sendable {
    case queuedDeletion(id: String)
    case unqueuedDeletion(id: String)
    case advanced
    case undoApplied(assetID: String)
    case sessionFinished
    case noOp
}
