import XCTest

/// Smoke tests that drive the app against the in-memory fake library
/// (`-uiTestingFakeLibrary`), so they never touch real photos.
final class SWIPRUITests: XCTestCase {
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

    private func clusterElement(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["viewer.cluster"]
    }

    private func gripElement(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["viewer.grip"]
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

    /// Opens the one entry action and starts the newest-first traversal, which
    /// is where every viewer test begins.
    private func startViewer(_ app: XCUIApplication) -> XCUIElement {
        XCTAssertTrue(app.buttons["entry.start"].waitForExistence(timeout: 10))
        app.buttons["entry.start"].tap()
        let newest = app.buttons["choosePhoto.newest"]
        XCTAssertTrue(newest.waitForExistence(timeout: 10))
        newest.tap()
        let photo = photoElement(app)
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        return photo
    }

    func testNewestStartsAViewerSession() {
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
            let photo = photoElement(app)
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
        XCTAssertEqual(relaunched.buttons["entry.resume"].label, "Resume")
        XCTAssertEqual(
            relaunched.buttons["entry.review"].label,
            "1 photo marked for deletion",
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

    // MARK: - Choose a photo

    func testChoosePhotoExplainsItselfAndGroupsTheLibraryByMonth() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["entry.start"].waitForExistence(timeout: 10))
        app.buttons["entry.start"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["choosePhoto.explanation"].waitForExistence(timeout: 10),
            "Choose a photo must say what it is for"
        )
        XCTAssertTrue(app.buttons["choosePhoto.newest"].exists, "Newest lives inside Choose a photo")
        XCTAssertTrue(app.buttons["choosePhoto.random"].exists, "Random lives inside Choose a photo")
        let headers = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "choosePhoto.month."))
        XCTAssertGreaterThanOrEqual(headers.count, 2, "the library should be grouped into months")
        XCTAssertTrue(app.descendants(matching: .any)["choosePhoto.jump"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["choosePhoto.sort"].exists)
        capture("Choose a photo — explanation, Newest/Random, months")

        // Newest first by default: toggling must actually reorder the sections.
        let firstNewest = headers.element(boundBy: 0).identifier
        let toggle = app.descendants(matching: .any)["choosePhoto.sort"]
        toggle.tap()
        XCTAssertTrue(app.staticTexts["Oldest first"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(
            headers.element(boundBy: 0).identifier,
            firstNewest,
            "switching to oldest first should change which month is at the top"
        )
        capture("Choose a photo — oldest first")
    }

    func testChoosePhotoCanJumpStraightToAMonth() {
        let app = launchApp()
        app.buttons["entry.start"].tap()

        let jump = app.descendants(matching: .any)["choosePhoto.jump"]
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
        capture("Choose a photo — jumped to \(chosen)")
    }

    func testChoosingAPhotoStartsSortingAtThatPhoto() {
        let app = launchApp()
        app.buttons["entry.start"].tap()

        // fake-23 is the newest photo and a 4:1 panorama, so the viewer's own
        // aspect ratio proves the session started where it was chosen.
        let cell = app.descendants(matching: .any)["choosePhoto.cell.fake-23"]
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        cell.tap()

        let photo = photoElement(app)
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        let ratio = photo.frame.width / photo.frame.height
        XCTAssertEqual(ratio, 4.0, accuracy: 0.02, "sorting should have started at the chosen photo")
    }

    // MARK: - Fixed control positions and the puck move

    /// What the cluster says about where it is docked.
    private func clusterDock(_ app: XCUIApplication) -> String {
        (clusterElement(app).value as? String) ?? ""
    }

    /// Drags the three-dot grip to a screen point. The puck follows the finger,
    /// so the release lands in whichever slot contains that point.
    private func dragGrip(_ app: XCUIApplication, to point: CGPoint) {
        let grip = gripElement(app)
        XCTAssertTrue(grip.waitForExistence(timeout: 10), "there is no grip to drag")
        XCTAssertLessThan(clusterElement(app).frame.width, app.windows.firstMatch.frame.width, "viewer.cluster should be the cluster")
        let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: point.x, dy: point.y))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
        // Let the landing animation settle before the next frame is read.
        usleep(600_000)
    }

