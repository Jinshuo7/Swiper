import Foundation

/// The Home media filter: the set of media categories whose assets enter a
/// session.
///
/// Selection is a plain `Set<MediaCategory>` with three entry presets
/// (`everything`, `photos`, `videos`) and two single-purpose mutations
/// (`toggle`, `selectOnly`). Presets are built fresh each time, so a new
/// session never silently inherits a previous session's exclusions.
///
/// Matching is **exclusion-wins**: an asset that spans several categories (for
/// example a Live Photo screenshot) is included only when every one of its
/// categories is selected, and it is never emitted twice.
public struct MediaFilter: Equatable, Sendable {
    /// The currently selected categories. Mutations go through ``toggle(_:)``
    /// and ``selectOnly(_:)`` so a preset or Only action replaces rather than
    /// layers onto a previous selection.
    public private(set) var categories: Set<MediaCategory>

    public init(categories: Set<MediaCategory>) {
        self.categories = categories
    }

    // MARK: - Presets

    /// Every photo category and Videos.
    public static let everything = MediaFilter(categories: Set(MediaCategory.allCases))
    /// The four photo categories, without Videos.
    public static let photos = MediaFilter(categories: [.screenshot, .livePhoto, .panorama, .otherPhoto])
    /// Only Videos.
    public static let videos = MediaFilter(categories: [.video])
    /// Nothing selected; Continue is disabled and the pool is empty.
    public static let empty = MediaFilter(categories: [])

    public var isEmpty: Bool { categories.isEmpty }

    // MARK: - Selection

    public func contains(_ category: MediaCategory) -> Bool {
        categories.contains(category)
    }

    /// Toggles one category without disturbing the other choices.
    public mutating func toggle(_ category: MediaCategory) {
        if categories.contains(category) {
            categories.remove(category)
        } else {
            categories.insert(category)
        }
    }

    /// Isolates one category, replacing whatever was selected before.
    public mutating func selectOnly(_ category: MediaCategory) {
        categories = [category]
    }

    // MARK: - Matching

    /// Whether an asset enters the pool. An asset whose categories span several
    /// selections is included only when all of them are selected (exclusions
    /// win), which keeps the result deterministic.
    public func includes(_ asset: AssetDescriptor) -> Bool {
        let assetCategories = asset.categories
        guard !assetCategories.isEmpty else { return false }
        return assetCategories.isSubset(of: categories)
    }

    /// The matching assets, still sorted oldest → newest, each once.
    public func apply(to order: LibraryOrder) -> LibraryOrder {
        LibraryOrder(order.assets.filter { includes($0) })
    }

    // MARK: - Summary

    /// A plain name for the current selection, e.g. "Everything" or
    /// "Screenshots, Videos".
    public var selectionName: String {
        if categories == Set(MediaCategory.allCases) { return "Everything" }
        if categories == Self.photos.categories { return "Photos" }
        if categories == Self.videos.categories { return "Videos" }
        if categories.isEmpty { return "Nothing selected" }
        let ordered = MediaCategory.allCases.filter { categories.contains($0) }
        return ordered.map(Self.name(for:)).joined(separator: ", ")
    }

    /// A plain-language pool summary naming the selection and how many assets
    /// match, e.g. "Everything · 24 items".
    public func summary(matchingCount: Int) -> String {
        "\(selectionName) · \(matchingCount) \(matchingCount == 1 ? "item" : "items")"
    }

    private static func name(for category: MediaCategory) -> String {
        switch category {
        case .screenshot: return "Screenshots"
        case .livePhoto: return "Live Photos"
        case .panorama: return "Panoramas"
        case .otherPhoto: return "Other Photos"
        case .video: return "Videos"
        }
    }
}
