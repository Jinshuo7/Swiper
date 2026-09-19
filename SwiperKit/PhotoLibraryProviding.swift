import Foundation

/// The subset of photo-library operations Swiper's logic needs.
///
/// The real implementation wraps PhotoKit (`PhotoKitLibrary` in the app
/// target); tests use a fake. Deliberately free of UIKit types so the whole
/// framework builds and tests on macOS.
public protocol PhotoLibraryProviding: AnyObject {
    /// Every supported asset currently visible to the app, oldest → newest is
    /// *not* guaranteed here; callers wrap the result in `LibraryOrder`.
    func fetchAllDescriptors() async -> [AssetDescriptor]

    /// Descriptors for a specific set of identifiers. Missing identifiers are
    /// simply absent from the result.
    func descriptors(forIDs ids: [String]) async -> [String: AssetDescriptor]

    /// Which of `ids` still exist, used to confirm a deletion actually happened.
    func existingAssetIDs(among ids: [String]) async -> Set<String>

    /// Sets the Apple Photos favorite flag. Throws if the library rejects it.
    func setFavorite(_ isFavorite: Bool, forID id: String) async throws

    /// Performs the only destructive operation in Swiper. The system presents
    /// its own confirmation before anything is removed.
    /// Returns the identifiers actually submitted to the library for deletion.
    func deleteAssets(ids: [String]) async throws -> [String]
}
