import XCTest

/// Smoke tests that drive the app against the in-memory fake library
/// (`-uiTestingFakeLibrary`), so they never touch real photos.
final class SwiperUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launchApp(
        showTutorial: Bool = false,
        persistentStore: Bool = false,
        resetStore: Bool = false,
        failDeletion: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uiTestingFakeLibrary",
            "-hasSeenSwipeTutorial", showTutorial ? "NO" : "YES",
        ]
        if persistentStore { app.launchArguments += ["-uiTestingPersistentStore"] }
        if resetStore { app.launchArguments += ["-uiTestingResetStore"] }
        if failDeletion { app.launchArguments += ["-uiTestingFailDeletion"] }
        app.launch()
        return app
    }

    private func photoElement(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["viewer.photo"]
    }

    private func tutorialElement(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["viewer.tutorial"]
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Starts a drag that ends *held* in place, captures the mid-gesture
    /// feedback, and only then releases. The wells are only visible while the
    /// gesture is live, so a screenshot after release could never show them.
    private func holdDrag(
        from start: XCUICoordinate,
        to end: XCUICoordinate,
        captureNamed name: String
    ) {
        let released = expectation(description: name)
        DispatchQueue.global(qos: .userInitiated).async {
            start.press(
                forDuration: 0.1,
                thenDragTo: end,
                withVelocity: .slow,
                thenHoldForDuration: 1.5
            )
            released.fulfill()
        }
        Thread.sleep(forTimeInterval: 0.8)
        capture(name)
        wait(for: [released], timeout: 20)
    }

    private func startViewer(_ app: XCUIApplication) -> XCUIElement {
        XCTAssertTrue(app.buttons["entry.recent"].waitForExistence(timeout: 10))
        app.buttons["entry.recent"].tap()
        let photo = app.descendants(matching: .any)["viewer.photo"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        return photo
    }

    func testRecentStartsAViewerSession() {
        let app = launchApp()
        _ = startViewer(app)
    }

    /// Every demo fixture is contained, never cropped to fill, and stays inside
    /// the screen. The demo library cycles landscape → portrait → square →
    /// panorama, so walking four photos covers all four proportions.
    func testViewerShowsWholePhotosWithoutCroppingOrOffscreenControls() {
        let app = launchApp()
        _ = startViewer(app)

        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(window.width, 0)
        XCTAssertGreaterThan(window.height, 0)

        let knownRatios: [CGFloat] = [4.0 / 3.0, 3.0 / 4.0, 1.0, 4.0]
        let fillRatio = window.width / window.height

        for step in 0..<4 {
            let photo = app.descendants(matching: .any)["viewer.photo"]
            XCTAssertTrue(photo.waitForExistence(timeout: 10), "photo \(step) never appeared")
            let frame = photo.frame

            XCTAssertTrue(
                window.contains(frame),
                "photo \(step) frame \(frame) escapes the screen \(window)"
            )
            XCTAssertLessThanOrEqual(frame.width, window.width + 0.5)
            XCTAssertLessThanOrEqual(frame.height, window.height + 0.5)

            let ratio = frame.width / frame.height
            XCTAssertTrue(
                knownRatios.contains { abs($0 - ratio) < 0.02 },
                "photo \(step) is shown at \(ratio), not one of the fixture proportions"
            )
            XCTAssertGreaterThan(
                abs(ratio - fillRatio),
                0.05,
                "photo \(step) was cropped to fill the screen instead of being contained"
            )
            XCTAssertEqual(frame.midX, window.midX, accuracy: 1, "photo \(step) is not centred")

            assertControlsInsideScreen(app, window: window)

            capture("Viewer — complete photo, fixture step \(step)")

            if step < 3 { photo.swipeRight() }
        }
    }

    // MARK: - Swipe feedback and teaching (#15)

    func testFirstPhotoTutorialExplainsAndReplaysFromSettings() {
        let app = launchApp(showTutorial: true)
        _ = startViewer(app)

        XCTAssertTrue(tutorialElement(app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nothing is deleted until you review and confirm."].exists)
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "saved as you make it")).firstMatch.exists,
            "the tutorial must explain that accepted work is saved"
        )
        capture("Tutorial — first photo, Swipe preset")

        app.buttons["viewer.tutorial.dismiss"].tap()
        XCTAssertFalse(tutorialElement(app).waitForExistence(timeout: 2))

        // Dismissed once: it does not return for the next photo.
        photoElement(app).swipeRight()
        XCTAssertFalse(tutorialElement(app).waitForExistence(timeout: 2))

        // Settings → How to use replays it.
        app.buttons["topbar.close"].tap()
        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 5))
        app.buttons["entry.settings"].tap()
        let howTo = app.buttons["settings.howToUse"]
        XCTAssertTrue(howTo.waitForExistence(timeout: 5))
        capture("Settings — How to use")
        howTo.tap()
        XCTAssertTrue(tutorialElement(app).waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["viewer.tutorial.dismiss"].label, "Got it")
    }

    func testTutorialWordingFollowsTheSelectedPreset() {
        let app = launchApp(showTutorial: true)
        app.buttons["entry.settings"].tap()
        app.buttons["settings.preset.thumb"].tap()
        app.buttons["Back"].firstMatch.tap()
        _ = startViewer(app)

        XCTAssertTrue(tutorialElement(app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Trash marks for deletion"].exists)
        XCTAssertFalse(
            app.staticTexts["Drag left to mark for deletion"].exists,
            "a button preset must not be told to swipe"
        )
    }

    func testPartialDragsShowFeedbackButDecideNothing() {
        let app = launchApp()
        let photo = startViewer(app)
        let before = photo.label

        let centre = photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        holdDrag(
            from: centre,
            to: centre.withOffset(CGVector(dx: -45, dy: 0)),
            captureNamed: "Partial left drag — below threshold"
        )
        XCTAssertFalse(app.buttons["viewer.review"].exists, "a short drag must not mark anything")
        XCTAssertEqual(photoElement(app).label, before)

        holdDrag(
            from: centre,
            to: centre.withOffset(CGVector(dx: 45, dy: 0)),
            captureNamed: "Partial right drag — below threshold"
        )
        XCTAssertEqual(photoElement(app).label, before, "a short drag must not keep anything")

        holdDrag(
            from: centre,
            to: centre.withOffset(CGVector(dx: -160, dy: 0)),
            captureNamed: "Left drag past threshold"
        )
        XCTAssertTrue(app.buttons["viewer.review"].waitForExistence(timeout: 5), "a released drag past the threshold marks")
    }

    func testVerticalDragDecidesNothing() {
        let app = launchApp()
        let photo = startViewer(app)
        let before = photo.label
        let centre = photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

        holdDrag(
            from: centre,
            to: centre.withOffset(CGVector(dx: 0, dy: -200)),
            captureNamed: "Vertical drag — no decision"
        )

        XCTAssertFalse(app.buttons["viewer.review"].exists)
        XCTAssertEqual(photoElement(app).label, before)
    }

    func testViewerKeepsAccessibleControlAlternatives() {
        let app = launchApp()
        _ = startViewer(app)

        for (identifier, label) in [
            ("topbar.close", "Close"),
            ("topbar.favorite", "Favorite"),
            ("topbar.undo", "Undo"),
        ] {
            let control = app.buttons[identifier]
            XCTAssertTrue(control.exists, "\(identifier) must exist as a button alternative")
            XCTAssertEqual(control.label, label)
        }
    }

    func testViewerNoLongerShowsThePermanentLowContrastHint() {
        let app = launchApp()
        _ = startViewer(app)
        XCTAssertFalse(app.staticTexts["◀ Queue deletion     Keep ▶     Tap ♡ to favorite"].exists)
        XCTAssertFalse(app.staticTexts["Queue deletion"].exists)
    }

    func testViewerShowsMarkedCountAndReachesReview() {
        let app = launchApp()
        let photo = startViewer(app)
        XCTAssertFalse(app.buttons["viewer.review"].exists)

        photo.swipeLeft()

        let review = app.buttons["viewer.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        XCTAssertEqual(review.label, "1 photo marked for deletion")
        XCTAssertTrue(app.staticTexts["Review · 1"].exists)

        review.tap()
        XCTAssertTrue(app.staticTexts["Review deletion"].waitForExistence(timeout: 5))
    }

    private func assertControlsInsideScreen(_ app: XCUIApplication, window: CGRect) {
        for identifier in ["topbar.close", "topbar.favorite", "topbar.undo"] {
            let control = app.buttons[identifier]
            XCTAssertTrue(control.exists, "\(identifier) is missing from the viewer")
            XCTAssertTrue(
                window.contains(control.frame),
                "\(identifier) frame \(control.frame) escapes the screen \(window)"
            )
        }
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

    // MARK: - Cross-session marks (#13)

    func testHomeOffersContinueSortingAndReviewAfterMarking() {
        let app = launchApp()
        let photo = startViewer(app)
        let markedLabel = photo.label
        photo.swipeLeft()

        app.buttons["topbar.close"].tap()

        let review = app.buttons["entry.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        XCTAssertEqual(review.label, "Review & delete · 1")
        XCTAssertTrue(app.buttons["entry.resume"].label.contains("Continue sorting"))
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "marked for deletion")).firstMatch.exists,
            "home must say the photo is marked, not deleted"
        )
        XCTAssertTrue(app.staticTexts["Nothing deleted yet."].exists || app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Nothing deleted yet.")).firstMatch.exists)
        XCTAssertFalse(markedLabel.isEmpty)
    }

    func testReviewFromHomeReachesTheSameMarks() {
        let app = launchApp()
        let photo = startViewer(app)
        photo.swipeLeft()
        app.buttons["topbar.close"].tap()

        let review = app.buttons["entry.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        review.tap()

        XCTAssertTrue(app.staticTexts["Review deletion"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 photo marked for deletion"].exists)
        XCTAssertTrue(app.buttons["review.delete"].exists)

        app.buttons["review.back"].tap()
        XCTAssertTrue(app.buttons["entry.review"].waitForExistence(timeout: 5))
    }

    func testMarkedPhotoIsSkippedAfterRelaunchAndInANewMode() {
        let app = launchApp(persistentStore: true, resetStore: true)
        let photo = startViewer(app)
        let markedLabel = photo.label
        photo.swipeLeft()
        app.buttons["topbar.close"].tap()
        XCTAssertTrue(app.buttons["entry.review"].waitForExistence(timeout: 5))

        app.terminate()
        let relaunched = launchApp(persistentStore: true)
        XCTAssertTrue(relaunched.buttons["entry.recent"].waitForExistence(timeout: 10))
        XCTAssertTrue(relaunched.buttons["entry.review"].exists, "marks survive a relaunch")

        // Continue sorting resumes at the saved position, never on the mark.
        relaunched.buttons["entry.resume"].tap()
        let resumed = photoElement(relaunched)
        XCTAssertTrue(resumed.waitForExistence(timeout: 10))
        XCTAssertNotEqual(resumed.label, markedLabel)

        // A brand-new mode also skips it.
        relaunched.buttons["topbar.close"].tap()
        XCTAssertTrue(relaunched.buttons["entry.tumbler"].waitForExistence(timeout: 5))
        relaunched.buttons["entry.tumbler"].tap()
        let tumblerPhoto = photoElement(relaunched)
        XCTAssertTrue(tumblerPhoto.waitForExistence(timeout: 10))
        XCTAssertNotEqual(tumblerPhoto.label, markedLabel)
    }

    // MARK: - Review and deletion recovery (#14)

    func testCancellingTheInAppConfirmationKeepsEveryMark() {
        let app = launchApp()
        let photo = startViewer(app)
        photo.swipeLeft()
        app.buttons["viewer.review"].tap()

        let delete = app.buttons["review.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()

        let cancel = app.alerts.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()

        XCTAssertTrue(app.staticTexts["Review deletion"].exists)
        XCTAssertTrue(app.staticTexts["1 photo marked for deletion"].exists)
        XCTAssertTrue(app.buttons["review.delete"].exists)
    }

    func testInspectionCanRestoreASingleMarkBackToTheGrid() {
        let app = launchApp()
        let photo = startViewer(app)
        photo.swipeLeft()
        app.buttons["viewer.review"].tap()

        let cell = app.descendants(matching: .any)["review.cell.0"]
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()

        let restore = app.buttons["inspect.restore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()

        XCTAssertTrue(app.staticTexts["Nothing is marked for deletion"].waitForExistence(timeout: 5))
    }

    func testACancelledSystemDeletionKeepsMarksAndReportsNoDeletion() {
        let app = launchApp(failDeletion: true)
        let photo = startViewer(app)
        photo.swipeLeft()
        app.buttons["viewer.review"].tap()

        let delete = app.buttons["review.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        app.alerts.buttons["Delete"].tap()

        XCTAssertTrue(app.staticTexts["Nothing was deleted"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "stayed marked")).firstMatch.exists,
            "unsuccessful items must be reported as still marked"
        )

        let continuation = app.buttons["result.done"]
        XCTAssertTrue(continuation.waitForExistence(timeout: 5))
        continuation.tap()

        let review = app.buttons["viewer.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        XCTAssertEqual(review.label, "1 photo marked for deletion")
        XCTAssertEqual(review.value as? String, "Nothing deleted yet.")

        app.buttons["topbar.close"].tap()
        XCTAssertEqual(app.buttons["entry.review"].label, "Review & delete · 1")
    }

    func testSuccessfulDeletionReturnsToTheSortingPosition() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["entry.recent"].waitForExistence(timeout: 10))
        app.buttons["entry.recent"].tap()

        let photo = photoElement(app)
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        photo.swipeLeft()

        app.buttons["viewer.review"].tap()
        let delete = app.buttons["review.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        app.alerts.buttons["Delete"].tap()

        let continuation = app.buttons["result.done"]
        XCTAssertTrue(continuation.waitForExistence(timeout: 10))
        XCTAssertTrue(continuation.label.contains("Continue sorting"))
        continuation.tap()

        XCTAssertTrue(photoElement(app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["viewer.review"].exists)
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
