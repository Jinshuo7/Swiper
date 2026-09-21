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
/// and favorite flows without any destructive real-library action. Demo assets
/// deliberately cover landscape, portrait, square and panorama proportions, and
/// every generated image carries high-contrast edge markers so a cropped or
/// offscreen photo is obvious both to a screenshot reviewer and to a pixel
/// assertion.
final class FakePhotoLibrary: SwiperPhotoLibrary {
    /// A real-world proportion an asset can have. `nickname` is only used for
    /// labels and screenshots.
    struct Shape: Equatable, Sendable {
        let pixelWidth: Int
        let pixelHeight: Int
        let nickname: String

        static let landscape = Shape(pixelWidth: 4_032, pixelHeight: 3_024, nickname: "landscape")
        static let portrait = Shape(pixelWidth: 3_024, pixelHeight: 4_032, nickname: "portrait")
        static let square = Shape(pixelWidth: 3_000, pixelHeight: 3_000, nickname: "square")
        static let panorama = Shape(pixelWidth: 8_000, pixelHeight: 2_000, nickname: "panorama")

        /// The order demo assets cycle through, so the first asset of a fresh
        /// UI-test run is always the same landscape photo.
        static let all: [Shape] = [.landscape, .portrait, .square, .panorama]
    }

    /// Injectable failures so app and UI tests can exercise recovery paths
    /// without touching a real library.
    struct Faults: Equatable, Sendable {
        /// `setFavorite` throws for these identifiers.
        var failingFavoriteIDs: Set<String> = []
        /// `deleteAssets` submits these identifiers but leaves them in place,
        /// modelling a partial or cancelled system deletion.
        var failedDeleteIDs: Set<String> = []
        /// `deleteAssets` throws outright for these identifiers.
        var throwingDeleteIDs: Set<String> = []
        /// `setFavorite` never completes while true, so tests can observe the
        /// serialised-saving state.
        var hangsFavoriteWrites = false

        static let none = Faults()
    }

    var changeHandler: (() -> Void)?
    var faults: Faults = .none
    /// Every favorite write that reached the library, in order. App tests use it
    /// to prove a retry never repeats an effect.
    private(set) var favoriteWrites: [(id: String, isFavorite: Bool)] = []

    private var assets: [AssetDescriptor]
    private var favoriteIDs: Set<String>
    private var deletedIDs: Set<String> = []

    init(assets: [AssetDescriptor]) {
        self.assets = assets
        self.favoriteIDs = Set(assets.filter(\.isFavorite).map(\.id))
    }

    // MARK: - Demo fixtures

    /// The descriptors backing ``demo(count:)``. Exposed so app tests can make
    /// assertions about the same fixtures a UI test sees.
    static func demoDescriptors(count: Int = 24) -> [AssetDescriptor] {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        return (0..<count).map { index in
            let shape = Shape.all[index % Shape.all.count]
            return AssetDescriptor(
                id: "fake-\(index)",
                creationDate: base.addingTimeInterval(Double(index) * 3_600),
                pixelWidth: shape.pixelWidth,
                pixelHeight: shape.pixelHeight,
                isFavorite: false,
                kind: index % 5 == 4 ? .livePhoto : .photo
            )
        }
    }

    static func demo(count: Int = 24) -> FakePhotoLibrary {
        FakePhotoLibrary(assets: demoDescriptors(count: count))
    }

    // MARK: - Authorization

    func currentAuthorization() -> LibraryAuthorization { .authorized }
    func requestAuthorization() async -> LibraryAuthorization { .authorized }
    @MainActor func presentLimitedLibraryPicker(from viewController: UIViewController) {}

    // MARK: - PhotoLibraryProviding

    func fetchAllDescriptors() async -> [AssetDescriptor] {
        assets
            .filter { !deletedIDs.contains($0.id) }
            .map { descriptor in
                AssetDescriptor(
                    id: descriptor.id,
                    creationDate: descriptor.creationDate,
                    pixelWidth: descriptor.pixelWidth,
                    pixelHeight: descriptor.pixelHeight,
                    isFavorite: favoriteIDs.contains(descriptor.id),
                    kind: descriptor.kind
                )
            }
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
        if faults.hangsFavoriteWrites {
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
        }
        if faults.failingFavoriteIDs.contains(id) {
            throw CocoaError(.fileWriteUnknown)
        }
        favoriteWrites.append((id: id, isFavorite: isFavorite))
        if isFavorite { favoriteIDs.insert(id) } else { favoriteIDs.remove(id) }
    }

