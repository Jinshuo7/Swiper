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

    func testUndoSideNames() {
        XCTAssertEqual(UndoSide.leading.title, "Left")
        XCTAssertEqual(UndoSide.trailing.title, "Right")
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
        XCTAssertEqual(bottom.width, 228, "three controls and the tray's padding")

        // A 375 pt phone leaves room at each bottom corner for the side columns.
        XCTAssertGreaterThanOrEqual((375 - bottom.width) / 2, 40)

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
        XCTAssertEqual(ControlClusterLayout.order(for: .leading), [.undo, .trash, .keep])
        XCTAssertEqual(ControlClusterLayout.order(for: .trailing), [.trash, .keep, .undo])
        for side in UndoSide.allCases {
            let order = ControlClusterLayout.order(for: side)
            XCTAssertEqual(
                order.count,
                ControlClusterLayout.ClusterControl.allCases.count,
                "every control is drawn exactly once: the dock has no grip"
            )
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

    /// The dock is moved as one piece, so every destination is the same shape
    /// and holds all three controls. Those frames are also what the destination
    /// markers draw while the dock is in the air.
    func testEveryDestinationHoldsAllThreeControlsAtTheSameSize() {
        for position in ControlPosition.allCases {
            let rect = ControlClusterLayout.slotRect(for: position, in: safeArea)
            let expected = ControlClusterLayout.clusterSize(for: position)
            XCTAssertEqual(rect.size, expected, "\(position) is the same dock")
            XCTAssertEqual(
                [rect.width, rect.height].sorted(),
                [88, 228],
                "the dock is the same 88 by 228 shape at every destination, only turned"
            )
            XCTAssertEqual(
                CGPoint(x: rect.midX, y: rect.midY),
                ControlClusterLayout.centre(for: position, in: safeArea),
                "the marker is drawn where the dock will land"
            )
        }
    }

    /// The spec puts the landing bounce at or below 0.2.
    func testLandingBounceStaysAtOrBelowTheSpecCeiling() {
        XCTAssertLessThanOrEqual(ControlClusterLayout.landingBounce, 0.2)
        XCTAssertGreaterThan(ControlClusterLayout.reduceMotionDuration, 0)
    }
}
