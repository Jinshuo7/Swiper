import XCTest

/// Smoke tests that drive the app against the in-memory fake library
/// (`-uiTestingFakeLibrary`), so they never touch real photos.
final class SWIPRUITests: XCTestCase {
    /// Mirrors `FakePhotoLibrary.mixedMediaLaunchArgument`. A UI-test bundle is a
    /// separate process and cannot import the app module, so the value has to be
    /// repeated here.
    private let mixedMediaLaunchArgument = "-uiTestingMixedMediaLibrary"

    /// The demo fixtures are `index * 9` days after this instant; see
    /// `FakePhotoLibrary.demoDescriptors`.
    private let fixtureBase = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        continueAfterFailure = false
    }

    /// Leaves the app stopped, so the next test's launch cannot race a teardown.
    override func tearDown() {
        AppLaunchHandoff.stopAppUnderTest()
        super.tearDown()
    }

    /// What the viewer speaks for a demo fixture, so a test can tell exactly
    /// which asset is on screen. Mirrors `ViewerView.accessibilityDescription`.
    private func fixtureLabel(_ index: Int) -> String {
        let date = fixtureBase.addingTimeInterval(Double(index) * 86_400 * 9)
        let kind = index % 5 == 4 ? "Live Photo" : "Photo"
        return "\(kind), \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    private func launchApp(
        showTutorial: Bool = false,
        persistentStore: Bool = false,
        resetStore: Bool = false,
        failDeletion: Bool = false,
        failFirstDecisionSave: Bool = false,
        extraArguments: [String] = []
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
        app.launchArguments += extraArguments
        AppLaunchHandoff.launch(app, firstScreen: app.buttons["entry.settings"])
        return app
    }

    /// The viewer's canvas carries its identifier on whatever it is showing: an
    /// `Image` once the fixture has rendered, and a `ProgressView` before that,
    /// so it is looked up by identifier rather than by element kind.
    private func photoElement(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["viewer.photo"]
    }

    /// Grid cells have the same two states as the viewer canvas, so they are
    /// looked up by identifier too.
    private func gridCell(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)["choosePhoto.cell.\(identifier)"]
    }

    private func tutorialElement(_ app: XCUIApplication) -> XCUIElement {
        app.otherElements["viewer.tutorial"]
    }

    private func clusterElement(_ app: XCUIApplication) -> XCUIElement {
        app.otherElements["viewer.cluster"]
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

    /// What a held dock drag looked like and measured, read from a background
    /// queue: the token and the three destination markers only exist while the
    /// finger is down, and a held gesture blocks the test thread.
    private final class DockDragSample: @unchecked Sendable {
        private let lock = NSLock()
        private var storedScreenshot: XCUIScreenshot?
        private var storedPhotoFrame: CGRect?

        var screenshot: XCUIScreenshot? {
            get { lock.withLock { storedScreenshot } }
            set { lock.withLock { storedScreenshot = newValue } }
        }

        var photoFrame: CGRect? {
            get { lock.withLock { storedPhotoFrame } }
            set { lock.withLock { storedPhotoFrame = newValue } }
        }
    }

    /// Holds a dock drag in place, samples the mid-gesture state from a
    /// background queue — a screenshot plus the media frame — and only then
    /// releases. The attachments and the sample are returned to the caller.
    ///
    /// `sampleAfter` is late enough that a slow drag has arrived and is being
    /// held at its destination, which is the state the markers are read in.
    private func holdDockDrag(
        _ app: XCUIApplication,
        from start: XCUICoordinate,
        to point: CGPoint,
        captureNamed name: String,
        sampleAfter delay: TimeInterval = 1.6
    ) -> DockDragSample {
        let sample = DockDragSample()
        let sampled = expectation(description: "sampled \(name)")
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
            sample.screenshot = XCUIScreen.main.screenshot()
            let photo = self.photoElement(app)
            if photo.exists {
                sample.photoFrame = photo.frame
            }
            sampled.fulfill()
        }

        let end = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: point.x, dy: point.y))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 2.5)
        wait(for: [sampled], timeout: 20)
        guard let screenshot = sample.screenshot else {
            XCTFail("Could not capture \(name) while the dock drag was held")
            return sample
        }
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        usleep(600_000)
        return sample
    }

    /// Opens the starting-point grid the way Home reaches it now: through a
    /// media choice and its editable filters. `Everything` includes the whole
    /// fake library, so viewer tests walk exactly what they did before.
    @discardableResult
    private func openChoosePhoto(_ app: XCUIApplication) -> XCUIElement {
        XCTAssertTrue(app.buttons["entry.preset.everything"].waitForExistence(timeout: 10))
        app.buttons["entry.preset.everything"].tap()
        let cont = app.buttons["filter.continue"]
        XCTAssertTrue(cont.waitForExistence(timeout: 10), "the filters must offer Continue")
        cont.tap()
        let newest = app.buttons["choosePhoto.newest"]
        XCTAssertTrue(newest.waitForExistence(timeout: 10))
        return newest
    }

    /// Taps a starting-point control and, when an unfinished session makes the
    /// replacement confirmation appear, chooses **Start new**. Tests that need to
    /// inspect the confirmation itself drive it directly instead.
    private func beginSession(_ start: XCUIElement, in app: XCUIApplication) {
        AppLaunchHandoff.beginSession(start, in: app)
    }

    /// Opens the Home media choice and starts the newest-first traversal, which
    /// is where every viewer test begins.
    private func startViewer(_ app: XCUIApplication) -> XCUIElement {
        let newest = openChoosePhoto(app)
        beginSession(newest, in: app)
        let photo = photoElement(app)
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        return photo
    }

    func testNewestStartsAViewerSession() {
        let app = launchApp()
        _ = startViewer(app)
    }

    // MARK: - The launch handoff (#81)

    /// A launch always runs the arguments it was given, whatever the launch
    /// before it left behind.
    ///
    /// `XCUIApplication.launch()` stops a previous instance asynchronously, and a
    /// launch that starts during that teardown can attach to the dying process,
    /// which keeps the *previous* launch arguments — the app then opens the
    /// previous test's store, or the real PhotoKit library, instead of what this
    /// launch asked for. This launches the same way three times in a row and asks
    /// the app to prove, each time, that it read the arguments of *that* launch.
    func testEveryLaunchRunsTheArgumentsItWasGiven() {
        let readOnly = launchApp(extraArguments: ["-uiTestingUnreadableState"])
        XCTAssertTrue(
            readOnly.images["persistence.readOnly"].waitForExistence(timeout: 10),
            "the first launch must open the state it was told to open"
        )

        let plain = launchApp()
        XCTAssertFalse(
            plain.images["persistence.readOnly"].waitForExistence(timeout: 3),
            "the second launch must not inherit the first launch's arguments"
        )
        XCTAssertTrue(plain.buttons["entry.preset.everything"].exists)

        let readOnlyAgain = launchApp(extraArguments: ["-uiTestingUnreadableState"])
        XCTAssertTrue(
            readOnlyAgain.images["persistence.readOnly"].waitForExistence(timeout: 10),
            "and the arguments decide each time, so it is not the order that decides"
        )
    }

    // MARK: - Home and the editable filters (#46)

    func testHomeOffersTheThreeMediaChoicesAndStableSettings() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["entry.preset.everything"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["entry.preset.photos"].exists, "Home has a Photos choice")
        XCTAssertTrue(app.buttons["entry.preset.videos"].exists, "Home has a Videos choice")
        XCTAssertTrue(app.buttons["entry.settings"].exists, "Settings keeps its stable place")
        XCTAssertFalse(app.buttons["entry.resume"].exists, "nothing is waiting to continue")
        XCTAssertFalse(app.buttons["entry.review"].exists, "nothing is marked")
        capture("Home — Everything, Photos and Videos")
    }

    /// Every media choice opens the filters with its documented preset, and a
    /// fresh preset drops a previous attempt's exclusions.
    func testMediaChoicesOpenTheirPresetsAndResetEachTime() {
        let app = launchApp()
        let summary = app.staticTexts["filter.summary"]

        app.buttons["entry.preset.photos"].tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertEqual(summary.label, "Photos · 24 items")
        XCTAssertEqual(app.buttons["filter.toggle.video"].value as? String, "Excluded", "Photos leaves videos out")

        // Exclude Live Photos, then choose Photos again: the exclusion is gone.
        app.buttons["filter.toggle.livePhoto"].tap()
        XCTAssertEqual(summary.label, "Screenshots, Panoramas, Other Photos · 20 items")
        app.buttons["filter.back"].tap()
        XCTAssertTrue(app.buttons["entry.preset.photos"].waitForExistence(timeout: 5))
        app.buttons["entry.preset.photos"].tap()
        XCTAssertEqual(summary.label, "Photos · 24 items", "a fresh preset never reuses exclusions")

        // Everything includes the single Videos category too.
        app.buttons["filter.back"].tap()
        app.buttons["entry.preset.everything"].tap()
        XCTAssertEqual(summary.label, "Everything · 24 items")
        capture("Filters — Everything selected")
    }

    /// Five rows toggle independently, Only isolates one, and the selection
    /// follows the user onto the grid and back.
    func testFilterRowsToggleIndependentlyAndOnlyIsolates() {
        let app = launchApp()
        app.buttons["entry.preset.everything"].tap()
        let summary = app.staticTexts["filter.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertEqual(summary.label, "Everything · 24 items")

        // Toggle one row; the others keep their own state.
        app.buttons["filter.toggle.livePhoto"].tap()
        XCTAssertEqual(summary.label, "Screenshots, Panoramas, Other Photos, Videos · 20 items")
        XCTAssertEqual(app.buttons["filter.toggle.otherPhoto"].value as? String, "Included")
        XCTAssertEqual(app.buttons["filter.toggle.livePhoto"].value as? String, "Excluded")
        XCTAssertEqual(app.buttons["filter.toggle.video"].value as? String, "Included", "other rows are untouched")

        // Only Other Photos isolates the whole selection.
        app.buttons["filter.only.otherPhoto"].tap()
        XCTAssertEqual(summary.label, "Other Photos · 20 items")

        // Continue preserves the selection onto the grid, and going back keeps it.
        app.buttons["filter.continue"].tap()
        XCTAssertTrue(app.buttons["choosePhoto.newest"].waitForExistence(timeout: 10))
        app.buttons["choosePhoto.back"].tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual(summary.label, "Other Photos · 20 items", "returning from the grid preserves the filters")

        // Newest then walks only the matching assets.
        app.buttons["filter.continue"].tap()
        let newest = app.buttons["choosePhoto.newest"]
        XCTAssertTrue(newest.waitForExistence(timeout: 10))
        newest.tap()
        let photo = photoElement(app)
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        XCTAssertTrue(photo.label.hasPrefix("Photo"), "no Live Photo may enter an Other Photos pool")
    }

    /// An empty selection is explained and Continue is disabled, rather than
    /// silently starting an empty session.
    func testAnEmptyFilterExplainsItselfAndDisablesContinue() {
        let app = launchApp()
        app.buttons["entry.preset.videos"].tap()
        let summary = app.staticTexts["filter.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertEqual(summary.label, "Videos · 0 items")
        XCTAssertTrue(app.staticTexts["filter.empty"].exists, "the empty state must explain itself")
        XCTAssertFalse(app.buttons["filter.continue"].isEnabled, "an empty pool cannot continue")
        capture("Filters — empty selection, Continue disabled")

        // Clearing everything is the same honest state.
        app.buttons["filter.clear"].tap()
        XCTAssertEqual(summary.label, "Nothing selected · 0 items")
        XCTAssertFalse(app.buttons["filter.continue"].isEnabled)
    }

    /// Captures the Home and filter screens in light, dark and the largest
    /// accessibility text size for the milestone. The attachments are exported
    /// from the result bundle; see docs/TESTING.md.
    func testCaptureHomeAndFilterScreensInEveryAppearance() {
        captureHomeAndFilters(extraArguments: ["-uiTestingForceLight"], suffix: "light")
        captureHomeAndFilters(extraArguments: ["-uiTestingForceDark"], suffix: "dark")
        captureHomeAndFilters(
            extraArguments: [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            ],
            suffix: "ax5"
        )
    }

    private func captureHomeAndFilters(extraArguments: [String], suffix: String) {
        let app = launchApp(extraArguments: extraArguments)
        XCTAssertTrue(app.buttons["entry.preset.everything"].waitForExistence(timeout: 10))
        capture("home-\(suffix)")

        app.buttons["entry.preset.photos"].tap()
        XCTAssertTrue(app.buttons["filter.continue"].waitForExistence(timeout: 10))
        capture("filters-\(suffix)")
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

        AppLaunchHandoff.stopAppUnderTest()

        let relaunched = launchApp(persistentStore: true)
        XCTAssertTrue(relaunched.buttons["entry.resume"].waitForExistence(timeout: 10))
        XCTAssertEqual(relaunched.buttons["entry.resume"].label, "Continue sorting")
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
        _ = openChoosePhoto(app)

        XCTAssertTrue(
            app.staticTexts["choosePhoto.explanation"].waitForExistence(timeout: 10),
            "Choose a photo must say what it is for"
        )
        XCTAssertTrue(app.buttons["choosePhoto.newest"].exists, "Newest first lives inside Choose a photo")
        XCTAssertTrue(app.buttons["choosePhoto.oldest"].exists, "Oldest first lives inside Choose a photo")
        XCTAssertTrue(app.buttons["choosePhoto.random"].exists, "Random lives inside Choose a photo")
        let headers = app.staticTexts
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "choosePhoto.month."))
        XCTAssertGreaterThanOrEqual(headers.count, 2, "the library should be grouped into months")
        XCTAssertTrue(app.buttons["choosePhoto.jump"].exists)
        XCTAssertTrue(app.buttons["choosePhoto.sort"].exists)
        capture("Choose a photo — explanation, Newest first/Oldest first/Random, months")

        // Newest first by default: toggling must actually reorder the sections.
        let firstNewest = headers.element(boundBy: 0).identifier
        let toggle = app.buttons["choosePhoto.sort"]
        XCTAssertTrue(toggle.label.contains("Newest first"), "the grid order toggle starts newest first")
        toggle.tap()
        XCTAssertTrue(
            toggle.label.contains("Oldest first"),
            "tapping the grid order toggle must flip it to Oldest first, saw \(toggle.label)"
        )
        XCTAssertNotEqual(
            headers.element(boundBy: 0).identifier,
            firstNewest,
            "switching to oldest first should change which month is at the top"
        )
        capture("Choose a photo — oldest first")
    }

    /// Both named traversals start at the end they name, whatever the saved
    /// default direction is. "Newest first" walks toward older items; "Oldest
    /// first" walks toward newer ones.
    func testBothNamedTraversalsStartAtTheirNamedEnd() {
        let app = launchApp()
        _ = openChoosePhoto(app)

        let oldest = app.buttons["choosePhoto.oldest"]
        XCTAssertTrue(oldest.waitForExistence(timeout: 10))
        oldest.tap()
        let oldestPhoto = photoElement(app)
        XCTAssertTrue(oldestPhoto.waitForExistence(timeout: 10))
        XCTAssertEqual(oldestPhoto.label, fixtureLabel(0), "Oldest first starts at the oldest photo")
        oldestPhoto.swipeRight()
        XCTAssertEqual(
            photoElement(app).label,
            fixtureLabel(1),
            "Oldest first must walk toward newer photos"
        )

        app.buttons["viewer.close"].tap()
        _ = openChoosePhoto(app)
        let newest = app.buttons["choosePhoto.newest"]
        XCTAssertTrue(newest.waitForExistence(timeout: 10))
        beginSession(newest, in: app)
        let newestPhoto = photoElement(app)
        XCTAssertTrue(newestPhoto.waitForExistence(timeout: 10))
        XCTAssertEqual(newestPhoto.label, fixtureLabel(23), "Newest first starts at the newest photo")
        newestPhoto.swipeRight()
        XCTAssertEqual(
            photoElement(app).label,
            fixtureLabel(22),
            "Newest first must walk toward older photos"
        )
        capture("Choose a photo — both named traversals")
    }

    /// A named traversal walks its whole pool exactly once and then stops at a
    /// visible boundary. It must never wrap back to the photo it started on.
    func testANamedTraversalCompletesWithoutWrapping() {
        let app = launchApp()
        _ = openChoosePhoto(app)
        app.buttons["choosePhoto.oldest"].tap()

        var seen: [String] = []
        for step in 0..<24 {
            let photo = photoElement(app)
            XCTAssertTrue(photo.waitForExistence(timeout: 10), "Oldest first stopped after \(step) photos")
            seen.append(photo.label)
            photo.swipeRight()
        }

        XCTAssertEqual(
            seen,
            (0..<24).map { fixtureLabel($0) },
            "Oldest first must walk every fixture once, oldest to newest, without repeating one"
        )
        XCTAssertFalse(
            photoElement(app).waitForExistence(timeout: 5),
            "a finished traversal must not wrap back to a photo"
        )
        XCTAssertTrue(
            app.buttons["viewer.finish"].waitForExistence(timeout: 10),
            "the traversal must end at the visible completion boundary"
        )
        XCTAssertTrue(app.staticTexts["You've reviewed everything"].exists)
        capture("Choose a photo — traversal finished without wrapping")
    }

    func testChoosePhotoCanJumpStraightToAMonth() {
        let app = launchApp()
        _ = openChoosePhoto(app)

        let jump = app.buttons["choosePhoto.jump"]
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
        _ = openChoosePhoto(app)

        // fake-23 is the newest photo and a 4:1 panorama, so the viewer's own
        // aspect ratio proves the session started where it was chosen.
        let cell = gridCell(app, "fake-23")
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        cell.tap()

        let photo = photoElement(app)
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        let ratio = photo.frame.width / photo.frame.height
        XCTAssertEqual(ratio, 4.0, accuracy: 0.02, "sorting should have started at the chosen photo")
    }

    // MARK: - Replacement confirmation (#56)

    /// The confirmation appears only when a session would be discarded.
    /// **Keep current** resumes the saved position; **Start new** begins a fresh
    /// traversal while the mark stays in Review. Nothing is deleted either way.
    func testReplacementConfirmationKeepsOrReplacesTheSession() {
        let app = launchApp(persistentStore: true, resetStore: true)
        let photo = startViewer(app)
        let firstPhoto = photo.label
        photo.swipeRight()
        // Wait for each advance before the next gesture so the test never races
        // the viewer's transition animation.
        expectation(
            for: NSPredicate(format: "label != %@", firstPhoto),
            evaluatedWith: photoElement(app)
        )
        waitForExpectations(timeout: 5)
        let markedLabel = photoElement(app).label
        photoElement(app).swipeLeft()
        expectation(
            for: NSPredicate(format: "label != %@", markedLabel),
            evaluatedWith: photoElement(app)
        )
        waitForExpectations(timeout: 5)
        let positionAfterMark = photoElement(app).label
        XCTAssertNotEqual(markedLabel, positionAfterMark)

        app.buttons["viewer.close"].tap()
        XCTAssertTrue(app.buttons["entry.resume"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["entry.review"].label, "1 photo marked for deletion")

        // A second start asks first, and explains what will be replaced.
        _ = openChoosePhoto(app)
        app.buttons["choosePhoto.newest"].tap()
        let confirmation = app.otherElements["replaceSession.confirmation"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 10), "a replacement start must ask first")
        XCTAssertTrue(
            app.staticTexts
                .containing(NSPredicate(format: "label CONTAINS %@", "position and Undo history"))
                .firstMatch.exists,
            "the confirmation must say what is replaced"
        )
        XCTAssertTrue(
            app.staticTexts
                .containing(NSPredicate(format: "label CONTAINS %@", "stay in Review"))
                .firstMatch.exists,
            "the confirmation must promise the marks stay in Review"
        )

        // Keep current: the grid stays, and resuming lands on the saved position.
        app.buttons["replaceSession.keep"].tap()
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5))
        app.buttons["choosePhoto.back"].tap()
        app.buttons["filter.back"].tap()
        XCTAssertTrue(app.buttons["entry.resume"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["entry.review"].label, "1 photo marked for deletion")
        app.buttons["entry.resume"].tap()
        XCTAssertEqual(photoElement(app).label, positionAfterMark, "Keep current preserved the saved position")

        // Start new: a fresh traversal from the newest, but the mark stays marked.
        app.buttons["viewer.close"].tap()
        XCTAssertTrue(app.buttons["entry.preset.everything"].waitForExistence(timeout: 10))
        _ = openChoosePhoto(app)
        app.buttons["choosePhoto.newest"].tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 10))
        app.buttons["replaceSession.startNew"].tap()
        XCTAssertTrue(photoElement(app).waitForExistence(timeout: 10))
        XCTAssertEqual(photoElement(app).label, fixtureLabel(23), "Start new begins at the newest photo")
        XCTAssertEqual(
            app.buttons["viewer.review"].label,
            "1 photo marked for deletion",
            "Start new never clears the deletion list"
        )
        XCTAssertNotEqual(photoElement(app).label, markedLabel, "a marked photo stays skipped")
    }

    /// Captures the replacement confirmation in both appearances. The app is
    /// pinned dark, so the light capture goes through the `-uiTestingForceLight`
    /// seam; the porcelain card adapts to whichever appearance it is handed.
    func testCaptureReplacementConfirmationInEveryAppearance() {
        captureReplacementConfirmation(extraArguments: ["-uiTestingForceLight"], name: "replace-session-light")
        captureReplacementConfirmation(extraArguments: ["-uiTestingForceDark"], name: "replace-session-dark")
    }

    private func captureReplacementConfirmation(extraArguments: [String], name: String) {
        let app = launchApp(persistentStore: true, resetStore: true, extraArguments: extraArguments)
        _ = startViewer(app)
        app.buttons["viewer.close"].tap()
        XCTAssertTrue(app.buttons["entry.preset.everything"].waitForExistence(timeout: 10))
        _ = openChoosePhoto(app)
        let newest = app.buttons["choosePhoto.newest"]
        XCTAssertTrue(newest.waitForExistence(timeout: 10))
        newest.tap()
        let confirmation = app.otherElements["replaceSession.confirmation"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 10), "an unfinished session must ask before it is replaced")
        capture(name)
    }

    // MARK: - Moving the dock

    /// What the dock says about where it is docked.
    private func clusterDock(_ app: XCUIApplication) -> String {
        (clusterElement(app).value as? String) ?? ""
    }

    /// The point a destination sits at, in window coordinates.
    ///
    /// `DockGeometry` pins the three: the labelled Delete/Keep pair centred on
    /// the width 20 pt above the bottom safe edge, and columns of separate icon
    /// controls centred at 75 % of the safe height 20 pt inside the edge.
    /// Portrait leaves no leading or trailing safe inset, so a column's centre
    /// is 48 pt from the window edge — its 20 pt margin plus half its 56 pt
    /// width. The destinations are far enough apart that a finger well inside
    /// one captures it.
    private func destinationTarget(_ position: String, in app: XCUIApplication) -> CGPoint {
        let window = app.windows.firstMatch.frame
        switch position {
        case "left":
            return CGPoint(x: window.minX + 48, y: window.height * 0.73)
        case "right":
            return CGPoint(x: window.maxX - 48, y: window.height * 0.73)
        default:
            return CGPoint(x: window.midX, y: window.height * 0.88)
        }
    }

    /// The centre of one dock control: the grip is gone, so a drag usually starts
    /// on a control, and sometimes in the gap beside one.
    private func dockStart(_ app: XCUIApplication, _ identifier: String) -> XCUICoordinate {
        let control = app.buttons[identifier]
        XCTAssertTrue(control.waitForExistence(timeout: 10), "there is no \(identifier) to drag")
        return control.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    }

    /// Drags the whole dock from a point on it to a screen point. The dock has no
    /// grip, so the start can be any control or any gap.
    private func dragDock(
        _ app: XCUIApplication,
        from start: XCUICoordinate,
        to point: CGPoint,
        holdFor hold: TimeInterval = 0.3
    ) {
        XCTAssertTrue(clusterElement(app).waitForExistence(timeout: 10), "there is no dock to drag")
        XCTAssertLessThan(
            clusterElement(app).frame.width,
            app.windows.firstMatch.frame.width,
            "viewer.cluster should be the dock"
        )
        let end = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: point.x, dy: point.y))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: hold)
        // Let the landing animation settle before the next frame is read.
        usleep(600_000)
    }

    /// The pair the user acts on: Delete and Keep, including the tray's padding
    /// around them. Its centre is the dock's anchor at the bottom.
    private func actionPairFrame(_ app: XCUIApplication) -> CGRect {
        let delete = app.buttons["control.delete"].frame
        let keep = app.buttons["control.keep"].frame
        return delete.union(keep)
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
        // A side layout is separate controls: the gap between two of them is a
        // non-action gap, so they never touch.
        let stacked = [delete.frame, keep.frame, undo.frame].sorted { $0.minY < $1.minY }
        for (upper, lower) in zip(stacked, stacked.dropFirst()) {
            XCTAssertGreaterThanOrEqual(
                lower.minY - upper.maxY,
                8,
                "the side controls must stand apart, not merge into one tray",
                file: file,
                line: line
            )
        }
        // And the column keeps its safe-area inset on the edge it sits against.
        let window = app.windows.firstMatch.frame
        if keep.frame.midX < window.midX {
            XCTAssertGreaterThanOrEqual(delete.frame.minX - window.minX, 16, "the left column keeps its inset", file: file, line: line)
        } else {
            XCTAssertGreaterThanOrEqual(window.maxX - delete.frame.maxX, 16, "the right column keeps its inset", file: file, line: line)
        }
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

    /// The dock starts as a bottom row and can be moved to either side, where it
    /// becomes a column. The whole dock is the handle, so each of the three moves
    /// starts on a different control, and none of them decides anything.
    func testTheDockMovesToEachFixedPosition() {
        let app = launchApp()
        _ = startViewer(app)
        assertClusterIsARow(app)
        let window = app.windows.firstMatch.frame

        XCTAssertEqual(
            actionPairFrame(app).midX,
            window.midX,
            accuracy: 6,
            "the labelled Delete/Keep pair is centred on the width"
        )
        XCTAssertLessThan(
            app.buttons["control.undo"].frame.maxX,
            app.buttons["control.delete"].frame.minX,
            "Undo is a separate control before the pair, outside the tray"
        )
        XCTAssertLessThan(
            app.buttons["control.undo"].frame.width,
            app.buttons["control.delete"].frame.width,
            "the bottom Undo is drawn smaller than an action"
        )
        let undoAtBottom = app.buttons["control.undo"].frame
        XCTAssertGreaterThan(undoAtBottom.midY, window.height * 0.8, "the bottom row sits low")
        let photoBefore = photoElement(app).label
        capture("Controls — bottom centre")

        dragDock(app, from: dockStart(app, "control.delete"), to: destinationTarget("left", in: app))
        XCTAssertEqual(clusterDock(app), "Docked left edge")
        XCTAssertLessThan(app.buttons["control.keep"].frame.midX, window.midX, "the left column sits on the left")
        assertClusterIsAColumn(app)
        capture("Controls — left edge column")

        dragDock(app, from: dockStart(app, "control.keep"), to: destinationTarget("right", in: app))
        XCTAssertEqual(clusterDock(app), "Docked right edge")
        XCTAssertGreaterThan(app.buttons["control.keep"].frame.midX, window.midX, "the right column sits on the right")
        assertClusterIsAColumn(app)
        capture("Controls — right edge column")

        dragDock(app, from: dockStart(app, "control.undo"), to: destinationTarget("bottom", in: app))
        XCTAssertEqual(clusterDock(app), "Docked bottom")
        assertClusterIsARow(app)
        capture("Controls — bottom centre again")

        // Moving the dock is not a decision, however the grab lands.
        XCTAssertEqual(photoElement(app).label, photoBefore, "moving the dock must not decide anything")
        XCTAssertFalse(app.buttons["viewer.review"].exists, "moving the dock must not mark the photo")
    }

    /// The neutral dock's two layouts, and the one mapping they share.
    ///
    /// At the bottom Delete and Keep are labelled pills with a separate smaller
    /// Undo outside them; at a side all three are separate icon controls with a
    /// non-action gap between them. "Before actions" then has to mean the same
    /// thing in both: Undo leads the row, and Undo leads the column.
    func testTheDockLayoutsAndTheOneUndoMapping() {
        let app = launchApp()
        _ = startViewer(app)
        let window = app.windows.firstMatch.frame
        let windowMidX = window.midX
        let delete = app.buttons["control.delete"]
        let keep = app.buttons["control.keep"]
        let undo = app.buttons["control.undo"]
        for control in [delete, keep, undo] {
            XCTAssertTrue(control.waitForExistence(timeout: 10), "the dock is missing a control")
        }

        // The bottom layout: two labelled pills, a separate smaller Undo, and
        // the pair centred on the width.
        XCTAssertEqual(delete.label, "Delete")
        XCTAssertEqual(keep.label, "Keep")
        XCTAssertGreaterThan(
            delete.frame.width,
            delete.frame.height + 20,
            "the bottom action is a labelled pill, not an icon circle"
        )
        XCTAssertEqual(actionPairFrame(app).midX, windowMidX, accuracy: 6, "the pair is centred on the width")
        XCTAssertLessThan(undo.frame.midX, delete.frame.midX, "Undo leads the pair: Before actions by default")
        XCTAssertLessThan(undo.frame.width, delete.frame.width, "the bottom Undo is drawn smaller than an action")
        capture("Controls — bottom, labelled pair")

        // The side layout: three separate icon controls, none of them touching.
        dragDock(app, from: dockStart(app, "control.keep"), to: destinationTarget("left", in: app))
        XCTAssertEqual(clusterDock(app), "Docked left edge")
        XCTAssertEqual(delete.frame.width, delete.frame.height, accuracy: 1, "a side control is icon-only")
        XCTAssertEqual(delete.frame.width, keep.frame.width, accuracy: 1, "the side controls are one size")
        XCTAssertEqual(undo.frame.width, keep.frame.width, accuracy: 1, "Undo is not smaller at a side")
        XCTAssertLessThan(undo.frame.midY, delete.frame.midY, "Undo leads the column too: Before actions")
        assertClusterIsAColumn(app)
        capture("Controls — left, separate icon controls")

        // After actions mirrors both layouts. At a side that moves Undo past
        // the pair — the column stays where it is and the pair keeps its own
        // order and spacing; at the bottom it puts Undo after the centred pair.
        let columnAtTheColumn = undo.frame.union(actionPairFrame(app))
        let pairSpacing = keep.frame.midY - delete.frame.midY
        app.buttons["viewer.close"].tap()
        app.buttons["entry.settings"].tap()
        let trailing = app.buttons["settings.undoSide.trailing"]
        XCTAssertTrue(trailing.waitForExistence(timeout: 10))
        for _ in 0..<4 where !trailing.isHittable { app.swipeUp() }
        trailing.tap()
        app.buttons["Back"].firstMatch.tap()

        _ = startViewer(app)
        XCTAssertTrue(undo.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(undo.frame.midY, keep.frame.midY, "Undo follows the column: After actions")
        XCTAssertEqual(
            undo.frame.union(actionPairFrame(app)).midY,
            columnAtTheColumn.midY,
            accuracy: 1,
            "moving Undo moved the column"
        )
        XCTAssertEqual(
            undo.frame.union(actionPairFrame(app)).midX,
            columnAtTheColumn.midX,
            accuracy: 1,
            "moving Undo moved the column"
        )
        XCTAssertEqual(
            keep.frame.midY - delete.frame.midY,
            pairSpacing,
            accuracy: 1,
            "Delete and Keep must never move relative to each other"
        )

        dragDock(app, from: dockStart(app, "control.keep"), to: destinationTarget("bottom", in: app))
        XCTAssertEqual(clusterDock(app), "Docked bottom")
        XCTAssertGreaterThan(undo.frame.midX, keep.frame.midX, "Undo follows the pair: After actions")
        XCTAssertEqual(actionPairFrame(app).midX, windowMidX, accuracy: 6, "the pair is still centred on the width")
        capture("Controls — bottom, Undo after the pair")
    }

    /// The dock has no grip, so no source is special: a drag from each control
    /// can reach each of the three destinations.
    func testEveryControlCanMoveTheDockToEveryDestination() {
        let app = launchApp()
        _ = startViewer(app)
        let photoBefore = photoElement(app).label
        let destinations = [
            ("left", "Docked left edge"),
            ("bottom", "Docked bottom"),
            ("right", "Docked right edge"),
        ]

        for source in ["control.delete", "control.keep", "control.undo"] {
            for (destination, expected) in destinations {
                dragDock(app, from: dockStart(app, source), to: destinationTarget(destination, in: app))
                XCTAssertEqual(
                    clusterDock(app),
                    expected,
                    "a drag that began on \(source) must reach \(destination)"
                )
            }
        }

        // Nine moves, and not one of them was a decision.
        XCTAssertEqual(photoElement(app).label, photoBefore, "moving the dock must not decide anything")
        XCTAssertFalse(app.buttons["viewer.review"].exists, "moving the dock must not mark the photo")
        XCTAssertTrue(app.buttons["control.undo"].isHittable, "the dock must still take input after nine moves")

        // The tray's own padding is part of the handle: with no grip, a drag that
        // begins in a gap has to move the dock as well. This corner point is in
        // the dock's padding whichever way round it is laid out.
        let gap = clusterElement(app).coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.06))
        dragDock(app, from: gap, to: destinationTarget("left", in: app))
        XCTAssertEqual(clusterDock(app), "Docked left edge", "a drag from the dock's own gap must move it")
        XCTAssertFalse(app.buttons["viewer.review"].exists, "a drag from the gap must not mark the photo")
    }

    /// Normal taps still perform Delete, Keep and Undo, and they do it at a side
    /// position too, where the dock is a column.
    func testNormalTapsStillDecideAtEveryPosition() {
        let app = launchApp()
        let photo = startViewer(app)
        let first = photoElement(app).label

        app.buttons["control.delete"].tap()
        XCTAssertTrue(app.buttons["viewer.review"].waitForExistence(timeout: 5), "a tap on Delete must mark the photo")
        app.buttons["control.undo"].tap()
        XCTAssertFalse(
            app.buttons["viewer.review"].waitForExistence(timeout: 2),
            "a tap on Undo must take the mark back"
        )
        XCTAssertEqual(photoElement(app).label, first, "Undo returns to the photo it reversed")
        app.buttons["control.keep"].tap()
        XCTAssertNotEqual(photoElement(app).label, first, "a tap on Keep must advance")

        // The same taps, from the left column.
        dragDock(app, from: dockStart(app, "control.delete"), to: destinationTarget("left", in: app))
        XCTAssertEqual(clusterDock(app), "Docked left edge")
        let second = photoElement(app).label
        app.buttons["control.delete"].tap()
        XCTAssertTrue(app.buttons["viewer.review"].waitForExistence(timeout: 5), "Delete must still tap from the left column")
        app.buttons["control.undo"].tap()
        XCTAssertEqual(photoElement(app).label, second, "Undo must still tap from the left column")
        app.buttons["control.keep"].tap()
        XCTAssertNotEqual(photoElement(app).label, second, "Keep must still tap from the left column")
    }

    /// Nine points of movement cancels the pending tap for good. A short drag may
    /// not decide, and when it releases away from every destination the dock must
    /// not move either.
    func testAShortDragCancelsTheTapWithoutDeciding() {
        let app = launchApp()
        _ = startViewer(app)
        let photoBefore = photoElement(app).label
        let dockBefore = clusterElement(app).frame

        // 20 pt sideways from Delete: past the tap-cancel threshold, and still
        // inside the bottom destination the dock already occupies.
        let delete = dockStart(app, "control.delete")
        dragDock(
            app,
            from: delete,
            to: CGPoint(x: delete.screenPoint.x + 20, y: delete.screenPoint.y)
        )
        XCTAssertEqual(clusterDock(app), "Docked bottom", "a small drag lands the dock back where it was")
        XCTAssertFalse(app.buttons["viewer.review"].exists, "a small drag from Delete must not mark the photo")
        XCTAssertEqual(photoElement(app).label, photoBefore, "a small drag from Delete must not decide")

        // 20 pt sideways from Undo: the same cancellation, now far enough from
        // every destination that the release has nothing to land on.
        let undo = dockStart(app, "control.undo")
        dragDock(
            app,
            from: undo,
            to: CGPoint(x: undo.screenPoint.x + 20, y: undo.screenPoint.y)
        )
        XCTAssertEqual(clusterDock(app), "Docked bottom", "an invalid release restores the source")
        XCTAssertEqual(clusterElement(app).frame, dockBefore, "an invalid release restores the source exactly")
        XCTAssertEqual(photoElement(app).label, photoBefore, "a small drag from Undo must not undo anything")
    }

    /// A release over none of the three destinations changes nothing.
    func testAReleaseOverNoDestinationRestoresTheSource() {
        let app = launchApp()
        _ = startViewer(app)
        let before = app.buttons["control.keep"].frame
        let dock = clusterDock(app)

        // The middle of the screen, above every destination.
        dragDock(
            app,
            from: dockStart(app, "control.keep"),
            to: CGPoint(x: app.windows.firstMatch.frame.midX, y: app.windows.firstMatch.frame.height * 0.3)
        )

        XCTAssertEqual(clusterDock(app), dock, "a release over no destination must not move the dock")
        XCTAssertEqual(app.buttons["control.keep"].frame, before, "a release over no destination must not move the dock")
    }

    /// Moving the dock is the dock's own gesture: a swipe on the photo decides
    /// nothing about where the controls sit.
    func testAPlainSwipeNeverMovesTheCluster() {
        let app = launchApp()
        let photo = startViewer(app)
        let before = app.buttons["control.keep"].frame
        let dock = clusterDock(app)

        photo.swipeRight()
        XCTAssertEqual(clusterDock(app), dock, "a swipe moved the dock")
        XCTAssertEqual(app.buttons["control.keep"].frame, before, "a swipe moved the dock")
    }

    /// Chrome never moves the photo (ADR-0006): the fitted frame is identical at
    /// all three positions and throughout a move.
    func testThePhotoFrameIsIdenticalAtEveryControlPosition() {
        let app = launchApp()
        _ = startViewer(app)

        let atBottom = photoElement(app).frame
        dragDock(app, from: dockStart(app, "control.delete"), to: destinationTarget("left", in: app))
        XCTAssertEqual(clusterDock(app), "Docked left edge")
        let atLeft = photoElement(app).frame
        dragDock(app, from: dockStart(app, "control.keep"), to: destinationTarget("right", in: app))
        XCTAssertEqual(clusterDock(app), "Docked right edge")
        let atRight = photoElement(app).frame

        XCTAssertEqual(atLeft, atBottom, "the photo moved when the dock went left")
        XCTAssertEqual(atRight, atBottom, "the photo moved when the dock went right")
    }

    /// While the dock is being moved it is a compact token with three destination
    /// markers, and the media frame is exactly what it was before. The sample is
    /// read from a background queue, because a held gesture blocks the test thread
    /// and the token and markers only exist while the finger is down.
    func testTheDockIsATokenWhileItIsBeingMoved() {
        let app = launchApp()
        _ = startViewer(app)
        let photoBefore = photoElement(app).frame

        let delete = dockStart(app, "control.delete")
        let sample = holdDockDrag(
            app,
            from: delete,
            to: destinationTarget("left", in: app),
            captureNamed: "Controls — moving, with the three destination markers"
        )

        XCTAssertEqual(
            sample.photoFrame,
            photoBefore,
            "the media frame must be identical while the dock is moving"
        )
        XCTAssertEqual(clusterDock(app), "Docked left edge", "the held drag landed on the release")
        XCTAssertEqual(photoElement(app).frame, photoBefore, "the media frame must be identical after the move")
        XCTAssertFalse(app.buttons["viewer.review"].exists, "a moving dock must never decide")
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
        XCTAssertTrue(app.staticTexts["Move the buttons"].exists, "the tutorial must teach that the buttons can be moved")
        XCTAssertFalse(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "three dots")).firstMatch.exists,
            "the tutorial must not teach a grip the dock no longer has"
        )
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

    /// The media badge always names the kind, beneath Review on the trailing
    /// edge. The fake library cycles a Live Photo every fifth asset (indices 4,
    /// 9, 14, 19), and Newest starts at index 23 walking older, so the fifth
    /// fixture is the first Live Photo.
    func testMediaKindBadgeAlwaysNamesTheCurrentAsset() {
        let app = launchApp()
        _ = startViewer(app)

        let badge = app.otherElements["viewer.mediaBadge"]
        XCTAssertTrue(badge.waitForExistence(timeout: 10), "every asset needs a media badge")
        XCTAssertEqual(badge.label, "Photo", "the first fixture is a still, so the badge must read Photo")

        var steps = 0
        while badge.label != "Live Photo" && steps < 6 {
            photoElement(app).swipeRight()
            steps += 1
        }

        XCTAssertEqual(badge.label, "Live Photo", "a Live Photo must be named in the viewer")
        XCTAssertTrue(
            photoElement(app).label.contains("Live Photo"),
            "the spoken description must name the kind too, got \(photoElement(app).label)"
        )
        capture("Viewer — Live Photo labelled")
    }

    /// The badge is anchored to the trailing edge, directly beneath the Review
    /// entry, so Review and the media kind read as one quiet column.
    func testMediaKindBadgeSitsBeneathReview() {
        let app = launchApp()
        let photo = startViewer(app)
        photo.swipeLeft()   // mark this one, so Review appears

        let review = app.buttons["viewer.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 5), "Review should appear once something is marked")
        let badge = app.otherElements["viewer.mediaBadge"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "the media badge should stay visible")

        XCTAssertGreaterThanOrEqual(
            badge.frame.minY,
            review.frame.maxY,
            "the media badge must sit beneath Review, not beside it"
        )
        XCTAssertEqual(
            badge.frame.maxX,
            review.frame.maxX,
            accuracy: 1,
            "the badge must share Review's trailing edge"
        )
        capture("Viewer — media badge beneath Review")
    }

    /// A mixed pool shows a complete still preview for all three kinds, at the
    /// asset's own aspect ratio, centred and letterboxed, with the neutral kind
    /// badge beneath Review. No playback UI appears for the video: this story
    /// only shows its poster.
    func testMixedMediaPreviewAndBadgeCoverAllThreeKinds() {
        let app = launchApp(extraArguments: [mixedMediaLaunchArgument])
        _ = startViewer(app)
        let window = app.windows.firstMatch.frame

        let expectations: [(label: String, ratio: CGFloat)] = [
            ("Photo", 4.0 / 3.0),
            ("Live Photo", 3.0 / 4.0),
            ("Video", 16.0 / 9.0),
        ]

        for (index, expected) in expectations.enumerated() {
            let photo = photoElement(app)
            XCTAssertTrue(photo.waitForExistence(timeout: 10), "preview \(index) never appeared")
            let badge = app.otherElements["viewer.mediaBadge"]
            XCTAssertTrue(badge.waitForExistence(timeout: 10), "no media badge at step \(index)")
            XCTAssertEqual(badge.label, expected.label, "step \(index) badge")
            XCTAssertTrue(
                photo.label.hasPrefix(expected.label),
                "step \(index) spoken kind, got \(photo.label)"
            )

            let frame = photo.frame
            XCTAssertTrue(window.contains(frame), "step \(index) preview \(frame) escapes \(window)")
            let ratio = frame.width / frame.height
            XCTAssertEqual(ratio, expected.ratio, accuracy: 0.02, "step \(index) is not at its original aspect ratio")
            XCTAssertEqual(frame.midX, window.midX, accuracy: 1, "step \(index) is not centred")
            XCTAssertGreaterThan(frame.height, 40, "step \(index) preview is suspiciously small")

            if index < expectations.count - 1 { photoElement(app).swipeRight() }
        }

        XCTAssertFalse(app.buttons["Play"].exists, "a video poster must not offer playback in this story")
    }

    /// The nine viewer screenshots: each kind at light, dark and the largest
    /// accessibility text size. They go through the same fake library as every
    /// other test.
    func testCaptureViewerKindScreensInEveryAppearance() {
        captureViewerKinds(extraArguments: ["-uiTestingForceLight"], suffix: "light")
        captureViewerKinds(extraArguments: ["-uiTestingForceDark"], suffix: "dark")
        captureViewerKinds(
            extraArguments: [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            ],
            suffix: "ax5"
        )
    }

    private func captureViewerKinds(extraArguments: [String], suffix: String) {
        let app = launchApp(
            extraArguments: extraArguments + [mixedMediaLaunchArgument]
        )
        _ = startViewer(app)
        let badge = app.otherElements["viewer.mediaBadge"]

        XCTAssertTrue(badge.waitForExistence(timeout: 10), "no media badge for the \(suffix) screenshots")
        XCTAssertEqual(badge.label, "Photo")
        capture("viewer-photo-\(suffix)")

        photoElement(app).swipeRight()
        XCTAssertEqual(badge.label, "Live Photo")
        capture("viewer-live-\(suffix)")

        photoElement(app).swipeRight()
        XCTAssertEqual(badge.label, "Video")
        capture("viewer-video-\(suffix)")
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

    /// The dock's own look at each of its three places, in both appearances and
    /// at the largest text size, for the v1-04 milestone screenshots.
    func testCaptureTheDockAtEveryPositionInEveryAppearance() {
        captureDockPositions(extraArguments: ["-uiTestingForceLight"], suffix: "light")
        captureDockPositions(extraArguments: ["-uiTestingForceDark"], suffix: "dark")
        captureDockPositions(
            extraArguments: [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            ],
            suffix: "ax5"
        )
    }

    private func captureDockPositions(extraArguments: [String], suffix: String) {
        let app = launchApp(extraArguments: extraArguments)
        let photo = startViewer(app)
        XCTAssertTrue(photo.waitForExistence(timeout: 10), "no viewer for the \(suffix) dock screenshots")
        capture("dock-bottom-\(suffix)")

        let window = app.windows.firstMatch.frame
        dragDock(app, from: dockStart(app, "control.delete"), to: destinationTarget("left", in: app))
        XCTAssertEqual(clusterDock(app), "Docked left edge")
        assertControlsInsideScreen(app, window: window)
        capture("dock-left-\(suffix)")

        dragDock(app, from: dockStart(app, "control.keep"), to: destinationTarget("right", in: app))
        XCTAssertEqual(clusterDock(app), "Docked right edge")
        assertControlsInsideScreen(app, window: window)
        capture("dock-right-\(suffix)")

        // The one state only a held finger can show: the token and the three
        // subtle destination markers.
        let sample = holdDockDrag(
            app,
            from: dockStart(app, "control.keep"),
            to: destinationTarget("bottom", in: app),
            captureNamed: "dock-moving-\(suffix)"
        )
        XCTAssertEqual(sample.photoFrame, photoElement(app).frame, "the media must not move while the dock does")
        XCTAssertEqual(clusterDock(app), "Docked bottom")
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
            app.buttons["entry.preset.everything"].waitForExistence(timeout: 10) || app.buttons["entry.settings"].waitForExistence(timeout: 10)
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
        XCTAssertEqual(app.buttons["entry.resume"].label, "Continue sorting")
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

        AppLaunchHandoff.stopAppUnderTest()
        let relaunched = launchApp(persistentStore: true)
        XCTAssertTrue(relaunched.buttons["entry.preset.everything"].waitForExistence(timeout: 10))
        XCTAssertTrue(relaunched.buttons["entry.review"].exists, "marks survive a relaunch")

        // Continue sorting resumes at the saved position, never on the mark.
        relaunched.buttons["entry.resume"].tap()
        let resumed = photoElement(relaunched)
        XCTAssertTrue(resumed.waitForExistence(timeout: 10))
        XCTAssertNotEqual(resumed.label, markedLabel)

        // A brand-new mode also skips it.
        relaunched.buttons["viewer.close"].tap()
        XCTAssertTrue(relaunched.buttons["entry.preset.everything"].waitForExistence(timeout: 5))
        relaunched.buttons["entry.preset.everything"].tap()
        let continueToGrid = relaunched.buttons["filter.continue"]
        XCTAssertTrue(continueToGrid.waitForExistence(timeout: 5))
        continueToGrid.tap()
        let random = relaunched.buttons["choosePhoto.random"]
        XCTAssertTrue(random.waitForExistence(timeout: 5))
        beginSession(random, in: relaunched)
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

        let banner = app.images["saveFailure.banner"]
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

        let cell = app.buttons["review.cell.0"]
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

    /// Turning the buttons off hides the dock, and swiping keeps working;
    /// turning them back on brings the dock and its controls back.
    func testShowButtonsToggleHidesAndRestoresTheCluster() {
        let app = launchApp()
        _ = startViewer(app)
        app.buttons["viewer.close"].tap()

        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 10))
        app.buttons["entry.settings"].tap()
        let toggle = app.switches["settings.showButtons"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.tap()
        app.buttons["Back"].firstMatch.tap()

        _ = startViewer(app)
        XCTAssertFalse(app.buttons["control.keep"].exists, "turning the buttons off must hide the controls")
        XCTAssertFalse(clusterElement(app).exists, "turning the buttons off must hide the dock")

        // Swiping is always available, so a decision still works without buttons.
        photoElement(app).swipeLeft()
        XCTAssertTrue(app.buttons["viewer.review"].waitForExistence(timeout: 5), "swiping must still decide")

        app.buttons["viewer.close"].tap()
        app.buttons["entry.settings"].tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.tap()
        app.buttons["Back"].firstMatch.tap()
        _ = startViewer(app)
        XCTAssertTrue(app.buttons["control.keep"].waitForExistence(timeout: 5), "turning them back on must restore the controls")
    }

    /// Statistics is inline at the top of Settings, read-only and with no
    /// chevron row into a separate screen.
    func testStatisticsIsInlineAtTheTopOfSettings() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 10))
        app.buttons["entry.settings"].tap()

        let stats = app.staticTexts["settings.statistics"]
        XCTAssertTrue(stats.waitForExistence(timeout: 10), "statistics must be in Settings")
        XCTAssertTrue(app.staticTexts["settings.statistics.lifetimeDeleted"].exists)
        XCTAssertTrue(app.staticTexts["settings.statistics.lifetimeReclaimed"].exists)
        XCTAssertTrue(app.staticTexts["settings.statistics.sessions"].exists)
        XCTAssertEqual(
            app.staticTexts["settings.statistics.lifetimeReclaimed"].label,
            "0 bytes",
            "nothing reclaimed reads as plain 0 bytes, not an approximate zero"
        )
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
        let wordmark = app.staticTexts["entry.wordmark"]
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
        let firstPhoto = photo.label
        photo.swipeRight()                     // keep, so the session is resumable
        // Wait for the viewer to actually move on before reading the saved
        // position, so this never races the advance animation.
        expectation(
            for: NSPredicate(format: "label != %@", firstPhoto),
            evaluatedWith: photoElement(app)
        )
        waitForExpectations(timeout: 5)
        let position = photoElement(app).label
        app.buttons["viewer.close"].tap()
        XCTAssertTrue(app.buttons["entry.resume"].waitForExistence(timeout: 5))

        // Opening Choose a photo and coming back must not disturb the session.
        _ = openChoosePhoto(app)
        app.buttons["choosePhoto.back"].tap()
        app.buttons["filter.back"].tap()
        XCTAssertTrue(app.buttons["entry.resume"].waitForExistence(timeout: 5))
        app.buttons["entry.resume"].tap()
        XCTAssertEqual(photoElement(app).label, position, "opening Choose a photo must not disturb the session")

        // Choosing a photo replaces it, after the confirmation: fake-23 is the
        // 4:1 panorama.
        app.buttons["viewer.close"].tap()
        _ = openChoosePhoto(app)
        let cell = gridCell(app, "fake-23")
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        cell.tap()
        XCTAssertTrue(
            app.otherElements["replaceSession.confirmation"].waitForExistence(timeout: 10),
            "choosing a photo while a session waits must ask before it replaces it"
        )
        app.buttons["replaceSession.startNew"].tap()
        let chosen = photoElement(app)
        XCTAssertTrue(chosen.waitForExistence(timeout: 10))
        XCTAssertEqual(chosen.frame.width / chosen.frame.height, 4.0, accuracy: 0.02, "choosing a photo replaces the session")
    }
}
