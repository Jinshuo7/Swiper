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

    /// A drag between the bottom row and a side column passes closer to the side
    /// destination before it has left the bottom one's release radius, so the
    /// nearest destination flips while the capture must not. Losing it there
    /// would flicker the highlighted marker off and drop a release the user had
    /// every right to expect would land.
    func testACapturedDestinationHoldsUntilItsReleaseRadiusIsPassed() {
        // The safe area of the phone the screenshots and the local suite run on.
        let safeArea = CGSize(width: 375, height: 763)
        let bottom = DockGeometry.centre(for: .bottom, in: safeArea)
        let leading = DockGeometry.centre(for: .leading, in: safeArea)
        let separation = hypot(leading.x - bottom.x, leading.y - bottom.y)
        // Just inside the bottom's release radius, and already nearer the leading
        // column: the flip the realistic geometry produces.
        let along = DockGeometry.releaseRadius - 1
        let point = CGPoint(
            x: bottom.x + (leading.x - bottom.x) / separation * along,
            y: bottom.y + (leading.y - bottom.y) / separation * along
        )
        XCTAssertGreaterThan(
            separation - along,
            DockGeometry.captureRadius,
            "the leading column is not yet close enough to be captured itself"
        )
        XCTAssertNil(
            DockGeometry.capture(at: point, in: safeArea, currentlyCaptured: nil),
            "nothing is captured out there from a standing start"
        )
        XCTAssertEqual(
            DockGeometry.capture(at: point, in: safeArea, currentlyCaptured: .bottom),
            .bottom,
            "the capture holds until its own release radius is left"
        )
        XCTAssertEqual(
            DockGeometry.destination(forReleaseAt: point, in: safeArea, captured: .bottom),
            .bottom,
            "releasing there still lands on the captured destination"
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

    /// The dock has no grip, so no source is special: a drag must be able to
    /// reach all three destinations from all three, and the release must land on
    /// the one the finger finished on.
    func testEverySourceCanReachEveryDestination() {
        for source in ControlPosition.allCases {
            let start = DockGeometry.centre(for: source, in: size)
            for destination in ControlPosition.allCases {
                let target = DockGeometry.centre(for: destination, in: size)
                XCTAssertTrue(
                    DockGeometry.cancelsTap(from: start, to: target) || source == destination,
                    "a drag from \(source) to \(destination) must cancel the pending tap"
                )
                XCTAssertEqual(
                    DockGeometry.capture(at: target, in: size, currentlyCaptured: nil),
                    destination,
                    "the \(destination) marker captures the finger"
                )
                XCTAssertEqual(
                    DockGeometry.destination(forReleaseAt: target, in: size, captured: destination),
                    destination,
                    "a release on the \(destination) marker lands there, from \(source)"
                )
            }
        }
    }

    /// Releasing back over the source is a valid landing on the source, not a
    /// lost move: the dock is simply put down where it was picked up.
    func testAReleaseBackOnTheSourceLandsOnTheSource() {
        for source in ControlPosition.allCases {
            let centre = DockGeometry.centre(for: source, in: size)
            XCTAssertEqual(
                DockGeometry.destination(forReleaseAt: centre, in: size, captured: source),
                source
            )
        }
    }

    /// A release nowhere near a destination changes nothing, even after a
    /// capture: the finger left the marker and nothing was captured again.
    func testAReleaseOverNoDestinationRestoresTheSource() {
        let far = CGPoint(x: size.width / 2, y: size.height * 0.3)
        XCTAssertNil(DockGeometry.capture(at: far, in: size, currentlyCaptured: nil))
        XCTAssertNil(DockGeometry.destination(forReleaseAt: far, in: size, captured: nil))
    }

    /// Where two markers are near enough that a finger is inside both, the
    /// nearer centre wins rather than the first in case order.
    func testTheNearestDestinationResolvesAnOverlap() {
        let left = DockGeometry.centre(for: .leading, in: size)
        let bottom = DockGeometry.centre(for: .bottom, in: size)
        XCTAssertEqual(
            DockGeometry.capture(at: CGPoint(x: left.x + 8, y: left.y - 8), in: size, currentlyCaptured: nil),
            .leading
        )
        XCTAssertEqual(
            DockGeometry.capture(at: CGPoint(x: bottom.x - 20, y: bottom.y - 8), in: size, currentlyCaptured: nil),
            .bottom
        )
    }

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
