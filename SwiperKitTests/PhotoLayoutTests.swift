import XCTest
@testable import SwiperKit

final class PhotoLayoutTests: XCTestCase {
    private let phoneScreen = CGSize(width: 375, height: 812)

    func testLandscapePhotoIsWidthLimitedAndLetterboxed() {
        let size = PhotoLayout.fittedSize(
            forPixelSize: CGSize(width: 4_032, height: 3_024),
            in: phoneScreen
        )
        XCTAssertEqual(size.width, 375, accuracy: 0.001)
        XCTAssertEqual(size.height, 281.25, accuracy: 0.001)
        XCTAssertLessThan(size.height, phoneScreen.height)
    }

    func testPortraitPhotoIsHeightLimitedAndPillarboxedWhenScreenIsShort() {
        let shortScreen = CGSize(width: 800, height: 500)
        let size = PhotoLayout.fittedSize(
            forPixelSize: CGSize(width: 3_024, height: 4_032),
            in: shortScreen
        )
        XCTAssertEqual(size.height, 500, accuracy: 0.001)
        XCTAssertEqual(size.width, 375, accuracy: 0.001)
    }

    func testSquarePhotoFitsBothWaysWithoutExceedingBounds() {
        let size = PhotoLayout.fittedSize(
            forPixelSize: CGSize(width: 3_000, height: 3_000),
            in: phoneScreen
        )
        XCTAssertEqual(size.width, 375, accuracy: 0.001)
        XCTAssertEqual(size.height, 375, accuracy: 0.001)
    }

    func testPanoramaKeepsItsExtremeAspectRatio() {
        let size = PhotoLayout.fittedSize(
            forPixelSize: CGSize(width: 8_000, height: 2_000),
            in: phoneScreen
        )
        XCTAssertEqual(size.width, 375, accuracy: 0.001)
        XCTAssertEqual(size.height, 93.75, accuracy: 0.001)
        XCTAssertEqual(size.width / size.height, 4, accuracy: 0.0001)
    }

    func testPortraitPhotoIsWidthLimitedOnATallPhone() {
        let size = PhotoLayout.fittedSize(
            forPixelSize: CGSize(width: 3_024, height: 4_032),
            in: phoneScreen
        )
        // 375 / 812 is wider than 3024 / 4032, so the width is the limit.
        XCTAssertEqual(size.width, 375, accuracy: 0.001)
        XCTAssertEqual(size.height, 500, accuracy: 0.001)
    }

    func testVeryTallPhotoIsHeightLimited() {
        let size = PhotoLayout.fittedSize(
            forPixelSize: CGSize(width: 100, height: 4_000),
            in: phoneScreen
        )
        XCTAssertEqual(size.height, 812, accuracy: 0.001)
        XCTAssertEqual(size.width, 20.3, accuracy: 0.001)
    }

    func testFittedSizeNeverExceedsBoundsAcrossRealShapes() {
        let shapes = [
            CGSize(width: 4_032, height: 3_024),
            CGSize(width: 3_024, height: 4_032),
            CGSize(width: 3_000, height: 3_000),
            CGSize(width: 8_000, height: 2_000),
            CGSize(width: 100, height: 4_000),
        ]
        let bounds = [phoneScreen, CGSize(width: 1_024, height: 1_366), CGSize(width: 100, height: 100)]
        for shape in shapes {
            for bound in bounds {
                let size = PhotoLayout.fittedSize(forPixelSize: shape, in: bound)
                XCTAssertLessThanOrEqual(size.width, bound.width + 0.001)
                XCTAssertLessThanOrEqual(size.height, bound.height + 0.001)
                XCTAssertEqual(
                    size.width / size.height,
                    shape.width / shape.height,
                    accuracy: 0.0001,
                    "\(shape) in \(bound) changed the aspect ratio"
                )
            }
        }
    }

    func testFittedRectIsCentred() {
        let bounds = CGRect(origin: .zero, size: phoneScreen)
        let rect = PhotoLayout.fittedRect(forPixelSize: CGSize(width: 4_032, height: 3_024), in: bounds)
        XCTAssertEqual(rect.midX, bounds.midX, accuracy: 0.001)
        XCTAssertEqual(rect.midY, bounds.midY, accuracy: 0.001)
        XCTAssertEqual(rect.height, 281.25, accuracy: 0.001)
    }

    func testDegenerateInputsFallBackToBounds() {
        let zeroPixels = PhotoLayout.fittedSize(forPixelSize: .zero, in: phoneScreen)
        XCTAssertEqual(zeroPixels, phoneScreen)
        let zeroBounds = PhotoLayout.fittedSize(
            forPixelSize: CGSize(width: 4_032, height: 3_024),
            in: .zero
        )
        XCTAssertEqual(zeroBounds, .zero)
    }

    func testFitsWithoutCroppingDetectsCroppedResult() {
        let pixels = CGSize(width: 4_032, height: 3_024)
        let good = PhotoLayout.fittedSize(forPixelSize: pixels, in: phoneScreen)
        XCTAssertTrue(PhotoLayout.fitsWithoutCropping(size: good, pixelSize: pixels, in: phoneScreen))

        // A fill-style result: correct width but the full screen height, which
        // is exactly the cropping this design must prevent.
        let cropped = CGSize(width: 375, height: 812)
        XCTAssertFalse(PhotoLayout.fitsWithoutCropping(size: cropped, pixelSize: pixels, in: phoneScreen))
    }

    func testAssetDescriptorExposesItsAspectRatio() {
        let landscape = TestLibrary.descriptor(id: "a", dayOffset: 0, width: 4_032, height: 3_024)
        XCTAssertEqual(landscape.aspectRatio, 4.0 / 3.0, accuracy: 0.0001)
        let degenerate = TestLibrary.descriptor(id: "b", dayOffset: 1, width: 0, height: 0)
        XCTAssertEqual(degenerate.aspectRatio, 1)
    }
}
