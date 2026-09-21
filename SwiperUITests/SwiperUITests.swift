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
        failDeletion: Bool = false,
        failFirstDecisionSave: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uiTestingFakeLibrary",
            "-hasSeenSwipeTutorial", showTutorial ? "NO" : "YES",
        ]
        if persistentStore { app.launchArguments += ["-uiTestingPersistentStore"] }
        if resetStore { app.launchArguments += ["-uiTestingResetStore"] }
        if failDeletion { app.launchArguments += ["-uiTestingFailDeletion"] }
        if failFirstDecisionSave { app.launchArguments += ["-uiTestingFailFirstDecisionSave"] }
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

    /// A thread-safe slot for the screenshot taken while a drag is held.
    private final class ScreenshotBox: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: XCUIScreenshot?

        var screenshot: XCUIScreenshot? {
            get { lock.withLock { stored } }
            set { lock.withLock { stored = newValue } }
        }
    }

    /// Starts a drag that ends *held* in place, captures the mid-gesture
    /// feedback, and only then releases.
    ///
    /// `press(...)` asserts that it runs on the main thread, and it does not
    /// return until the drag is released — so the capture has to happen
    /// concurrently, on a background queue, while the main thread is inside the
    /// held gesture. The wells are only visible during that hold, so a
    /// screenshot taken after release could never show them.
    private func holdDrag(
        from start: XCUICoordinate,
        to end: XCUICoordinate,
        captureNamed name: String
    ) {
        let box = ScreenshotBox()
        let captured = expectation(description: "captured \(name)")
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.6) {
            box.screenshot = XCUIScreen.main.screenshot()
            captured.fulfill()
        }

        start.press(
            forDuration: 0.1,
            thenDragTo: end,
            withVelocity: .slow,
            thenHoldForDuration: 1.5
        )

        wait(for: [captured], timeout: 20)
        guard let screenshot = box.screenshot else {
            return XCTFail("Could not capture \(name) while the drag was held")
        }
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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

    // MARK: - Interruption (airplane / Uber)

    /// The interrupted-session case end to end: sort, have the app killed, come
    /// back. Nothing may be lost, and home must be unambiguous about what can be
    /// resumed and what can be reviewed.
    func testKillingTheAppMidSessionRestoresPositionMarksAndUndo() {
        let app = launchApp(persistentStore: true, resetStore: true)
        let photo = startViewer(app)

        photo.swipeRight()                       // keep the newest
        let markedLabel = photoElement(app).label
        photoElement(app).swipeLeft()            // mark this one
        let positionAtKill = photoElement(app).label
        XCTAssertNotEqual(positionAtKill, markedLabel)

        app.terminate()

        let relaunched = launchApp(persistentStore: true)
        XCTAssertTrue(relaunched.buttons["entry.resume"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            relaunched.buttons["entry.resume"].label.contains("Continue sorting"),
            "home must offer to continue the interrupted session"
        )
        XCTAssertEqual(
            relaunched.buttons["entry.review"].label,
            "Review & delete · 1",
            "the mark made before the kill must still be there"
        )

        relaunched.buttons["entry.resume"].tap()
        let resumed = photoElement(relaunched)
        XCTAssertTrue(resumed.waitForExistence(timeout: 10))
        XCTAssertEqual(resumed.label, positionAtKill, "sorting must resume at the same photo")

        // Undo survived too, and still reverses the mark made before the kill.
        relaunched.buttons["control.undo"].tap()
        XCTAssertFalse(
            relaunched.buttons["viewer.review"].waitForExistence(timeout: 3),
            "undo after a kill must still remove the mark"
        )
        let afterUndo = photoElement(relaunched)
        XCTAssertTrue(afterUndo.waitForExistence(timeout: 5))
        XCTAssertEqual(afterUndo.label, markedLabel, "undo returns to the photo it marked")
    }

    // MARK: - Start Here (user report, 2026-09-21)

    func testStartHereExplainsItselfAndGroupsTheLibraryByMonth() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["entry.startHere"].waitForExistence(timeout: 10))
        app.buttons["entry.startHere"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["startHere.explanation"].waitForExistence(timeout: 10),
            "Start Here must say what it is for"
        )
        let headers = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "startHere.month."))
        XCTAssertGreaterThanOrEqual(headers.count, 2, "the library should be grouped into months")
        XCTAssertTrue(app.descendants(matching: .any)["startHere.jump"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["startHere.sort"].exists)
        capture("Start Here — explanation, months, jump and sort")

        // Newest first by default: toggling must actually reorder the sections.
        let firstNewest = headers.element(boundBy: 0).identifier
        let toggle = app.descendants(matching: .any)["startHere.sort"]
        toggle.tap()
        XCTAssertTrue(app.staticTexts["Oldest first"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(
            headers.element(boundBy: 0).identifier,
            firstNewest,
            "switching to oldest first should change which month is at the top"
        )
        capture("Start Here — oldest first")
    }

    func testStartHereCanJumpStraightToAMonth() {
        let app = launchApp()
        app.buttons["entry.startHere"].tap()

        let jump = app.descendants(matching: .any)["startHere.jump"]
        XCTAssertTrue(jump.waitForExistence(timeout: 10))
        jump.tap()

        // The oldest year in the fixed fixtures; the gap from the newest month
        // is far more than one screen, so scrolling could not have found it.
        let oldest = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "2023")).firstMatch
        XCTAssertTrue(oldest.waitForExistence(timeout: 5), "the month menu should list older months")
        let chosen = oldest.label
        oldest.tap()

        XCTAssertTrue(
            app.staticTexts[chosen].waitForExistence(timeout: 5),
            "jumping should bring \(chosen) on screen"
        )
        capture("Start Here — jumped to \(chosen)")
    }

    func testChoosingAPhotoStartsSortingAtThatPhoto() {
        let app = launchApp()
        app.buttons["entry.startHere"].tap()

        // fake-23 is the newest photo and a 4:1 panorama, so the viewer's own
        // aspect ratio proves the session started where it was chosen.
        let cell = app.descendants(matching: .any)["startHere.cell.fake-23"]
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        cell.tap()

        let photo = photoElement(app)
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        let ratio = photo.frame.width / photo.frame.height
        XCTAssertEqual(ratio, 4.0, accuracy: 0.02, "sorting should have started at the chosen photo")
    }

    // MARK: - Control rail stability (user report, 2026-09-21)

    /// Reaches Settings from wherever the test is — including from inside the
    /// viewer — chooses the rail, and returns home. The presence of
    /// `entry.settings` cannot be used to decide whether we are already there,
    /// because it exists on the entry screen too.
    private func useRail(_ app: XCUIApplication, _ rail: String) {
        if app.buttons["control.close"].exists {
            app.buttons["control.close"].tap()
        }
        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 10))
        app.buttons["entry.settings"].tap()
        let option = app.buttons["settings.rail.\(rail)"]
        XCTAssertTrue(option.waitForExistence(timeout: 10), "no rail option \(rail)")
        option.tap()
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["entry.recent"].waitForExistence(timeout: 10))
    }

    private func useButtonPreset(_ app: XCUIApplication, _ preset: String) {
        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 10))
        app.buttons["entry.settings"].tap()
        let choice = app.buttons["settings.preset.\(preset)"]
        XCTAssertTrue(choice.waitForExistence(timeout: 10))
        choice.tap()
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["entry.recent"].waitForExistence(timeout: 10))
    }

    /// The controls are physical targets: they must sit in the same place for a
    /// panorama, a square, a portrait and a landscape photo. A rail anchored to
    /// the photo instead of to the screen fails this.
    func testControlRailDoesNotMoveBetweenPhotos() {
        let app = launchApp()
        useButtonPreset(app, "thumb")
        _ = startViewer(app)

        var frames: [CGRect] = []
        for step in 0..<4 {
            let keep = app.buttons["control.keep"]
            XCTAssertTrue(keep.waitForExistence(timeout: 10), "no Keep control at step \(step)")
            frames.append(keep.frame)
            capture("Controls — fixture step \(step)")
            if step < 3 { photoElement(app).swipeRight() }
        }

        for (index, frame) in frames.enumerated().dropFirst() {
            XCTAssertEqual(
                frame,
                frames[0],
                "the rail moved between photos: step 0 at \(frames[0]), step \(index) at \(frame)"
            )
        }

        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.contains(frames[0]), "the rail must stay on screen")
        XCTAssertGreaterThan(
            frames[0].midY,
            window.height * 0.8,
            "a bottom rail must sit in the lower part of the screen, got \(frames[0]) in \(window)"
        )
    }

    /// The rail is the handedness choice: it must be able to run down either
    /// side, with Close at the top and Keep at the bottom.
    func testControlRailCanMoveToEitherSideRail() {
        let app = launchApp()
        useButtonPreset(app, "thumb")
        useRail(app, "trailing")
        _ = startViewer(app)

        let close = app.buttons["control.close"]
        let keep = app.buttons["control.keep"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        XCTAssertTrue(keep.exists)

        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(close.frame.midX, window.midX, "the right rail must be on the right")
        XCTAssertLessThan(close.frame.midY, keep.frame.midY, "Close must sit above Keep on a vertical rail")
        XCTAssertTrue(window.contains(close.frame) && window.contains(keep.frame))
        capture("Controls — right side rail")

        useRail(app, "leading")
        _ = startViewer(app)
        let leftClose = app.buttons["control.close"]
        XCTAssertTrue(leftClose.waitForExistence(timeout: 10))
        XCTAssertLessThan(leftClose.frame.midX, window.midX, "the left rail must be on the left")
        XCTAssertLessThan(leftClose.frame.midY, app.buttons["control.keep"].frame.midY)
        XCTAssertTrue(window.contains(leftClose.frame))
        capture("Controls — left side rail")
    }

    /// The order half of the handedness choice: with Keep first the decisions
    /// move to the other end of the rail, which is what a left thumb on a bottom
    /// rail needs.
    func testTheRailOrderCanBeFlipped() {
        let app = launchApp()
        useButtonPreset(app, "thumb")
        _ = startViewer(app)

        let closeFirst = app.buttons["control.close"].frame
        let keepFirst = app.buttons["control.keep"].frame
        XCTAssertLessThan(closeFirst.midX, keepFirst.midX, "Close should start at the leading end")

        app.buttons["control.close"].tap()
        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 10))
        app.buttons["entry.settings"].tap()
        let flipped = app.buttons["settings.order.keepFirst"]
        XCTAssertTrue(flipped.waitForExistence(timeout: 10))
        flipped.tap()
        app.buttons["Back"].firstMatch.tap()

        _ = startViewer(app)
        let newClose = app.buttons["control.close"]
        XCTAssertTrue(newClose.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(
            newClose.frame.midX,
            app.buttons["control.keep"].frame.midX,
            "with Keep first the decisions should be at the leading end"
        )
        capture("Controls — Keep first order")
    }

    /// A vertical rail reserves a lane: the photo is fitted beside it, not
    /// underneath the buttons.
    func testASideRailDoesNotCoverThePhoto() {
        let app = launchApp()
        useButtonPreset(app, "thumb")
        useRail(app, "trailing")
        _ = startViewer(app)

        let photo = photoElement(app)
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        let close = app.buttons["control.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))

        let overlap = photo.frame.intersection(close.frame)
        XCTAssertTrue(
            overlap.isNull || overlap.width < 1 || overlap.height < 1,
            "the rail overlaps the photo: photo \(photo.frame), Close \(close.frame)"
        )
    }

    /// Only the rail choice may move a control: the preset changes which
    /// controls exist, never where they are.
    func testSwitchingPresetDoesNotMoveTheRail() {
        let app = launchApp()
        useButtonPreset(app, "thumb")
        _ = startViewer(app)

        let before = app.buttons["control.close"].frame
        app.buttons["control.close"].tap()   // back home
        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 5))
        useButtonPreset(app, "extended")
        _ = startViewer(app)

        XCTAssertEqual(
            app.buttons["control.close"].frame,
            before,
            "switching preset moved the rail"
        )
    }

    /// Marking a photo makes the Review bar appear. That must not shove the
    /// decision controls somewhere else mid-session.
    func testControlRailDoesNotMoveWhenAMarkAppears() {
        let app = launchApp()
        useButtonPreset(app, "thumb")
        _ = startViewer(app)

        let keep = app.buttons["control.keep"]
        XCTAssertTrue(keep.waitForExistence(timeout: 10))
        let before = keep.frame

        app.buttons["control.delete"].tap()
        XCTAssertTrue(app.buttons["viewer.review"].waitForExistence(timeout: 5), "the mark should be showing")

        XCTAssertEqual(
            app.buttons["control.keep"].frame,
            before,
            "the Review bar appearing moved the decision controls"
        )
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
        app.buttons["control.close"].tap()
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
            ("control.close", "Close"),
            ("control.favorite", "Favorite"),
            ("control.undo", "Undo"),
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

    /// The fake library cycles a Live Photo every fifth asset (indices 4, 9, 14,
    /// 19), and Recent starts at index 23 walking older, so the fifth photo is
    /// the first Live Photo.
    func testLivePhotosAreLabelledInTheViewer() {
        let app = launchApp()
        _ = startViewer(app)

        let badge = app.descendants(matching: .any)["viewer.liveBadge"]
        XCTAssertFalse(badge.exists, "the first fixture is a still, so it must not be labelled")

        var swipes = 0
        while !badge.exists && swipes < 6 {
            photoElement(app).swipeRight()
            swipes += 1
        }

        XCTAssertTrue(badge.exists, "a Live Photo must be labelled in the viewer")
        XCTAssertEqual(badge.label, "Live Photo")
        XCTAssertTrue(
            photoElement(app).label.contains("Live Photo"),
            "the spoken description must name the kind too, got \(photoElement(app).label)"
        )
        capture("Viewer — Live Photo labelled")
    }

    private func assertControlsInsideScreen(_ app: XCUIApplication, window: CGRect) {
        for identifier in ["control.close", "control.favorite", "control.undo"] {
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

        // Swiper adds no dialog of its own; the fake library stands in for
        // PhotoKit, whose system prompt is the only confirmation in the real app.
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

        app.buttons["control.close"].tap()

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
        app.buttons["control.close"].tap()

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
        app.buttons["control.close"].tap()
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
        relaunched.buttons["control.close"].tap()
        XCTAssertTrue(relaunched.buttons["entry.tumbler"].waitForExistence(timeout: 5))
        relaunched.buttons["entry.tumbler"].tap()
        let tumblerPhoto = photoElement(relaunched)
        XCTAssertTrue(tumblerPhoto.waitForExistence(timeout: 10))
        XCTAssertNotEqual(tumblerPhoto.label, markedLabel)
    }

    // MARK: - Visible save failure and retry (#12)

    func testAFailedSaveShowsRetryAndDoesNotAdvanceTheSession() {
        let app = launchApp(failFirstDecisionSave: true)
        let photo = startViewer(app)
        let before = photo.label

        photo.swipeLeft()

        let banner = app.descendants(matching: .any)["saveFailure.banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "a failed save must be visible")
        XCTAssertTrue(app.staticTexts["Couldn't save your last decision"].exists)
        XCTAssertEqual(photoElement(app).label, before, "the session must not advance before the decision is saved")
        XCTAssertFalse(app.buttons["viewer.review"].exists, "an unsaved mark must not appear")

        let retry = app.buttons["Retry"]
        XCTAssertTrue(retry.exists)
        capture("Save failure — Retry offered")
        retry.tap()

        XCTAssertFalse(banner.waitForExistence(timeout: 3), "a successful retry clears the banner")
        XCTAssertTrue(app.buttons["viewer.review"].waitForExistence(timeout: 5), "the retried decision is acknowledged")
        XCTAssertNotEqual(photoElement(app).label, before)
    }

    // MARK: - Review and deletion recovery (#14)

    /// Deleting asks once, not twice. Swiper adds no dialog of its own: the only
    /// confirmation is PhotoKit's system prompt, which the fake library stands in
    /// for. What that dialog used to explain is on the review screen instead.
    func testDeletionAsksOnlyTheSystemConfirmationAndExplainsItself() {
        let app = launchApp()
        let photo = startViewer(app)
        photo.swipeLeft()
        app.buttons["viewer.review"].tap()

        XCTAssertTrue(
            app.staticTexts["Your iPhone asks you to confirm before anything is removed. Photos you restored stay put."]
                .waitForExistence(timeout: 5),
            "the review screen must say what the commit does, now that Swiper has no alert"
        )

        let delete = app.buttons["review.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()

        // No Swiper dialog appears; the outcome follows the single tap.
        XCTAssertTrue(app.buttons["result.done"].waitForExistence(timeout: 10))
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

        app.buttons["control.close"].tap()
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

    /// Statistics is no longer on the main screen; it lives inside Settings,
    /// with the Wi-Fi-looking bar glyph replaced.
    func testStatisticsIsReachedFromSettings() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["entry.statistics"].exists, "statistics must not sit on the main screen")
        app.buttons["entry.settings"].tap()

        let statistics = app.buttons["settings.statistics"]
        XCTAssertTrue(statistics.waitForExistence(timeout: 10))
        capture("Settings — statistics row")
        statistics.tap()
        XCTAssertTrue(app.staticTexts["Statistics"].waitForExistence(timeout: 10))
    }
}
