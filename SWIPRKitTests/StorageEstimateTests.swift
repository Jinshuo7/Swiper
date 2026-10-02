import XCTest
@testable import SWIPRKit

final class StorageEstimateTests: XCTestCase {
    func testPhotoEstimateUsesBytesPerPixel() {
        let expected = Int64((Double(4_032 * 3_024) * StorageEstimate.stillBytesPerPixel).rounded())
        XCTAssertEqual(StorageEstimate.bytes(width: 4_032, height: 3_024, kind: .photo), expected)
    }

    func testLivePhotoAddsMotionComponent() {
        let still = StorageEstimate.bytes(width: 4_032, height: 3_024, kind: .photo)
        let live = StorageEstimate.bytes(width: 4_032, height: 3_024, kind: .livePhoto)
        XCTAssertEqual(live, still + StorageEstimate.livePhotoMotionBytes)
    }

    func testZeroDimensionsFallBackToMinimum() {
        XCTAssertEqual(StorageEstimate.bytes(width: 0, height: 0, kind: .photo), StorageEstimate.minimumStillBytes)
    }

    func testVideoEstimateIsConservativeZero() {
        XCTAssertEqual(StorageEstimate.bytes(width: 3_840, height: 2_160, kind: .video), 0)
        XCTAssertEqual(StorageEstimate.bytes(width: 0, height: 0, kind: .video), 0)
    }

    func testVideoDescriptorEstimatesZeroBytes() {
        let video = AssetDescriptor(
            id: "video",
            creationDate: nil,
            pixelWidth: 3_840,
            pixelHeight: 2_160,
            kind: .video
        )
        XCTAssertEqual(video.estimatedBytes, 0)
        XCTAssertEqual(StorageEstimate.bytes(for: video), 0)
    }

    func testByteFormatterScalesUnits() {
        XCTAssertEqual(ByteFormatter.string(fromBytes: 1), "1 byte")
        XCTAssertEqual(ByteFormatter.string(fromBytes: 999), "999 bytes")
        XCTAssertEqual(ByteFormatter.string(fromBytes: 1_000), "1.0 KB")
        XCTAssertEqual(ByteFormatter.string(fromBytes: 1_000_000), "1.0 MB")
        XCTAssertEqual(ByteFormatter.string(fromBytes: 26_000_000), "26 MB")
        XCTAssertEqual(ByteFormatter.string(fromBytes: 1_500_000_000), "1.5 GB")
        XCTAssertEqual(ByteFormatter.string(fromBytes: 2_000_000_000_000), "2.0 TB")
        XCTAssertEqual(ByteFormatter.string(fromBytes: 999_999_999), "1.0 GB")
    }

    func testApproximateCopy() {
        XCTAssertEqual(ByteFormatter.approximateString(fromBytes: 1_200_000_000), "about 1.2 GB")
    }

    func testNegativeValuesAreClamped() {
        XCTAssertEqual(ByteFormatter.string(fromBytes: -5), "0 bytes")
    }
}
