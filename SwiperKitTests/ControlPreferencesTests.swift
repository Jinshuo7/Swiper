import XCTest
@testable import SwiperKit

final class ControlPreferencesTests: XCTestCase {
    func testPresetCapabilities() {
        XCTAssertTrue(ControlPreset.swipe.usesSwipeGestures)
        XCTAssertFalse(ControlPreset.swipe.showsDeleteButton)
        XCTAssertFalse(ControlPreset.swipe.showsAnyDecisionControl)

        XCTAssertTrue(ControlPreset.thumb.showsKeepButton)
        XCTAssertTrue(ControlPreset.thumb.showsDeleteButton)
        XCTAssertFalse(ControlPreset.thumb.showsFavoriteButton)
        XCTAssertTrue(ControlPreset.thumb.showsAnyDecisionControl)

        XCTAssertFalse(ControlPreset.deleteOnly.showsKeepButton)
        XCTAssertTrue(ControlPreset.deleteOnly.showsDeleteButton)
        XCTAssertFalse(ControlPreset.deleteOnly.usesSwipeGestures)

        XCTAssertTrue(ControlPreset.extended.showsKeepButton)
        XCTAssertTrue(ControlPreset.extended.showsDeleteButton)
        XCTAssertTrue(ControlPreset.extended.showsFavoriteButton)
        XCTAssertTrue(ControlPreset.extended.showsUndoButton)
    }

    func testDefaults() {
        let preferences = ControlPreferences.default
        XCTAssertEqual(preferences.preset, .swipe)
        XCTAssertEqual(preferences.rail, .bottom)
        XCTAssertEqual(preferences.anchor, .center)
        XCTAssertEqual(preferences.defaultDirection, .older)
    }

    func testAnchorTitlesFollowTheRail() {
        XCTAssertEqual(ControlAnchor.start.title(for: .bottom), "Left")
        XCTAssertEqual(ControlAnchor.end.title(for: .bottom), "Right")
        XCTAssertEqual(ControlAnchor.start.title(for: .leading), "Top")
        XCTAssertEqual(ControlAnchor.end.title(for: .trailing), "Bottom")
        XCTAssertFalse(ControlRail.bottom.isVertical)
        XCTAssertTrue(ControlRail.leading.isVertical)
        XCTAssertTrue(ControlRail.trailing.isVertical)
    }

    func testRoundTripsThroughCodable() throws {
        let preferences = ControlPreferences(
            preset: .extended,
            rail: .leading,
            anchor: .start,
            defaultDirection: .newer
        )
        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(ControlPreferences.self, from: data)
        XCTAssertEqual(decoded, preferences)
    }

    /// Preferences written before the rail existed stored a three-way
    /// horizontal placement. That choice must survive as the anchor on the
    /// bottom rail rather than being silently reset to the default.
    func testLegacyPlacementIsMigratedToTheRailAnchor() throws {
        let decoder = JSONDecoder()

        let left = try decoder.decode(
            ControlPreferences.self,
            from: Data(#"{"preset":"thumb","placement":"left","defaultDirection":"newer"}"#.utf8)
        )
        XCTAssertEqual(left.preset, .thumb)
        XCTAssertEqual(left.rail, .bottom)
        XCTAssertEqual(left.anchor, .start)
        XCTAssertEqual(left.defaultDirection, .newer)

        let centre = try decoder.decode(
            ControlPreferences.self,
            from: Data(#"{"preset":"swipe","placement":"center","defaultDirection":"older"}"#.utf8)
        )
        XCTAssertEqual(centre.anchor, .center)

        let right = try decoder.decode(
            ControlPreferences.self,
            from: Data(#"{"placement":"right"}"#.utf8)
        )
        XCTAssertEqual(right.rail, .bottom)
        XCTAssertEqual(right.anchor, .end)
        XCTAssertEqual(right.preset, .swipe, "a missing preset falls back to the default")
    }

    func testEncodedPreferencesDoNotWriteTheLegacyKey() throws {
        let data = try JSONEncoder().encode(ControlPreferences(preset: .thumb, rail: .trailing, anchor: .end))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(object["placement"])
        XCTAssertEqual(object["rail"] as? String, "trailing")
        XCTAssertEqual(object["anchor"] as? String, "end")
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
        store.savePreferences(ControlPreferences(preset: .thumb, rail: .trailing, anchor: .end))
        XCTAssertEqual(store.loadPreferences().preset, .thumb)
        XCTAssertEqual(store.loadPreferences().rail, .trailing)
        XCTAssertEqual(store.loadPreferences().anchor, .end)
    }
}
