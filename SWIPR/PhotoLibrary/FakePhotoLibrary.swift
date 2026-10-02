import Photos
import SWIPRKit
import UIKit

/// The union of everything the app needs from a photo library. The real
/// implementation is ``PhotoKitLibrary``; UI tests and previews use
/// ``FakePhotoLibrary``.
protocol SWIPRPhotoLibrary: PhotoLibraryProviding, AssetImageProviding {
    var changeHandler: (() -> Void)? { get set }
    func currentAuthorization() -> LibraryAuthorization
    func requestAuthorization() async -> LibraryAuthorization
    @MainActor func presentLimitedLibraryPicker(from viewController: UIViewController)
}

/// A deterministic, fully in-memory library used by previews and UI tests.
///
/// It never touches the user's real photos, so UI tests can exercise deletion
/// and deletion flows without any destructive real-library action. Demo assets
/// deliberately cover landscape, portrait, square and panorama proportions, and
/// every generated image carries high-contrast edge markers so a cropped or
/// offscreen photo is obvious both to a screenshot reviewer and to a pixel
/// assertion.
final class FakePhotoLibrary: SWIPRPhotoLibrary {
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
        /// `deleteAssets` submits these identifiers but leaves them in place,
        /// modelling a partial or cancelled system deletion.
        var failedDeleteIDs: Set<String> = []
        /// `deleteAssets` throws outright for these identifiers.
        var throwingDeleteIDs: Set<String> = []

        static let none = Faults()
    }

    var changeHandler: (() -> Void)?
    var faults: Faults = .none

    private var assets: [AssetDescriptor]
    private var deletedIDs: Set<String> = []

    init(assets: [AssetDescriptor]) {
        self.assets = assets
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
                // Spread across months rather than hours, so the start grid has
                // real month sections and a date jump worth testing.
                creationDate: base.addingTimeInterval(Double(index) * 86_400 * 9),
                pixelWidth: shape.pixelWidth,
                pixelHeight: shape.pixelHeight,
                kind: index % 5 == 4 ? .livePhoto : .photo
            )
        }
    }

    static func demo(count: Int = 24) -> FakePhotoLibrary {
        var descriptors = demoDescriptors(count: count)
        if ProcessInfo.processInfo.arguments.contains(mixedMediaLaunchArgument) {
            descriptors.append(contentsOf: kindShowcaseDescriptors())
        }
        return FakePhotoLibrary(assets: descriptors)
    }

    /// The launch argument that adds ``kindShowcaseDescriptors()`` on top of the
    /// ordinary demo library. It is only ever read by the app when a fake
    /// library is already in use (UI tests and previews), so a real library run
    /// can never see it.
    static let mixedMediaLaunchArgument = "-uiTestingMixedMediaLibrary"

    /// Three extra assets placed *newer* than every ``demoDescriptors(count:)``
    /// fixture, newest first: an ordinary photo, a Live Photo, then a video.
    /// "Newest first" therefore opens on the photo and walks straight through
    /// the other two kinds, which is what the all-kinds viewer UI tests need
    /// without disturbing the 24-item fixture those tests count on.
    static func kindShowcaseDescriptors() -> [AssetDescriptor] {
        let newestDemoDate = Date(timeIntervalSince1970: 1_700_000_000)
            .addingTimeInterval(86_400 * 9 * 24)
        return [
            AssetDescriptor(id: "kind-photo", creationDate: newestDemoDate.addingTimeInterval(60), pixelWidth: 4_032, pixelHeight: 3_024, kind: .photo),
            AssetDescriptor(id: "kind-live", creationDate: newestDemoDate.addingTimeInterval(30), pixelWidth: 3_024, pixelHeight: 4_032, kind: .livePhoto),
            AssetDescriptor(id: "kind-video", creationDate: newestDemoDate, pixelWidth: 3_840, pixelHeight: 2_160, kind: .video),
        ]
    }

    /// Additional mixed-media fixtures covering all five categories — Other
    /// Photo, Screenshot, Panorama, Live Photo and Video — plus the overlaps
    /// (a Live Photo that is also a screenshot or a panorama). They are
    /// separate from ``demoDescriptors(count:)``, whose ids, shapes, dates and
    /// kinds stay exactly as they are.
    static func mixedMediaDescriptors() -> [AssetDescriptor] {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let day: TimeInterval = 86_400
        return [
            AssetDescriptor(id: "mixed-other-photo", creationDate: base, pixelWidth: 4_032, pixelHeight: 3_024, kind: .photo),
            AssetDescriptor(id: "mixed-screenshot", creationDate: base.addingTimeInterval(day), pixelWidth: 1_179, pixelHeight: 2_556, kind: .photo, isScreenshot: true),
            AssetDescriptor(id: "mixed-panorama", creationDate: base.addingTimeInterval(day * 2), pixelWidth: 8_000, pixelHeight: 2_000, kind: .photo, isPanorama: true),
            AssetDescriptor(id: "mixed-live-photo", creationDate: base.addingTimeInterval(day * 3), pixelWidth: 4_032, pixelHeight: 3_024, kind: .livePhoto),
            AssetDescriptor(id: "mixed-live-screenshot", creationDate: base.addingTimeInterval(day * 4), pixelWidth: 1_179, pixelHeight: 2_556, kind: .livePhoto, isScreenshot: true),
            AssetDescriptor(id: "mixed-live-panorama", creationDate: base.addingTimeInterval(day * 5), pixelWidth: 8_000, pixelHeight: 2_000, kind: .livePhoto, isPanorama: true),
            AssetDescriptor(id: "mixed-video", creationDate: base.addingTimeInterval(day * 6), pixelWidth: 3_840, pixelHeight: 2_160, kind: .video),
        ]
    }

    static func mixedMedia() -> FakePhotoLibrary {
        FakePhotoLibrary(assets: mixedMediaDescriptors())
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
                    kind: descriptor.kind,
                    isScreenshot: descriptor.isScreenshot,
                    isPanorama: descriptor.isPanorama
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
