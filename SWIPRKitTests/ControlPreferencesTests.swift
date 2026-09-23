import XCTest
@testable import SWIPRKit

final class ControlPreferencesTests: XCTestCase {
    func testDefaults() {
        let preferences = ControlPreferences.default
        XCTAssertEqual(preferences.position, .bottom)
        XCTAssertTrue(preferences.showButtons)
        XCTAssertEqual(preferences.undoSide, .leading)
        XCTAssertEqual(preferences.defaultDirection, .older)
    }

    func testUndoSideNamesAndOpposite() {
        XCTAssertEqual(UndoSide.leading.title, "Left")
        XCTAssertEqual(UndoSide.trailing.title, "Right")
        XCTAssertEqual(UndoSide.leading.opposite, .trailing)
        XCTAssertEqual(UndoSide.trailing.opposite, .leading)
    }

    func testPositionNamesAndOrientation() {
        XCTAssertFalse(ControlPosition.bottom.isVertical)
        XCTAssertTrue(ControlPosition.leading.isVertical)
        XCTAssertTrue(ControlPosition.trailing.isVertical)
        XCTAssertEqual(ControlPosition.bottom.title, "bottom")
        XCTAssertEqual(ControlPosition.leading.title, "left edge")
        XCTAssertEqual(ControlPosition.trailing.title, "right edge")
        XCTAssertEqual(ControlPosition.bottom.next, .leading)
        XCTAssertEqual(ControlPosition.leading.next, .trailing)
        XCTAssertEqual(ControlPosition.trailing.next, .bottom)
    }

    func testRoundTripsThroughCodable() throws {
        let preferences = ControlPreferences(
            position: .leading,
            showButtons: false,
            undoSide: .trailing,
            defaultDirection: .newer
        )
        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(ControlPreferences.self, from: data)
        XCTAssertEqual(decoded, preferences)
    }