    func deleteAssets(ids: [String]) async throws -> [String] {
        let requested = ids.filter { id in
            assets.contains { $0.id == id } && !deletedIDs.contains(id)
        }
        if !faults.throwingDeleteIDs.isEmpty,
           requested.contains(where: { faults.throwingDeleteIDs.contains($0) }) {
            throw CocoaError(.fileWriteUnknown)
        }
        let submitted = requested
        let actuallyDeleted = submitted.filter { !faults.failedDeleteIDs.contains($0) }
        deletedIDs.formUnion(actuallyDeleted)
        return submitted
    }

    // MARK: - AssetImageProviding

    func displayImage(for id: String, targetSize: CGSize) async -> UIImage? {
        guard let descriptor = assets.first(where: { $0.id == id }) else { return nil }
        return Self.image(for: descriptor, targetSize: targetSize, deleted: deletedIDs.contains(id))
    }

    func thumbnail(for id: String, targetSize: CGSize) async -> UIImage? {
        await displayImage(for: id, targetSize: targetSize)
    }

    func livePhoto(for id: String, targetSize: CGSize) async -> PHLivePhoto? { nil }
    func startCaching(ids: [String], targetSize: CGSize) {}
    func stopCaching(ids: [String], targetSize: CGSize) {}

    // MARK: - Fixture rendering

    /// Renders a stand-in at the asset's own aspect ratio, contained inside
    /// `targetSize` (matching how the viewer requests and displays it).
    ///
    /// The image carries an unmistakable edge: a two-pixel inset border, four
    /// differently coloured corner blocks and a centre label. Cropping any edge
    /// therefore removes a marker that a screenshot review can spot.
    private static func image(for descriptor: AssetDescriptor, targetSize: CGSize, deleted: Bool) -> UIImage? {
        guard !deleted else { return nil }
        let fitted = PhotoLayout.fittedSize(
            forPixelSize: CGSize(width: descriptor.pixelWidth, height: descriptor.pixelHeight),
            in: CGSize(width: max(targetSize.width, 1), height: max(targetSize.height, 1))
        )
        let size = CGSize(width: max(fitted.width, 2), height: max(fitted.height, 2))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let isBright = descriptor.id.utf8.reduce(0) { ($0 &* 31 &+ Int($1)) } % 2 == 0
        let hue = CGFloat(abs(descriptor.id.hashValue % 360)) / 360

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let fill: UIColor = isBright
                ? UIColor(hue: hue, saturation: 0.30, brightness: 0.96, alpha: 1)
                : UIColor(hue: hue, saturation: 0.65, brightness: 0.22, alpha: 1)
            fill.setFill()
            context.fill(rect)

            // Gentle diagonal banding so a stretched or cropped rendering is
            // visible even in a greyscale screenshot.
            let band = UIColor.white.withAlphaComponent(isBright ? 0.10 : 0.06)
            band.setFill()
            let step = max(8, size.height / 6)
            var x = -size.height
            while x < size.width {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + step, y: size.height))
                path.addLine(to: CGPoint(x: x + step + size.height, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                path.close()
                path.fill()
                x += step * 2
            }

            let marker: UIColor = isBright ? .black : .white
            let lineWidth = max(2, min(size.width, size.height) * 0.02)
            marker.setStroke()
            let border = UIBezierPath(rect: rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
            border.lineWidth = lineWidth
            border.stroke()

            // Four distinct corner blocks: cropping any edge loses at least one.
            let cornerSide = max(6, min(size.width, size.height) * 0.12)
            let corners: [(UIColor, CGRect)] = [
                (.systemRed, CGRect(x: 0, y: 0, width: cornerSide, height: cornerSide)),
                (.systemGreen, CGRect(x: size.width - cornerSide, y: 0, width: cornerSide, height: cornerSide)),
                (.systemBlue, CGRect(x: 0, y: size.height - cornerSide, width: cornerSide, height: cornerSide)),
                (.systemYellow, CGRect(x: size.width - cornerSide, y: size.height - cornerSide, width: cornerSide, height: cornerSide)),
            ]
            for (colour, frame) in corners {
                colour.setFill()
                context.fill(frame)
            }

            let label = "\(descriptor.isLivePhoto ? "LIVE " : "")\(descriptor.id)\n\(descriptor.pixelWidth)×\(descriptor.pixelHeight)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: max(11, min(size.width, size.height) / 9), weight: .bold),
                .foregroundColor: marker,
            ]
            let text = label as NSString
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                withAttributes: attributes
            )
        }
    }
}
