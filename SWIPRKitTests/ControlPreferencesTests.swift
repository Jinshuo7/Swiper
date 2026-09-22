import XCTest
@testable import SWIPRKit

final class ControlPreferencesTests: XCTestCase {
    /// The preset now decides only how a decision can be made. The three rail
    /// controls are always there, so no preset hides any of them.
    func testPresetCapabilities() {
        XCTAssertTrue(ControlPreset.swipe.usesSwipeGestures)
        XCTAssertFalse(ControlPreset.swipe.tapToKeep)

        XCTAssertFalse(ControlPreset.thumb.usesSwipeGestures)
        XCTAssertFalse(ControlPreset.thumb.tapToKeep)

        XCTAssertFalse(ControlPreset.deleteOnly.usesSwipeGestures)
        XCTAssertTrue(ControlPreset.deleteOnly.tapToKeep)

        // `extended` is the old name for `swipe`, kept only for decoding.
        XCTAssertTrue(ControlPreset.extended.usesSwipeGestures)
        XCTAssertFalse(ControlPreset.selectable.contains(.extended))
        XCTAssertEqual(ControlPreset.selectable.count, 3)
    }

    func testDefaults() {
        let preferences = ControlPreferences.default
        XCTAssertEqual(preferences.preset, .swipe)
        XCTAssertEqual(preferences.rail, .bottom)
        XCTAssertEqual(preferences.position, 0.5)
        XCTAssertEqual(preferences.defaultDirection, .older)
    }

    func testRailNamesAndOrientation() {
        XCTAssertFalse(ControlRail.bottom.isVertical)
        XCTAssertTrue(ControlRail.leading.isVertical)
        XCTAssertTrue(ControlRail.trailing.isVertical)
        XCTAssertEqual(ControlRail.bottom.title, "bottom")
        XCTAssertEqual(ControlRail.leading.title, "left edge")
        XCTAssertEqual(ControlRail.trailing.title, "right edge")
    }

    func testPositionIsClampedAndNonFinitePositionsFallBackToTheCentre() {
        XCTAssertEqual(ControlPreferences(position: -2).position, 0)
        XCTAssertEqual(ControlPreferences(position: 4).position, 1)
        XCTAssertEqual(ControlPreferences(position: .nan).position, 0.5)
        XCTAssertEqual(ControlPreferences(position: .infinity).position, 0.5)
        XCTAssertEqual(ControlPreferences(position: 0.42).position, 0.42)
    }

    func testRoundTripsThroughCodable() throws {
        let preferences = ControlPreferences(
            preset: .thumb,
            rail: .leading,
            position: 0.2,
            defaultDirection: .newer
        )
        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(ControlPreferences.self, from: data)
        XCTAssertEqual(decoded, preferences)
    }

    /// Preferences written before the cluster could be dragged stored one of
    /// three stops. That choice must survive as a continuous position rather
    /// than being silently reset to the centre.
    func testTheOldAnchorBecomesAContinuousPosition() throws {
        let decoder = JSONDecoder()

        let start = try decoder.decode(
            ControlPreferences.self,
            from: Data(#"{"preset":"thumb","rail":"leading","anchor":"start"}"#.utf8)
        )
        XCTAssertEqual(start.rail, .leading)
        XCTAssertEqual(start.position, 0)

        let middle = try decoder.decode(
            ControlPreferences.self,
            from: Data(#"{"preset":"swipe","rail":"bottom","anchor":"center"}"#.utf8)
        )
        XCTAssertEqual(middle.position, 0.5)

        let end = try decoder.decode(
            ControlPreferences.self,
            from: Data(#"{"preset":"swipe","rail":"trailing","anchor":"end"}"#.utf8)
        )
        XCTAssertEqual(end.rail, .trailing)
        XCTAssertEqual(end.position, 1)
    }

    /// Preferences written before the rail existed stored a three-way horizontal
    /// placement on an implicit bottom rail.
    func testLegacyPlacementBecomesAContinuousPositionOnTheBottomRail() throws {
        let decoder = JSONDecoder()

        let left = try decoder.decode(
            ControlPreferences.self,
            from: Data(#"{"preset":"thumb","placement":"left","defaultDirection":"newer"}"#.utf8)
        )
        XCTAssertEqual(left.preset, .thumb)
        XCTAssertEqual(left.rail, .bottom)
        XCTAssertEqual(left.position, 0)
        XCTAssertEqual(left.defaultDirection, .newer)

        let centre = try decoder.decode(
            ControlPreferences.self,
            from: Data(#"{"preset":"swipe","placement":"center","defaultDirection":"older"}"#.utf8)
        )
        XCTAssertEqual(centre.position, 0.5)

        let right = try decoder.decode(
            ControlPreferences.self,
            from: Data(#"{"placement":"right"}"#.utf8)
        )
        XCTAssertEqual(right.rail, .bottom)
        XCTAssertEqual(right.position, 1)
        XCTAssertEqual(right.preset, .swipe, "a missing preset falls back to the default")
    }

    /// The rail order preference is gone, but old state that contains it still
    /// has to load.
    func testAnOldOrderKeyIsIgnoredRatherThanRejected() throws {
        let decoded = try JSONDecoder().decode(
            ControlPreferences.self,
            from: Data(#"{"preset":"thumb","rail":"bottom","anchor":"center","order":"keepFirst"}"#.utf8)
        )
        XCTAssertEqual(decoded.rail, .bottom)
        XCTAssertEqual(decoded.position, 0.5)
    }

    func testEncodedPreferencesWriteThePositionAndNoLegacyKeys() throws {
        let data = try JSONEncoder().encode(
            ControlPreferences(preset: .thumb, rail: .trailing, position: 0.25)
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(object["placement"])
        XCTAssertNil(object["anchor"])
        XCTAssertNil(object["order"])
        XCTAssertEqual(object["rail"] as? String, "trailing")
        XCTAssertEqual(object["position"] as? Double, 0.25)
    }

    func testAnUnknownRailIsRejectedSoTheStoreFallsBackToTheDefault() {
        // `decodeIfPresent` still throws on a present-but-invalid value, so an
        // unrecognised rail is not guessed at; the store's `?? .default` then
        // yields the documented defaults.
        let decoded = try? JSONDecoder().decode(ControlPreferences.self, from: Data(#"{"rail":"sideways"}"#.utf8))
        XCTAssertNil(decoded)
    }

    func testInMemoryStorePersistsPreferences() {
        let store = InMemorySessionStore()
        XCTAssertEqual(store.loadPreferences(), .default)
        store.savePreferences(ControlPreferences(preset: .thumb, rail: .trailing, position: 0.8))
        XCTAssertEqual(store.loadPreferences().preset, .thumb)
        XCTAssertEqual(store.loadPreferences().rail, .trailing)
        XCTAssertEqual(store.loadPreferences().position, 0.8)
    }
}
