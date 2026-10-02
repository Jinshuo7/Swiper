import XCTest
@testable import SWIPRKit

final class MediaClassificationTests: XCTestCase {
    private func descriptor(
        kind: MediaKind,
        isScreenshot: Bool = false,
        isPanorama: Bool = false
    ) -> AssetDescriptor {
        AssetDescriptor(
            id: "asset",
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            pixelWidth: 4_032,
            pixelHeight: 3_024,
            kind: kind,
            isScreenshot: isScreenshot,
            isPanorama: isPanorama
        )
    }

    func testMediaKindCoversPhotoLivePhotoAndVideo() {
        XCTAssertEqual(MediaKind.allCases, [.photo, .livePhoto, .video])
    }

    func testCategoryEnumCoversAllFiveBuckets() {
        XCTAssertEqual(
            Set(MediaCategory.allCases),
            [.screenshot, .livePhoto, .panorama, .otherPhoto, .video]
        )
    }

    func testMediaCategoryRoundTripsThroughJSON() throws {
        // MediaCategory is Codable so later MediaFilter and persisted filter
        // selections can store it. Every case must survive an encode/decode
        // round-trip with its identity intact.
        let all = MediaCategory.allCases
        let data = try JSONEncoder().encode(all)
        let decoded = try JSONDecoder().decode([MediaCategory].self, from: data)
        XCTAssertEqual(decoded, all)
        XCTAssertEqual(
            Set(decoded),
            [.screenshot, .livePhoto, .panorama, .otherPhoto, .video]
        )
    }

    func testPlainPhotoIsOnlyOtherPhoto() {
        XCTAssertEqual(descriptor(kind: .photo).categories, [.otherPhoto])
    }

    func testScreenshotIsScreenshot() {
        XCTAssertEqual(descriptor(kind: .photo, isScreenshot: true).categories, [.screenshot])
    }

    func testPanoramaIsPanorama() {
        XCTAssertEqual(descriptor(kind: .photo, isPanorama: true).categories, [.panorama])
    }

    func testLivePhotoIsLivePhoto() {
        XCTAssertEqual(descriptor(kind: .livePhoto).categories, [.livePhoto])
    }

    func testVideoIsVideo() {
        XCTAssertEqual(descriptor(kind: .video).categories, [.video])
    }

    func testLivePhotoScreenshotRetainsBothCategories() {
        XCTAssertEqual(
            descriptor(kind: .livePhoto, isScreenshot: true).categories,
            [.livePhoto, .screenshot]
        )
    }

    func testLivePhotoPanoramaRetainsBothCategories() {
        XCTAssertEqual(
            descriptor(kind: .livePhoto, isPanorama: true).categories,
            [.livePhoto, .panorama]
        )
    }

    func testDefaultFlagsAreFalse() {
        let asset = AssetDescriptor(
            id: "plain",
            creationDate: nil,
            pixelWidth: 1,
            pixelHeight: 1,
            kind: .photo
        )
        XCTAssertFalse(asset.isScreenshot)
        XCTAssertFalse(asset.isPanorama)
        XCTAssertFalse(asset.isLivePhoto)
        XCTAssertFalse(asset.isVideo)
    }

    func testIsVideoReflectsKind() {
        XCTAssertTrue(descriptor(kind: .video).isVideo)
        XCTAssertFalse(descriptor(kind: .photo).isVideo)
        XCTAssertFalse(descriptor(kind: .livePhoto).isVideo)
    }

    func testVideoIgnoresStrayPhotoSubtypeFlags() {
        // A video can never be a screenshot or a panorama, so even stray
        // subtype flags must not create a photo category for it.
        let video = descriptor(kind: .video, isScreenshot: true, isPanorama: true)
        XCTAssertEqual(video.categories, [.video])
    }

    func testClassificationPreservesOneStableIdentifier() {
        let asset = descriptor(kind: .livePhoto, isScreenshot: true)
        XCTAssertEqual(asset.id, "asset")
        XCTAssertEqual(asset.kind, .livePhoto)
    }
}
