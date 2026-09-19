import XCTest
@testable import SwiperKit

final class ControlPreferencesTests: XCTestCase {
    func testPresetCapabilities() {
        XCTAssertTrue(ControlPreset.swipe.usesSwipeGestures)
        XCTAssertFalse(ControlPreset.swipe.showsDeleteButton)

        XCTAssertTrue(ControlPreset.thumb.showsKeepButton)
        XCTAssertTrue(ControlPreset.thumb.showsDeleteButton)
        XCTAssertFalse(ControlPreset.thumb.showsFavoriteButton)

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
        XCTAssertEqual(preferences.placement, .center)
        XCTAssertEqual(preferences.defaultDirection, .older)
    }

    func testRoundTripsThroughCodable() throws {
        let preferences = ControlPreferences(preset: .extended, placement: .left, defaultDirection: .newer)
        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(ControlPreferences.self, from: data)
        XCTAssertEqual(decoded, preferences)
    }

    func testInMemoryStorePersistsPreferences() {
        let store = InMemorySessionStore()
        XCTAssertEqual(store.loadPreferences(), .default)
        store.savePreferences(ControlPreferences(preset: .thumb, placement: .right))
        XCTAssertEqual(store.loadPreferences().preset, .thumb)
        XCTAssertEqual(store.loadPreferences().placement, .right)
    }
}
