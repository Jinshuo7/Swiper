import Photos
import PhotosUI
import SwiperKit
import UIKit

/// The real PhotoKit-backed library.
///
/// Design notes:
/// * Every fetch is metadata-only; full-resolution images are requested on
///   demand and cancelled when the viewer moves on.
/// * Only photos and Live Photos are fetched. The predicate excludes
///   `PHAssetMediaType.video`, matching the product decision to leave ordinary
///   videos out of the first version.
/// * Deletion is the only destructive call and PhotoKit presents the system's
///   own confirmation before anything is removed.
final class PhotoKitLibrary: NSObject, SwiperPhotoLibrary, PHPhotoLibraryChangeObserver {
    private let imageManager = PHCachingImageManager()

    /// Called on the main queue whenever the library changes underneath us.
    var changeHandler: (() -> Void)?

    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    // MARK: - Authorization

    func currentAuthorization() -> LibraryAuthorization {
        LibraryAuthorization(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAuthorization() async -> LibraryAuthorization {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return LibraryAuthorization(status)
    }

    @MainActor
    func presentLimitedLibraryPicker(from viewController: UIViewController) {
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
    }

    // MARK: - PhotoLibraryProviding

    func fetchAllDescriptors() async -> [AssetDescriptor] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let result = PHAsset.fetchAssets(with: options)
        var descriptors = [AssetDescriptor]()
        descriptors.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            descriptors.append(PhotoKitLibrary.descriptor(from: asset))
        }
        return descriptors
    }

    func descriptors(forIDs ids: [String]) async -> [String: AssetDescriptor] {
        let assets = self.assets(withIDs: ids)
        var result = [String: AssetDescriptor]()
        for asset in assets {
            result[asset.localIdentifier] = PhotoKitLibrary.descriptor(from: asset)
        }
        return result
    }

    func existingAssetIDs(among ids: [String]) async -> Set<String> {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var existing = Set<String>()
        result.enumerateObjects { asset, _, _ in
            existing.insert(asset.localIdentifier)
        }
        return existing
    }

    func setFavorite(_ isFavorite: Bool, forID id: String) async throws {
        guard let asset = asset(withID: id) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = isFavorite
        }
    }

    func deleteAssets(ids: [String]) async throws -> [String] {
        let assets = self.assets(withIDs: ids)
        guard !assets.isEmpty else { return [] }
        let submittedIDs = assets.map(\.localIdentifier)
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }
        return submittedIDs
    }

    // MARK: - AssetImageProviding

    func displayImage(for id: String, targetSize: CGSize) async -> UIImage? {
        guard let asset = asset(withID: id) else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return await requestImage(asset: asset, targetSize: targetSize, options: options)
    }

    func thumbnail(for id: String, targetSize: CGSize) async -> UIImage? {
        guard let asset = asset(withID: id) else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return await requestImage(asset: asset, targetSize: targetSize, options: options)
    }

    func livePhoto(for id: String, targetSize: CGSize) async -> PHLivePhoto? {
        guard let asset = asset(withID: id) else { return nil }
        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        let bridge = AsyncRequestBridge<PHLivePhoto>()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                bridge.attach(continuation: continuation, manager: imageManager)
                let requestID = imageManager.requestLivePhoto(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFit,
                    options: options
                ) { livePhoto, info in
                    if info?[PHImageCancelledKey] as? Bool == true {
                        bridge.resolve(nil)
                    } else if info?[PHImageErrorKey] != nil {
                        bridge.resolve(nil)
                    } else {
                        bridge.resolve(livePhoto)
                    }
                }
                bridge.setRequestID(requestID)
            }
        } onCancel: {
            bridge.cancel()
        }
    }

    func startCaching(ids: [String], targetSize: CGSize) {
        let assets = self.assets(withIDs: ids)
        guard !assets.isEmpty else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        imageManager.startCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFit, options: options)
    }

    func stopCaching(ids: [String], targetSize: CGSize) {
        let assets = self.assets(withIDs: ids)
        guard !assets.isEmpty else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        imageManager.stopCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFit, options: options)
    }

    // MARK: - Change observation

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [weak self] in
            self?.changeHandler?()
        }
    }

    // MARK: - Helpers

    private func requestImage(asset: PHAsset, targetSize: CGSize, options: PHImageRequestOptions) async -> UIImage? {
        let bridge = AsyncRequestBridge<UIImage>()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                bridge.attach(continuation: continuation, manager: imageManager)
                let requestID = imageManager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFit,
                    options: options
                ) { image, info in
                    if info?[PHImageCancelledKey] as? Bool == true {
                        bridge.resolve(nil)
                    } else if info?[PHImageErrorKey] != nil {
                        bridge.resolve(nil)
                    } else {
                        bridge.resolve(image)
                    }
                }
                bridge.setRequestID(requestID)
            }
        } onCancel: {
            bridge.cancel()
        }
    }

    private func asset(withID id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }

    private func assets(withIDs ids: [String]) -> [PHAsset] {
        guard !ids.isEmpty else { return [] }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var assets = [PHAsset]()
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    static func descriptor(from asset: PHAsset) -> AssetDescriptor {
        let kind: MediaKind = asset.mediaSubtypes.contains(.photoLive) ? .livePhoto : .photo
        return AssetDescriptor(
            id: asset.localIdentifier,
            creationDate: asset.creationDate,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            isFavorite: asset.isFavorite,
            kind: kind
        )
    }
}