    private func bottomTarget(_ app: XCUIApplication) -> CGPoint {
        let window = app.windows.firstMatch.frame
        return CGPoint(x: window.midX, y: window.height * 0.88)
    }

    private func leftTarget(_ app: XCUIApplication) -> CGPoint {
        let window = app.windows.firstMatch.frame
        return CGPoint(x: window.minX + 44, y: window.height * 0.62)
    }

    private func rightTarget(_ app: XCUIApplication) -> CGPoint {
        let window = app.windows.firstMatch.frame
        return CGPoint(x: window.maxX - 44, y: window.height * 0.62)
    }

    /// The three buttons are one column when the cluster is at a side, and one
    /// row at the bottom.
    private func assertClusterIsAColumn(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let delete = app.buttons["control.delete"]
        let undo = app.buttons["control.undo"]
        let keep = app.buttons["control.keep"]
        for control in [delete, undo, keep] {
            XCTAssertTrue(control.exists, "a control is missing from the cluster", file: file, line: line)
        }
        XCTAssertEqual(delete.frame.midX, undo.frame.midX, accuracy: 1, "a column lines up", file: file, line: line)
        XCTAssertEqual(undo.frame.midX, keep.frame.midX, accuracy: 1, "a column lines up", file: file, line: line)
        XCTAssertLessThan(delete.frame.midY, keep.frame.midY, "Trash and Keep keep their order", file: file, line: line)
        XCTAssertTrue(
            undo.frame.midY < delete.frame.midY || undo.frame.midY > keep.frame.midY,
            "Undo sits at an outer end of the column, not between Trash and Keep",
            file: file,
            line: line
        )
    }

    private func assertClusterIsARow(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let delete = app.buttons["control.delete"]
        let undo = app.buttons["control.undo"]
        let keep = app.buttons["control.keep"]
        XCTAssertEqual(delete.frame.midY, undo.frame.midY, accuracy: 1, "a row lines up", file: file, line: line)
        XCTAssertEqual(undo.frame.midY, keep.frame.midY, accuracy: 1, "a row lines up", file: file, line: line)
        XCTAssertLessThan(delete.frame.midX, keep.frame.midX, "Trash and Keep keep their order", file: file, line: line)
        XCTAssertTrue(
            undo.frame.midX < delete.frame.midX || undo.frame.midX > keep.frame.midX,
            "Undo sits at an outer end of the row, not between Trash and Keep",
            file: file,
            line: line
        )
    }

    /// The cluster starts as a bottom row and can be moved to either side, where
    /// it becomes a column. Releasing over no slot leaves it exactly where it
    /// was, and a move never decides anything.
    func testTheGripMovesTheClusterToEachFixedPosition() {
        let app = launchApp()
        _ = startViewer(app)
        assertClusterIsARow(app)
        let window = app.windows.firstMatch.frame

        // The tray is centred on the width and sits low. The grip leads the
        // row, so the three buttons sit a little to its right.
        XCTAssertEqual(clusterElement(app).frame.midX, window.midX, accuracy: 6, "the bottom cluster is centred on the width")
        let undoAtBottom = app.buttons["control.undo"].frame
        XCTAssertGreaterThan(undoAtBottom.midY, window.height * 0.8, "the bottom row sits low")
        let photoBefore = photoElement(app).label
        capture("Controls — bottom centre")

        dragGrip(app, to: leftTarget(app))
        XCTAssertEqual(clusterDock(app), "Docked left edge")
        XCTAssertLessThan(app.buttons["control.keep"].frame.midX, window.midX, "the left column sits on the left")
        assertClusterIsAColumn(app)
        capture("Controls — left edge column")

        dragGrip(app, to: rightTarget(app))
        XCTAssertEqual(clusterDock(app), "Docked right edge")
        XCTAssertGreaterThan(app.buttons["control.keep"].frame.midX, window.midX, "the right column sits on the right")
        assertClusterIsAColumn(app)
        capture("Controls — right edge column")

        dragGrip(app, to: bottomTarget(app))
        XCTAssertEqual(clusterDock(app), "Docked bottom")
        assertClusterIsARow(app)
        capture("Controls — bottom centre again")

        // Moving the cluster is not a decision, however the grab lands.
        XCTAssertEqual(photoElement(app).label, photoBefore, "moving the cluster must not decide anything")
        XCTAssertFalse(app.buttons["viewer.review"].exists, "moving the cluster must not mark the photo")
    }

