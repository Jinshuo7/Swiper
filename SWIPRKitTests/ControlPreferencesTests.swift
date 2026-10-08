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

    /// The tray an Undo at `undoSide` leaves for the labelled Delete/Keep pair,
    /// in the same coordinates as `slotRect`. At a side position the pair is two
    /// of the three separate controls, and there is no tray at all.
    private func pairRect(for position: ControlPosition, undoSide: UndoSide) -> CGRect {
        let box = ControlClusterLayout.slotRect(for: position, in: safeArea, undoSide: undoSide)
        return CGRect(
            x: box.minX + (undoSide == .leading && !position.isVertical
                ? ControlClusterLayout.undoControlSize + ControlClusterLayout.undoGap
                : 0),
            y: box.minY,
            width: ControlClusterLayout.traySize.width,
            height: ControlClusterLayout.traySize.height
        )
    }

    /// The two layouts: at the bottom a wide labelled pair with a separate
    /// smaller Undo beside it, at a side three separate icon controls in a
    /// column.
    func testTheTwoLayoutsHaveTheirOwnFixedSize() {
        let bottom = ControlClusterLayout.clusterSize(for: .bottom)
        XCTAssertEqual(bottom.height, ControlClusterLayout.traySize.height)
        XCTAssertEqual(
            bottom.width,
            ControlClusterLayout.undoControlSize + ControlClusterLayout.undoGap
                + ControlClusterLayout.traySize.width,
            "the bottom dock is the pair's tray plus the separate Undo"
        )
        XCTAssertGreaterThan(
            ControlClusterLayout.traySize.width,
            ControlClusterLayout.pillWidth,
            "two labelled pills, not one"
        )

        // A 375 pt phone leaves the pair room to be centred with Undo beside it.
        XCTAssertGreaterThanOrEqual((375 - bottom.width) / 2, 16)

        let column = ControlClusterLayout.clusterSize(for: .leading)
        XCTAssertEqual(column.width, ControlClusterLayout.controlSize, "a side control stands on its own")
        XCTAssertEqual(
            column.height,
            ControlClusterLayout.controlSize * 3 + ControlClusterLayout.controlSpacing * 2,
            "three separate controls and the non-action gaps between them"
        )
        XCTAssertEqual(ControlClusterLayout.clusterSize(for: .trailing), column, "both sides are the same column")
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

    /// The bottom pair keeps its anchor: it is the labelled Delete/Keep pair
    /// that is centred on the width, and changing which end Undo takes moves
    /// only Undo. Its action must never shift under the thumb.
    func testTheBottomPairStaysCentredWhenUndoChangesEnd() {
        for undoSide in UndoSide.allCases {
            let tray = pairRect(for: .bottom, undoSide: undoSide)
            XCTAssertEqual(
                tray.midX,
                safeArea.width / 2,
                accuracy: 0.5,
                "the labelled pair is centred on the width with Undo at the \(undoSide) end"
            )
            XCTAssertEqual(tray.midY, ControlClusterLayout.centre(for: .bottom, in: safeArea).y, accuracy: 0.5)
        }

        // The separate Undo sits outside the pair, on the end the user chose.
        let leading = ControlClusterLayout.slotRect(for: .bottom, in: safeArea, undoSide: .leading)
        let leadingTray = pairRect(for: .bottom, undoSide: .leading)
        XCTAssertEqual(leading.minX, leadingTray.minX - ControlClusterLayout.undoGap - ControlClusterLayout.undoControlSize, accuracy: 0.5)
        XCTAssertLessThan(leading.minX, leadingTray.minX, "Undo leads the pair")

        let trailing = ControlClusterLayout.slotRect(for: .bottom, in: safeArea, undoSide: .trailing)
        let trailingTray = pairRect(for: .bottom, undoSide: .trailing)
        XCTAssertEqual(trailing.maxX, trailingTray.maxX + ControlClusterLayout.undoGap + ControlClusterLayout.undoControlSize, accuracy: 0.5)
        XCTAssertGreaterThan(trailing.maxX, trailingTray.maxX, "Undo follows the pair")

        XCTAssertEqual(
            leadingTray, trailingTray,
            "moving Undo to the other end must not move Delete and Keep at all"
        )
    }

    /// A side layout is three separate controls: nothing between them acts, and
    /// nothing touches, so a stray tap lands on no control at all.
    func testTheSideLayoutSeparatesItsControlsWithANonActionGap() {
        let gap = ControlClusterLayout.controlSpacing
        XCTAssertGreaterThanOrEqual(gap, 8, "a non-action gap has to be wide enough to be one")
        XCTAssertLessThan(gap, ControlClusterLayout.controlSize, "the controls read as separate, not as a tray")

        for position in [ControlPosition.leading, .trailing] {
            let box = ControlClusterLayout.slotRect(for: position, in: safeArea)
            XCTAssertEqual(box.width, ControlClusterLayout.controlSize)
            for index in 0..<3 {
                let top = box.minY + CGFloat(index) * (ControlClusterLayout.controlSize + gap)
                XCTAssertGreaterThanOrEqual(top, box.minY)
                XCTAssertLessThanOrEqual(
                    top + ControlClusterLayout.controlSize,
                    box.maxY,
                    "control \(index) has to fit inside the column"
                )
            }
            XCTAssertEqual(
                box.height,
                3 * ControlClusterLayout.controlSize + 2 * gap,
                "the column is exactly its three controls and their two gaps"
            )
        }
    }

    /// The dock is moved as one piece, so each destination holds the whole dock
    /// at its fixed size. Those frames are also what the destination markers
    /// draw while the dock is in the air.
    func testEveryDestinationDrawsTheWholeDockAtItsOwnSize() {
        for position in ControlPosition.allCases {
            for undoSide in UndoSide.allCases {
                let rect = ControlClusterLayout.slotRect(for: position, in: safeArea, undoSide: undoSide)
                XCTAssertEqual(
                    rect.size,
                    ControlClusterLayout.clusterSize(for: position),
                    "\(position) is the same dock whichever end Undo takes"
                )
                XCTAssertGreaterThanOrEqual(rect.minX, 0, "the marker must stay on screen")
                XCTAssertLessThanOrEqual(rect.maxX, safeArea.width)
                XCTAssertGreaterThanOrEqual(rect.minY, 0)
                XCTAssertLessThanOrEqual(rect.maxY, safeArea.height)
                // The dock hangs off the anchor to the side Undo took, and the
                // anchor is always inside it.
                let anchor = ControlClusterLayout.centre(for: position, in: safeArea)
                XCTAssertTrue(rect.contains(anchor), "the marker is drawn where the dock will land")
            }
        }
    }

    /// The spec puts the landing bounce at or below 0.2.
    func testLandingBounceStaysAtOrBelowTheSpecCeiling() {
        XCTAssertLessThanOrEqual(ControlClusterLayout.landingBounce, 0.2)
        XCTAssertGreaterThan(ControlClusterLayout.reduceMotionDuration, 0)
    }
}
