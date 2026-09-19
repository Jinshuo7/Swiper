import XCTest

/// Smoke tests that drive the app against the in-memory fake library
/// (`-uiTestingFakeLibrary`), so they never touch real photos.
final class SwiperUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingFakeLibrary"]
        app.launch()
        return app
    }

    func testRecentStartsAViewerSession() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["entry.recent"].waitForExistence(timeout: 10))
        app.buttons["entry.recent"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["viewer.photo"].waitForExistence(timeout: 10))
    }

    func testQueueForDeletionReachesReviewAndResult() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["entry.recent"].waitForExistence(timeout: 10))
        app.buttons["entry.recent"].tap()

        let photo = app.descendants(matching: .any)["viewer.photo"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        photo.swipeLeft()
        for _ in 1..<24 {
            photo.swipeRight()
        }

        let review = app.buttons["viewer.reviewFinished"]
        XCTAssertTrue(review.waitForExistence(timeout: 10))
        review.tap()

        let delete = app.buttons["review.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 10))
        delete.tap()

        let confirm = app.alerts.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        confirm.tap()

        XCTAssertTrue(app.buttons["result.done"].waitForExistence(timeout: 10))
        app.buttons["result.done"].tap()
        XCTAssertTrue(app.buttons["entry.recent"].waitForExistence(timeout: 10))
    }

    func testSettingsChangesPresetWithoutCrashing() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 10))
        app.buttons["entry.settings"].tap()
        XCTAssertTrue(app.buttons["settings.preset.extended"].waitForExistence(timeout: 10))
        app.buttons["settings.preset.extended"].tap()
        app.buttons["settings.preset.thumb"].tap()
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["entry.recent"].waitForExistence(timeout: 10))
    }

    func testStatisticsScreenOpens() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["entry.statistics"].waitForExistence(timeout: 10))
        app.buttons["entry.statistics"].tap()
        XCTAssertTrue(app.staticTexts["Statistics"].waitForExistence(timeout: 10))
    }
}