    /// Preferences written before the grip existed stored the three-way dock
    /// under `rail` plus a continuous `position` number. The stop survives; the
    /// number is dropped.
    func testTheOldRailBecomesTheFixedPosition() throws {
        let decoder = JSONDecoder()

        let left = try decoder.decode(
            ControlPreferences.self,
            from: Data(#"{"preset":"thumb","rail":"leading","position":0.2}"#.utf8)
        )
        XCTAssertEqual(left.position, .leading)

        let right = try decoder.decode(
            ControlPreferences.self,
            from: Data(#"{"preset":"swipe","rail":"trailing","anchor":"end"}"#.utf8)
        )
        XCTAssertEqual(right.position, .trailing)

        let bottom = try decoder.decode(
            ControlPreferences.self,
            from: Data(#"{"rail":"bottom"}"#.utf8)
        )
        XCTAssertEqual(bottom.position, .bottom)
        XCTAssertTrue(bottom.showButtons)
        XCTAssertEqual(bottom.undoSide, .leading, "preferences written before the setting get the default")
    }

    /// Placement predates the rail and was horizontal-only, so it is a bottom
    /// row under the fixed scheme.
    func testLegacyPlacementBecomesTheBottomRow() throws {
        let decoded = try JSONDecoder().decode(
            ControlPreferences.self,
            from: Data(#"{"preset":"thumb","placement":"left","defaultDirection":"newer"}"#.utf8)
        )
        XCTAssertEqual(decoded.position, .bottom)
        XCTAssertEqual(decoded.defaultDirection, .newer)
    }

    /// The rail order preference is gone, but old state that contains it still
    /// has to load.
    func testAnOldOrderKeyIsIgnoredRatherThanRejected() throws {
        let decoded = try JSONDecoder().decode(
            ControlPreferences.self,
            from: Data(#"{"preset":"thumb","rail":"bottom","anchor":"center","order":"keepFirst"}"#.utf8)
        )
        XCTAssertEqual(decoded.position, .bottom)
    }

    func testEncodedPreferencesWriteTheNewKeysAndNoLegacyOnes() throws {
        let data = try JSONEncoder().encode(
            ControlPreferences(position: .trailing, showButtons: false)
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(object["rail"])
        XCTAssertNil(object["preset"])
        XCTAssertNil(object["anchor"])
        XCTAssertNil(object["placement"])
        XCTAssertNil(object["order"])
        XCTAssertEqual(object["position"] as? String, "trailing")
        XCTAssertEqual(object["showButtons"] as? Bool, false)
    }

    /// A present-but-invalid stored rail is not guessed at; the store's
    /// `?? .default` then yields the documented defaults.
    func testAnUnknownRailIsRejectedSoTheStoreFallsBackToTheDefault() {
        let decoded = try? JSONDecoder().decode(ControlPreferences.self, from: Data(#"{"rail":"sideways"}"#.utf8))
        XCTAssertNil(decoded)
    }

    func testInMemoryStorePersistsPreferences() {
        let store = InMemorySessionStore()
        XCTAssertEqual(store.loadPreferences(), .default)
        store.savePreferences(ControlPreferences(position: .trailing, showButtons: false))
        XCTAssertEqual(store.loadPreferences().position, .trailing)
        XCTAssertFalse(store.loadPreferences().showButtons)
    }
}

final class ControlClusterLayoutTests: XCTestCase {
    /// A 375 pt wide phone with a 763 pt safe area (iPhone 11 Pro after the bars).
    private let safeArea = CGSize(width: 375, height: 763)

    func testClusterSizeShortAxisIsEightyEight() {
        let bottom = ControlClusterLayout.clusterSize(for: .bottom)
        XCTAssertEqual(bottom.height, 88)
        XCTAssertGreaterThan(bottom.width, 0)

        let column = ControlClusterLayout.clusterSize(for: .leading)
        XCTAssertEqual(column.width, 88)
        XCTAssertEqual(column.height, bottom.width)
    }

    /// The spec's geometry: a row centred on the width 20 pt above the bottom
    /// safe edge; columns centred at 75% of the safe height, 20 pt inside the
    /// edge.
    func testTheThreePositionsMatchTheSpec() {
        let bottomSize = ControlClusterLayout.clusterSize(for: .bottom)
        let bottom = ControlClusterLayout.centre(for: .bottom, in: safeArea)
        XCTAssertEqual(bottom.x, safeArea.width / 2, accuracy: 0.5)
        XCTAssertEqual(bottom.y, safeArea.height - 20 - bottomSize.height / 2, accuracy: 0.5)

        let columnSize = ControlClusterLayout.clusterSize(for: .leading)
        let left = ControlClusterLayout.centre(for: .leading, in: safeArea)
        XCTAssertEqual(left.x, 20 + columnSize.width / 2, accuracy: 0.5)
        XCTAssertEqual(left.y, safeArea.height * 0.75, accuracy: 0.5)

        let right = ControlClusterLayout.centre(for: .trailing, in: safeArea)
        XCTAssertEqual(right.x, safeArea.width - 20 - columnSize.width / 2, accuracy: 0.5)
        XCTAssertEqual(right.y, safeArea.height * 0.75, accuracy: 0.5)
    }

    /// Trash and Keep stay adjacent and in the swipe wells' order; Undo is at
    /// one outer end, never between them.
    func testUndoSitsAtAnOuterEndAwayFromThePair() {
        XCTAssertEqual(ControlClusterLayout.order(for: .leading), [.undo, .trash, .keep, .grip])
        XCTAssertEqual(ControlClusterLayout.order(for: .trailing), [.grip, .trash, .keep, .undo])
        for side in UndoSide.allCases {
            let order = ControlClusterLayout.order(for: side)
            let trash = order.firstIndex(of: .trash)
            let keep = order.firstIndex(of: .keep)
            XCTAssertEqual(keep, trash.map { $0 + 1 }, "Trash and Keep must stay adjacent")
            let undo = order.firstIndex(of: .undo)
            XCTAssertTrue(
                undo == 0 || undo == order.count - 1,
                "Undo must sit at an outer end, got index \(String(describing: undo))"
            )
        }
    }

    func testTheGripSitsAtTheEndOppositeUndo() {
        for position in ControlPosition.allCases {
            let centre = ControlClusterLayout.centre(for: position, in: safeArea)
            let gripWhenUndoTrailing = ControlClusterLayout.gripCentre(for: position, in: safeArea, undoSide: .trailing)
            let gripWhenUndoLeading = ControlClusterLayout.gripCentre(for: position, in: safeArea, undoSide: .leading)
            XCTAssertTrue(
                ControlClusterLayout.slotRect(for: position, in: safeArea).contains(gripWhenUndoTrailing),
                "the grip must be inside its own tray at \(position)"
            )
            if position.isVertical {
                XCTAssertLessThan(gripWhenUndoTrailing.y, centre.y, "grip leads when Undo trails")
                XCTAssertGreaterThan(gripWhenUndoLeading.y, centre.y, "grip trails when Undo leads")
                XCTAssertEqual(gripWhenUndoTrailing.x, centre.x, accuracy: 0.5)
            } else {
                XCTAssertLessThan(gripWhenUndoTrailing.x, centre.x, "grip leads when Undo trails")
                XCTAssertGreaterThan(gripWhenUndoLeading.x, centre.x, "grip trails when Undo leads")
                XCTAssertEqual(gripWhenUndoTrailing.y, centre.y, accuracy: 0.5)
            }
        }
    }

    /// A release lands only when the puck is over a slot. The middle of the
    /// screen is above the columns and nowhere near the bottom row, so it is a
    /// change-nothing release.
    func testOnlyPointsOverASlotLandSomewhere() {
        XCTAssertEqual(
            ControlClusterLayout.slot(at: ControlClusterLayout.centre(for: .bottom, in: safeArea), in: safeArea),
            .bottom
        )
        XCTAssertEqual(
            ControlClusterLayout.slot(at: ControlClusterLayout.centre(for: .leading, in: safeArea), in: safeArea),
            .leading
        )
        XCTAssertEqual(
            ControlClusterLayout.slot(at: ControlClusterLayout.centre(for: .trailing, in: safeArea), in: safeArea),
            .trailing
        )
        XCTAssertNil(
            ControlClusterLayout.slot(at: CGPoint(x: safeArea.width / 2, y: safeArea.height * 0.35), in: safeArea),
            "a release over no slot must change nothing"
        )
    }

    /// Where two slots overlap, the nearer centre wins rather than the first in
    /// case order.
    func testOverlappingSlotsAreResolvedByDistance() {
        let left = ControlClusterLayout.centre(for: .leading, in: safeArea)
        let bottom = ControlClusterLayout.centre(for: .bottom, in: safeArea)
        // A point just beside the left slot's centre stays with the left column.
        let nearLeft = CGPoint(x: left.x + 10, y: left.y - 10)
        XCTAssertEqual(ControlClusterLayout.slot(at: nearLeft, in: safeArea), .leading)
        let nearBottom = CGPoint(x: bottom.x - 30, y: bottom.y - 10)
        XCTAssertEqual(ControlClusterLayout.slot(at: nearBottom, in: safeArea), .bottom)
    }

    /// The spec puts the landing bounce at or below 0.2.
    func testLandingBounceStaysAtOrBelowTheSpecCeiling() {
        XCTAssertLessThanOrEqual(ControlClusterLayout.landingBounce, 0.2)
        XCTAssertGreaterThan(ControlClusterLayout.reduceMotionDuration, 0)
    }
}
