import Photos
import SwiperKit
import UIKit

/// The union of everything the app needs from a photo library. The real
/// implementation is ``PhotoKitLibrary``; UI tests and previews use
/// ``FakePhotoLibrary``.
protocol SwiperPhotoLibrary: PhotoLibraryProviding, AssetImageProviding {
    var changeHandler: (() -> Void)? { get set }
    func currentAuthorization() -> LibraryAuthorization
    func requestAuthorization() async -> LibraryAuthorization
    @MainActor func presentLimitedLibraryPicker(from viewController: UIViewController)
}

/// A deterministic, fully in-memory library used by previews and UI tests.
///
/// It never touches the user's real photos, so UI tests can exercise deletion
/// and favorite flows without any destructive real-library action.
final class FakePhotoLibrary: SwiperPhotoLibrary {
    var changeHandler: (() -> Void)?
    private var assets: [AssetDescriptor]
    private var favoriteIDs: Set<String>
    private var deletedIDs: Set<String> = []

    init(assets: [AssetDescriptor]) {
        self.assets = assets
        self.favoriteIDs = Set(assets.filter(\.isFavorite).map(\.id))
    }

    static func demo(count: Int = 24) -> FakePhotoLibrary {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let assets = (0..<count).map { index in
            AssetDescriptor(
                id: "fake-\(index)",
                creationDate: base.addingTimeInterval(Double(index) * 3_600),
                pixelWidth: 4_032,
                pixelHeight: 3_024,
                isFavorite: false,
                kind: index % 6 == 0 ? .livePhoto : .photo
            )
        }
        return FakePhotoLibrary(assets: assets)
    }

    func currentAuthorization() -> LibraryAuthorization { .authorized }
    func requestAuthorization() async -> LibraryAuthorization { .authorized }
    @MainActor func presentLimitedLibraryPicker(from viewController: UIViewController) {}

    func fetchAllDescriptors() async -> [AssetDescriptor] {
        assets.filter { !deletedIDs.contains($0.id) }
    }

    func descriptors(forIDs ids: [String]) async -> [String: AssetDescriptor] {
        var result = [String: AssetDescriptor]()
        for asset in assets where ids.contains(asset.id) {
            result[asset.id] = asset
        }
        return result
    }

    func existingAssetIDs(among ids: [String]) async -> Set<String> {
        Set(assets.map(\.id)).subtracting(deletedIDs).intersection(ids)
    }

    func setFavorite(_ isFavorite: Bool, forID id: String) async throws {
        guard assets.contains(where: { $0.id == id }) && !deletedIDs.contains(id) else {
            throw CocoaError(.fileNoSuchFile)
        }
        if isFavorite { favoriteIDs.insert(id) } else { favoriteIDs.remove(id) }
    }

    func deleteAssets(ids: [String]) async throws -> [String] {
        let submitted = ids.filter { id in
            assets.contains { $0.id == id } && !deletedIDs.contains(id)
        }
        deletedIDs.formUnion(submitted)
        return submitted
    }

    func displayImage(for id: String, targetSize: CGSize) async -> UIImage? {
        Self.image(for: id, size: targetSize, deleted: deletedIDs.contains(id))
    }

    func thumbnail(for id: String, targetSize: CGSize) async -> UIImage? {
        Self.image(for: id, size: targetSize, deleted: deletedIDs.contains(id))
    }

    func livePhoto(for id: String, targetSize: CGSize) async -> PHLivePhoto? { nil }
    func startCaching(ids: [String], targetSize: CGSize) {}
    func stopCaching(ids: [String], targetSize: CGSize) {}

    private static func image(for id: String, size: CGSize, deleted: Bool) -> UIImage? {
        guard !deleted else { return nil }
        let side = max(1, min(size.width, size.height, 600))
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let hue = CGFloat(abs(id.hashValue % 360)) / 360
        return renderer.image { context in
            UIColor(hue: hue, saturation: 0.45, brightness: 0.55, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let text = id as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: max(10, side / 8), weight: .semibold),
                .foregroundColor: UIColor.white,
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(x: (side - textSize.width) / 2, y: (side - textSize.height) / 2),
                withAttributes: attributes
            )
        }
    }
}
