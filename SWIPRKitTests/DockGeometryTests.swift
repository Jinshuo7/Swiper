import XCTest
@testable import SWIPRKit

final class DockGeometryTests: XCTestCase {
    private let size = CGSize(width: 400, height: 800)

    // MARK: - Tap cancellation

    func testASmallMoveIsStillATap() {
        XCTAssertFalse(DockGeometry.cancelsTap(from: CGPoint(x: 200, y: 400), to: CGPoint(x: 208, y: 400)))
    }

    func testAMovePastTheThresholdCancelsTheTap() {
        XCTAssertTrue(DockGeometry.cancelsTap(from: CGPoint(x: 200, y: 400), to: CGPoint(x: 211, y: 400)))
    }

    // MARK: - Capture

    func testEachDestinationCapturesItsOwnCentre() {
        for position in ControlPosition.allCases {
            let centre = DockGeometry.centre(for: position, in: size)
            XCTAssertEqual(
                DockGeometry.capture(at: centre, in: size, currentlyCaptured: nil),
                position,
                "the centre of \(position) captures it"
            )
        }
    }

    func testAFingerFarFromEveryDestinationCapturesNothing() {
        XCTAssertNil(DockGeometry.capture(at: CGPoint(x: 200, y: 200), in: size, currentlyCaptured: nil))
    }

    func testHysteresisKeepsAnAlreadyCapturedDestination() {
        // 80 points above the bottom centre: beyond captureRadius (72) but inside
        // releaseRadius (96).
        let centre = DockGeometry.centre(for: .bottom, in: size)
        let between = CGPoint(x: centre.x, y: centre.y - 80)

        XCTAssertNil(
            DockGeometry.capture(at: between, in: size, currentlyCaptured: nil),
            "a fresh capture needs the tighter radius"
        )
        XCTAssertEqual(
            DockGeometry.capture(at: between, in: size, currentlyCaptured: .bottom),
            .bottom,
            "once captured, the larger release radius holds it"
        )
    }

    // MARK: - Release

    func testAReleaseInsideTheReleaseRadiusLands() {
        let centre = DockGeometry.centre(for: .bottom, in: size)
        let between = CGPoint(x: centre.x, y: centre.y - 80)
        XCTAssertEqual(
            DockGeometry.destination(forReleaseAt: between, in: size, captured: .bottom),
            .bottom
        )
    }

    func testAReleaseBeyondTheReleaseRadiusRestoresTheSource() {
        let centre = DockGeometry.centre(for: .bottom, in: size)
        let tooFar = CGPoint(x: centre.x, y: centre.y - 120)
        XCTAssertNil(DockGeometry.destination(forReleaseAt: tooFar, in: size, captured: .bottom))
    }

    func testAReleaseWithNothingCapturedLandsNowhere() {
        XCTAssertNil(
            DockGeometry.destination(
                forReleaseAt: DockGeometry.centre(for: .bottom, in: size),
                in: size,
                captured: nil
            )
        )
    }

    // MARK: - Nearest destination

    func testNearestDestinationFollowsTheFinger() {
        let leading = DockGeometry.centre(for: .leading, in: size)
        XCTAssertEqual(
            DockGeometry.nearestDestination(to: CGPoint(x: leading.x + 5, y: leading.y), in: size),
            .leading
        )
        let trailing = DockGeometry.centre(for: .trailing, in: size)
        XCTAssertEqual(
            DockGeometry.nearestDestination(to: CGPoint(x: trailing.x - 5, y: trailing.y), in: size),
            .trailing
        )
    }

    func testAnEmptySafeAreaHasNoDestination() {
        XCTAssertNil(DockGeometry.nearestDestination(to: .zero, in: .zero))
    }

    func testDestinationsRespectTheSafeAreaEdgeMargin() {
        for position in ControlPosition.allCases {
            let centre = DockGeometry.centre(for: position, in: size)
            let cluster = ControlClusterLayout.clusterSize(for: position)
            let frame = CGRect(
                x: centre.x - cluster.width / 2,
                y: centre.y - cluster.height / 2,
                width: cluster.width,
                height: cluster.height
            )
            XCTAssertGreaterThanOrEqual(frame.minX, 0)
            XCTAssertLessThanOrEqual(frame.maxX, size.width)
            XCTAssertLessThanOrEqual(frame.maxY, size.height)
        }
    }
}
