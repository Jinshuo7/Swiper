import XCTest

final class ViewerDockPrototypeTests: XCTestCase {
    func testMovingFromTrashDoesNotMakeADecision() {
        let app = XCUIApplication()
        app.launchArguments = ["-viewerDockPrototype", "-uiTestingFakeLibrary"]
        app.launch()
        let dock = app.descendants(matching: .any)["prototype.dock"].firstMatch
        XCTAssertTrue(dock.waitForExistence(timeout: 10))
        // Trash is the centre control. First prove a normal tap works.
        dock.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["prototype.status"].label.contains("1 decisions · 1 marked"))
        // Drag from the very same control to the right magnetic stop.
        let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.72))
            .withOffset(CGVector(dx: -46, dy: 0))
        dock.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: destination)
        let landed = NSPredicate(format: "value CONTAINS %@", "right, 1 sample items marked")
        expectation(for: landed, evaluatedWith: dock)
        waitForExpectations(timeout: 4)
        XCTAssertTrue(app.staticTexts["prototype.status"].label.contains("no decision made"))
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "prototype-docked-right"
        capture.lifetime = .keepAlways
        add(capture)
    }
}