    /// A release that is over none of the three slots changes nothing.
    func testAReleaseAwayFromEverySlotChangesNothing() {
        let app = launchApp()
        _ = startViewer(app)
        let before = app.buttons["control.keep"].frame
        let dock = clusterDock(app)

        // The middle of the screen, above every slot.
        dragGrip(app, to: CGPoint(x: app.windows.firstMatch.frame.midX, y: app.windows.firstMatch.frame.height * 0.3))

        XCTAssertEqual(clusterDock(app), dock, "a release over no slot must not move the cluster")
        XCTAssertEqual(app.buttons["control.keep"].frame, before, "a release over no slot must not move the cluster")
    }

    /// The puck move is the grip's alone: a swipe on the photo decides nothing
    /// about the controls.
    func testAPlainSwipeNeverMovesTheCluster() {
        let app = launchApp()
        let photo = startViewer(app)
        let before = app.buttons["control.keep"].frame
        let dock = clusterDock(app)

        photo.swipeRight()
        XCTAssertEqual(clusterDock(app), dock, "a swipe moved the cluster")
        XCTAssertEqual(app.buttons["control.keep"].frame, before, "a swipe moved the cluster")
    }

    /// Chrome never moves the photo (ADR-0006): the fitted frame is identical at
    /// all three positions and throughout a move.
    func testThePhotoFrameIsIdenticalAtEveryControlPosition() {
        let app = launchApp()
        _ = startViewer(app)

        let atBottom = photoElement(app).frame
        dragGrip(app, to: leftTarget(app))
        XCTAssertEqual(clusterDock(app), "Docked left edge")
        let atLeft = photoElement(app).frame
        dragGrip(app, to: rightTarget(app))
        XCTAssertEqual(clusterDock(app), "Docked right edge")
        let atRight = photoElement(app).frame

        XCTAssertEqual(atLeft, atBottom, "the photo moved when the cluster went left")
        XCTAssertEqual(atRight, atBottom, "the photo moved when the cluster went right")
    }

    /// The controls are physical targets: they must sit in the same place for a
    /// panorama, a square, a portrait and a landscape photo.
    func testTheClusterKeepsItsPlaceBetweenPhotos() {
        let app = launchApp()
        _ = startViewer(app)

        var frames: [CGRect] = []
        for step in 0..<4 {
            let keep = app.buttons["control.keep"]
            XCTAssertTrue(keep.waitForExistence(timeout: 10), "no Keep control at step \(step)")
            frames.append(keep.frame)
            capture("Controls — fixture step \(step)")
            if step < 3 { keep.tap() }
        }

        for (index, frame) in frames.enumerated().dropFirst() {
            XCTAssertEqual(frame, frames[0], "the cluster moved between photos: step 0 at \(frames[0]), step \(index) at \(frame)")
        }
    }

    /// Marking a photo makes the Review chip appear. That must not shove the
    /// decision controls somewhere else mid-session.
    func testTheClusterDoesNotMoveWhenAMarkAppears() {
        let app = launchApp()
        _ = startViewer(app)

        let keep = app.buttons["control.keep"]
        XCTAssertTrue(keep.waitForExistence(timeout: 10))
        let before = keep.frame

        app.buttons["control.delete"].tap()
        XCTAssertTrue(app.buttons["viewer.review"].waitForExistence(timeout: 5), "the mark should be showing")

        XCTAssertEqual(app.buttons["control.keep"].frame, before, "the Review chip appearing moved the decision controls")
    }

