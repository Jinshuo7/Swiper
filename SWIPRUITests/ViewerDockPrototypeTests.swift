import XCTest

final class ViewerDockPrototypeTests: XCTestCase {
    func testMovingFromTrashDoesNotMakeADecision() {
        let app = XCUIApplication()
        app.launchArguments = ["-viewerDockPrototype", "-uiTestingFakeLibrary"]
        AppLaunchHandoff.launch(app, firstScreen: app.otherElements["prototype.dock"])
        let dock = app.otherElements["prototype.dock"].firstMatch
        XCTAssertTrue(dock.waitForExistence(timeout: 10))
        let home = app.buttons["prototype.home"]
        let review = app.buttons["prototype.review"]
        XCTAssertEqual(home.frame, review.frame.offsetBy(dx: home.frame.minX - review.frame.minX, dy: 0))
        XCTAssertEqual(home.frame.midX, app.frame.width - review.frame.midX, accuracy: 0.5)
        XCTAssertEqual(dock.frame.midX + 25.5, app.frame.midX, accuracy: 0.5)
        XCTAssertFalse(app.staticTexts["PHOTO"].exists)
        // Trash sits left of the centred Trash/Keep pair. First prove a normal tap works.
        let trash = dock.coordinate(withNormalizedOffset: CGVector(dx: 0.44, dy: 0.5))
        trash.tap()
        XCTAssertTrue((dock.value as? String)?.contains("1 sample items marked") == true)
        // Drag from the very same control to the right magnetic stop.
        let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.72))
            .withOffset(CGVector(dx: -46, dy: 0))
        trash.press(forDuration: 0.05, thenDragTo: destination)
        let landed = NSPredicate(format: "value CONTAINS %@", "right, 1 sample items marked")
        expectation(for: landed, evaluatedWith: dock)
        waitForExpectations(timeout: 4)
        XCTAssertTrue((dock.value as? String)?.contains("1 sample items marked") == true)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "prototype-docked-right"
        capture.lifetime = .keepAlways
        add(capture)
    }
}