    /// Close lives in the top left corner, drawn smaller than the decision
    /// controls but keeping a full tap region.
    func testCloseIsSmallInTheTopLeftCorner() {
        let app = launchApp()
        _ = startViewer(app)

        let close = app.buttons["viewer.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        let window = app.windows.firstMatch.frame
        XCTAssertLessThan(close.frame.midX, window.midX, "Close belongs in the top left")
        XCTAssertLessThan(close.frame.midY, window.height * 0.2, "Close belongs in the top strip")
        XCTAssertLessThan(close.frame.width, app.buttons["control.keep"].frame.width, "Close is drawn smaller than a decision control")
        XCTAssertGreaterThanOrEqual(close.frame.width, 44, "Close keeps a full tap region")
        capture("Controls — close in the top left")
    }

    // MARK: - Swipe feedback and teaching (#15)

    func testFirstPhotoTutorialExplainsAndReplaysFromSettings() {
        let app = launchApp(showTutorial: true)
        _ = startViewer(app)

        XCTAssertTrue(tutorialElement(app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nothing is deleted until you review and confirm."].exists)
        XCTAssertTrue(app.staticTexts["Move the buttons"].exists, "the tutorial must teach the grip")
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "saved as you make it")).firstMatch.exists,
            "the tutorial must explain that accepted work is saved"
        )
        capture("Tutorial — first photo")

        app.buttons["viewer.tutorial.dismiss"].tap()
        XCTAssertFalse(tutorialElement(app).waitForExistence(timeout: 2))

        // Dismissed once: it does not return for the next photo.
        photoElement(app).swipeRight()
        XCTAssertFalse(tutorialElement(app).waitForExistence(timeout: 2))

        // Settings → How to use replays it.
        app.buttons["viewer.close"].tap()
        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 5))
        app.buttons["entry.settings"].tap()
        let howTo = app.buttons["settings.howToUse"]
        XCTAssertTrue(howTo.waitForExistence(timeout: 5))
        capture("Settings — How to use")
        howTo.tap()
        XCTAssertTrue(tutorialElement(app).waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["viewer.tutorial.dismiss"].label, "Got it")
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
            ("viewer.close", "Close"),
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
    /// 19), and Newest starts at index 23 walking older, so the fifth photo is
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
        for identifier in ["viewer.close", "control.undo"] {
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
        let photo = startViewer(app)
        photo.swipeLeft()
        for _ in 1..<24 {
            photoElement(app).swipeRight()
        }

        let review = app.buttons["viewer.reviewFinished"]
        XCTAssertTrue(review.waitForExistence(timeout: 10))
        review.tap()

        let delete = app.buttons["review.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 10))
        delete.tap()

        // SWIPR adds no dialog of its own; the fake library stands in for
        // PhotoKit, whose system prompt is the only confirmation in the real app.
        XCTAssertTrue(app.buttons["result.done"].waitForExistence(timeout: 10))
        app.buttons["result.done"].tap()
        XCTAssertTrue(
            app.buttons["entry.start"].waitForExistence(timeout: 10) || app.buttons["entry.settings"].waitForExistence(timeout: 10)
        )
    }

    // MARK: - Cross-session marks (#13)

    func testHomeOffersResumeAndReviewAfterMarking() {
        let app = launchApp()
        let photo = startViewer(app)
        let markedLabel = photo.label
        photo.swipeLeft()

        app.buttons["viewer.close"].tap()

        let review = app.buttons["entry.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        XCTAssertEqual(review.label, "1 photo marked for deletion")
        XCTAssertEqual(app.buttons["entry.resume"].label, "Resume")
        XCTAssertFalse(markedLabel.isEmpty)
    }

    func testReviewFromHomeReachesTheSameMarks() {
        let app = launchApp()
        let photo = startViewer(app)
        photo.swipeLeft()
        app.buttons["viewer.close"].tap()

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
        app.buttons["viewer.close"].tap()
        XCTAssertTrue(app.buttons["entry.review"].waitForExistence(timeout: 5))

        app.terminate()
        let relaunched = launchApp(persistentStore: true)
        XCTAssertTrue(relaunched.buttons["entry.start"].waitForExistence(timeout: 10))
        XCTAssertTrue(relaunched.buttons["entry.review"].exists, "marks survive a relaunch")

        // Continue sorting resumes at the saved position, never on the mark.
        relaunched.buttons["entry.resume"].tap()
        let resumed = photoElement(relaunched)
        XCTAssertTrue(resumed.waitForExistence(timeout: 10))
        XCTAssertNotEqual(resumed.label, markedLabel)

        // A brand-new mode also skips it.
        relaunched.buttons["viewer.close"].tap()
        XCTAssertTrue(relaunched.buttons["entry.start"].waitForExistence(timeout: 5))
        relaunched.buttons["entry.start"].tap()
        let random = relaunched.buttons["choosePhoto.random"]
        XCTAssertTrue(random.waitForExistence(timeout: 5))
        random.tap()
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

    func testDeletionAsksOnlyTheSystemConfirmationAndExplainsItself() {
        let app = launchApp()
        let photo = startViewer(app)
        photo.swipeLeft()
        app.buttons["viewer.review"].tap()

        XCTAssertTrue(
            app.staticTexts["Your iPhone asks you to confirm before anything is removed. Photos you restored stay put."]
                .waitForExistence(timeout: 5),
            "the review screen must say what the commit does, now that SWIPR has no alert"
        )

        let delete = app.buttons["review.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()

        // No SWIPR dialog appears; the outcome follows the single tap.
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

        app.buttons["viewer.close"].tap()
        XCTAssertEqual(app.buttons["entry.review"].label, "1 photo marked for deletion")
    }

    func testSuccessfulDeletionReturnsToTheSortingPosition() {
        let app = launchApp()
        let photo = startViewer(app)
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

    // MARK: - Settings

    /// Turning the buttons off hides the cluster and its grip, and swiping keeps
    /// working; turning them back on brings the cluster back.
    func testShowButtonsToggleHidesAndRestoresTheCluster() {
        let app = launchApp()
        _ = startViewer(app)
        app.buttons["viewer.close"].tap()

        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 10))
        app.buttons["entry.settings"].tap()
        let toggle = app.descendants(matching: .any)["settings.showButtons"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.tap()
        app.buttons["Back"].firstMatch.tap()

        _ = startViewer(app)
        XCTAssertFalse(app.buttons["control.keep"].exists, "turning the buttons off must hide the cluster")
        XCTAssertFalse(gripElement(app).exists, "turning the buttons off must hide the grip")

        // Swiping is always available, so a decision still works without buttons.
        photoElement(app).swipeLeft()
        XCTAssertTrue(app.buttons["viewer.review"].waitForExistence(timeout: 5), "swiping must still decide")

        app.buttons["viewer.close"].tap()
        app.buttons["entry.settings"].tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.tap()
        app.buttons["Back"].firstMatch.tap()
        _ = startViewer(app)
        XCTAssertTrue(app.buttons["control.keep"].waitForExistence(timeout: 5), "turning them back on must restore the cluster")
    }

    /// Statistics is inline at the top of Settings, read-only and with no
    /// chevron row into a separate screen.
    func testStatisticsIsInlineAtTheTopOfSettings() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 10))
        app.buttons["entry.settings"].tap()

        let stats = app.descendants(matching: .any)["settings.statistics"]
        XCTAssertTrue(stats.waitForExistence(timeout: 10), "statistics must be in Settings")
        XCTAssertTrue(app.staticTexts["settings.statistics.lifetimeDeleted"].exists)
        XCTAssertTrue(app.staticTexts["settings.statistics.lifetimeReclaimed"].exists)
        XCTAssertTrue(app.staticTexts["settings.statistics.sessions"].exists)
        capture("Settings — inline statistics")
    }

    /// Undo is the least frequent decision and the only reversible one, so it
    /// sits at an outer end, away from the Trash/Keep pair. The setting moves it
    /// to either end.
    func testUndoSitsAtAnOuterEndAndMovesWithTheSetting() {
        let app = launchApp()
        _ = startViewer(app)
        let delete = app.buttons["control.delete"]
        let keep = app.buttons["control.keep"]
        let undo = app.buttons["control.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 10))
        XCTAssertLessThan(delete.frame.midX, keep.frame.midX, "Trash and Keep stay paired")
        XCTAssertLessThan(undo.frame.midX, delete.frame.midX, "Undo defaults to the outer left end")

        // Flip it to the other outer end in Settings.
        app.buttons["viewer.close"].tap()
        app.buttons["entry.settings"].tap()
        let right = app.buttons["settings.undoSide.trailing"]
        XCTAssertTrue(right.waitForExistence(timeout: 10))
        for _ in 0..<4 where !right.isHittable { app.swipeUp() }
        right.tap()
        app.buttons["Back"].firstMatch.tap()

        _ = startViewer(app)
        XCTAssertTrue(undo.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(undo.frame.midX, keep.frame.midX, "Undo moves to the outer right end")
    }

    func testSettingsOffersTheThreePositionsAndAReset() {
        let app = launchApp()
        app.buttons["entry.settings"].tap()
        for identifier in [
            "settings.position.bottom", "settings.position.leading", "settings.position.trailing",
            "settings.undoSide.leading", "settings.undoSide.trailing", "settings.resetControls",
        ] {
            let row = app.buttons[identifier]
            for _ in 0..<4 where !row.isHittable { app.swipeUp() }
            XCTAssertTrue(row.exists, "\(identifier) is missing from Settings")
        }
        XCTAssertFalse(app.buttons["settings.preset.swipe"].exists, "the preset list is gone")
    }

    /// The wordmark is centred on the screen, framed by the gear and the review
    /// chip, in every combination of waiting work.
    func testWordmarkIsCentredBetweenTheGearAndTheChip() {
        let app = launchApp()
        let photo = startViewer(app)
        photo.swipeLeft()
        app.buttons["viewer.close"].tap()

        let window = app.windows.firstMatch.frame
        let wordmark = app.descendants(matching: .any)["entry.wordmark"]
        XCTAssertTrue(wordmark.waitForExistence(timeout: 10))
        XCTAssertEqual(wordmark.frame.midX, window.midX, accuracy: 1, "the wordmark must be centred on the phone")
        XCTAssertLessThan(app.buttons["entry.settings"].frame.midX, wordmark.frame.midX)
        XCTAssertGreaterThan(app.buttons["entry.review"].frame.midX, wordmark.frame.midX)
    }

    /// Opening Choose a photo leaves a resumable session alone; choosing a photo
    /// is what replaces it.
    func testOpeningChooseAPhotoKeepsAResumableSession() {
        let app = launchApp(persistentStore: true, resetStore: true)
        let photo = startViewer(app)
        photo.swipeRight()                     // keep, so the session is resumable
        let position = photoElement(app).label
        app.buttons["viewer.close"].tap()
        XCTAssertTrue(app.buttons["entry.resume"].waitForExistence(timeout: 5))

        // Opening Choose a photo and coming back must not disturb the session.
        app.buttons["entry.start"].tap()
        XCTAssertTrue(app.buttons["choosePhoto.newest"].waitForExistence(timeout: 10))
        app.buttons["choosePhoto.back"].tap()
        XCTAssertTrue(app.buttons["entry.resume"].waitForExistence(timeout: 5))
        app.buttons["entry.resume"].tap()
        XCTAssertEqual(photoElement(app).label, position, "opening Choose a photo must not disturb the session")

        // Choosing a photo replaces it: fake-23 is the 4:1 panorama.
        app.buttons["viewer.close"].tap()
        app.buttons["entry.start"].tap()
        let cell = app.descendants(matching: .any)["choosePhoto.cell.fake-23"]
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        cell.tap()
        let chosen = photoElement(app)
        XCTAssertTrue(chosen.waitForExistence(timeout: 10))
        XCTAssertEqual(chosen.frame.width / chosen.frame.height, 4.0, accuracy: 0.02, "choosing a photo replaces the session")
    }
}
