import XCTest

/// "Play like a user" tests: they walk SWIPR the way a curious person would —
/// every control position, marking, reviewing, deleting, relaunching — against
/// the in-memory fake library (`-uiTestingFakeLibrary`), so no real photo is
/// ever touched.
///
/// The point is not any one bug. It is the invariants that must hold in *any* of
/// those states: the controls stay on screen, stay tappable and never cover each
/// other or the top strip, and every setting does what its screen says. Each
/// arrangement is attached as a screenshot, because a green assertion does not
/// prove the screen reads well.
final class PlaySessionUITests: XCTestCase {
    /// The three decision controls, in cluster order.
    private let allClusterControls = ["control.delete", "control.undo", "control.keep"]

    /// Everything fixed in the top strip. The cluster must never cover any of
    /// it, because the strip is where the way out, the review entry and the
    /// media-kind badge live.
    private let topStripElements = [
        "viewer.close", "viewer.mediaBadge", "viewer.review",
    ]

    /// The demo fixtures are `index * 9` days after this instant; see
    /// `FakePhotoLibrary.demoDescriptors`.
    private let fixtureBase = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Launching and driving

    private func launchApp(
        showTutorial: Bool = false,
        persistentStore: Bool = false,
        resetStore: Bool = false,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uiTestingFakeLibrary",
            "-hasSeenSwipeTutorial", showTutorial ? "NO" : "YES",
        ]
        if persistentStore { app.launchArguments += ["-uiTestingPersistentStore"] }
        if resetStore { app.launchArguments += ["-uiTestingResetStore"] }
        app.launchArguments += extraArguments
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// What the viewer speaks for a demo fixture, so a test can tell exactly
    /// which asset is on screen. Mirrors `ViewerView.accessibilityDescription`.
    private func fixtureLabel(_ index: Int) -> String {
        let date = fixtureBase.addingTimeInterval(Double(index) * 86_400 * 9)
        let kind = index % 5 == 4 ? "Live Photo" : "Photo"
        return "\(kind), \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// A thread-safe slot for a screenshot taken while a drag is held.
    private final class ScreenshotBox: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: XCUIScreenshot?

        var screenshot: XCUIScreenshot? {
            get { lock.withLock { stored } }
            set { lock.withLock { stored = newValue } }
        }
    }

    /// Holds a drag in place, captures what is on screen while it is held, then
    /// releases. The phantom slots only exist mid-drag, so a post-release
    /// screenshot could never show them.
    private func holdDrag(_ start: XCUICoordinate, to end: XCUICoordinate, captureNamed name: String) {
        let box = ScreenshotBox()
        let captured = expectation(description: "captured \(name)")
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.8) {
            box.screenshot = XCUIScreen.main.screenshot()
            captured.fulfill()
        }
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 1.5)
        wait(for: [captured], timeout: 20)
        guard let screenshot = box.screenshot else {
            return XCTFail("Could not capture \(name) while the drag was held")
        }
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Returns to the entry screen from wherever the app currently is.
    private func goHome(_ app: XCUIApplication) {
        if app.buttons["viewer.close"].exists {
            app.buttons["viewer.close"].tap()
        }
        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 10), "could not get back to the entry screen")
    }

    /// Opens Settings from home, taps one option and comes back, scrolling the
    /// settings list when the option is below the fold.
    private func choose(_ app: XCUIApplication, _ identifier: String) {
        goHome(app)
        app.buttons["entry.settings"].tap()
        let option = app.buttons[identifier]
        XCTAssertTrue(option.waitForExistence(timeout: 10), "there is no setting \(identifier)")
        for _ in 0..<4 where !option.isHittable { app.swipeUp() }
        XCTAssertTrue(option.isHittable, "the setting \(identifier) never became tappable")
        option.tap()
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["entry.preset.everything"].waitForExistence(timeout: 10))
    }

    /// Flips the `Show buttons` switch and comes back home.
    private func setShowButtons(_ app: XCUIApplication, on: Bool) {
        goHome(app)
        app.buttons["entry.settings"].tap()
        let toggle = app.switches["settings.showButtons"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "there is no Show buttons toggle")
        for _ in 0..<4 where !toggle.isHittable { app.swipeUp() }
        let isOn = (toggle.value as? String) == "1"
        if isOn != on { toggle.tap() }
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["entry.preset.everything"].waitForExistence(timeout: 10))
    }

    /// Picks one segment of the Default direction control.
    private func chooseDirection(_ app: XCUIApplication, _ label: String) {
        goHome(app)
        app.buttons["entry.settings"].tap()
        let option = app.segmentedControls.buttons[label].exists
            ? app.segmentedControls.buttons[label]
            : app.buttons[label]
        XCTAssertTrue(option.waitForExistence(timeout: 10), "there is no \(label) direction choice")
        for _ in 0..<4 where !option.isHittable { app.swipeUp() }
        XCTAssertTrue(option.isHittable, "the \(label) choice never became tappable")
        option.tap()
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["entry.preset.everything"].waitForExistence(timeout: 10))
    }

    /// Opens the starting-point grid through a Home media choice and its
    /// editable filters. `Everything` includes the whole fake library, so the
    /// viewer tests walk exactly what they did before.
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

    /// Opens the Home media choice and starts the newest-first traversal.
    @discardableResult
    private func startViewer(_ app: XCUIApplication) -> XCUIElement {
        goHome(app)
        let newest = openChoosePhoto(app)
        newest.tap()
        let photo = element(app, "viewer.photo")
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        return photo
    }

    /// Opens Choose a photo, finds one cell — scrolling to it if the month is
    /// below the fold — and begins sorting there.
    private func startAt(_ app: XCUIApplication, cell identifier: String) {
        goHome(app)
        _ = openChoosePhoto(app)
        let cell = element(app, "choosePhoto.cell.\(identifier)").firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "no cell \(identifier)")
        var scrolls = 0
        while !cell.isHittable && scrolls < 12 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(cell.isHittable, "cell \(identifier) never came on screen")
        cell.tap()
        XCTAssertTrue(element(app, "viewer.photo").waitForExistence(timeout: 10))
    }

    /// Decides on the current photo with the Keep button when it is shown, and
    /// otherwise with a drag, which is always available.
    private func keepCurrent(_ app: XCUIApplication) {
        if app.buttons["control.keep"].exists {
            app.buttons["control.keep"].tap()
        } else {
            element(app, "viewer.photo").swipeRight()
        }
    }

    /// Marks the current photo with the Trash button when it is shown, and
    /// otherwise with a drag.
    private func markCurrent(_ app: XCUIApplication) {
        if app.buttons["control.delete"].exists {
            app.buttons["control.delete"].tap()
        } else {
            element(app, "viewer.photo").swipeLeft()
        }
    }

    /// Advances the fake library until a Live Photo is on screen, so the top
    /// strip is carrying everything it ever carries.
    private func advanceToALivePhoto(_ app: XCUIApplication) {
        let badge = element(app, "viewer.mediaBadge")
        var steps = 0
        while badge.label != "Live Photo" && steps < 8 {
            keepCurrent(app)
            steps += 1
        }
        XCTAssertEqual(badge.label, "Live Photo", "never reached a Live Photo to put a badge in the top strip")
    }

    // MARK: - Invariants

    /// Two controls must never sit on top of each other. A single point of
    /// contact is allowed; real overlap is not.
    private func assertNoOverlap(
        _ first: XCUIElement,
        _ second: XCUIElement,
        _ context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard first.exists, second.exists else { return }
        let overlap = first.frame.intersection(second.frame)
        let area = overlap.isNull ? 0 : overlap.width * overlap.height
        XCTAssertLessThan(
            area,
            1,
            "\(context): \(first.identifier) at \(first.frame) covers \(second.identifier) at \(second.frame)",
            file: file,
            line: line
        )
    }

    /// The cluster, wherever it is docked: three controls, each on screen,
    /// tappable, and clear of each other and of everything in the top strip.
    private func assertClusterIsUsable(
        _ app: XCUIApplication,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let window = app.windows.firstMatch.frame
        let present = allClusterControls.filter { app.buttons[$0].exists }
        XCTAssertEqual(
            present.count,
            allClusterControls.count,
            "\(context): the cluster should hold all three controls",
            file: file,
            line: line
        )

        for identifier in present {
            let control = app.buttons[identifier]
            XCTAssertTrue(
                window.contains(control.frame),
                "\(context): \(identifier) at \(control.frame) escapes the screen \(window)",
                file: file,
                line: line
            )
            XCTAssertTrue(control.isHittable, "\(context): \(identifier) cannot be tapped", file: file, line: line)
        }

        for (index, identifier) in present.enumerated() {
            for other in present.dropFirst(index + 1) {
                assertNoOverlap(
                    app.buttons[identifier],
                    app.buttons[other],
                    "\(context) cluster controls",
                    file: file,
                    line: line
                )
            }
        }

        for identifier in present {
            for fixed in topStripElements {
                assertNoOverlap(
                    app.buttons[identifier],
                    element(app, fixed),
                    "\(context) cluster vs \(fixed)",
                    file: file,
                    line: line
                )
            }
        }

        for fixed in topStripElements {
            let strip = element(app, fixed)
            guard strip.exists else { continue }
            XCTAssertTrue(
                window.contains(strip.frame),
                "\(context): \(fixed) at \(strip.frame) escapes the screen",
                file: file,
                line: line
            )
        }
    }

    // MARK: - Moving the cluster

    private func clusterDock(_ app: XCUIApplication) -> String {
        (element(app, "viewer.cluster").value as? String) ?? ""
    }

    private func dragGrip(_ app: XCUIApplication, to point: CGPoint) {
        let grip = element(app, "viewer.grip")
        XCTAssertTrue(grip.waitForExistence(timeout: 10), "there is no grip to drag")
        XCTAssertLessThan(element(app, "viewer.cluster").frame.width, app.windows.firstMatch.frame.width, "viewer.cluster should be the cluster")
        let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point.x, dy: point.y))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
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

    /// Captures the phantom slots while the grip is held, because they only
    /// exist mid-move and that is the state the owner flagged as visually busy:
    /// the bottom row and the side columns overlap in the lower corners.
    func testPhantomSlotsWhileDraggingTheGrip() {
        let app = launchApp()
        _ = startViewer(app)
        let grip = element(app, "viewer.grip")
        XCTAssertTrue(grip.waitForExistence(timeout: 10))
        let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // Toward the left column, where the lower slots overlap most.
        holdDrag(start, to: start.withOffset(CGVector(dx: -120, dy: -180)), captureNamed: "Design — phantom slots mid-move")
    }

    /// Wherever the cluster is, every control has to stay on screen and clear of
    /// the other controls and of the top strip. The strip is carrying everything
    /// it can carry here: a media badge and a Review entry.
    func testPlayEveryControlPosition() {
        let app = launchApp()
        _ = startViewer(app)
        if !app.buttons["viewer.review"].exists { markCurrent(app) }
        let review = app.buttons["viewer.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 5), "the Review entry should appear once a photo is marked")
        let marksBefore = review.label
        advanceToALivePhoto(app)

        assertClusterIsUsable(app, context: "bottom centre")
        capture("Play — cluster at the bottom centre")

        dragGrip(app, to: leftTarget(app))
        XCTAssertEqual(clusterDock(app), "Docked left edge")
        assertClusterIsUsable(app, context: "left edge")
        capture("Play — cluster at the left edge")

        dragGrip(app, to: rightTarget(app))
        XCTAssertEqual(clusterDock(app), "Docked right edge")
        assertClusterIsUsable(app, context: "right edge")
        capture("Play — cluster at the right edge")

        dragGrip(app, to: bottomTarget(app))
        XCTAssertEqual(clusterDock(app), "Docked bottom")
        assertClusterIsUsable(app, context: "bottom centre again")
        capture("Play — cluster back at the bottom centre")

        // Moving the cluster must not have decided anything: no button may fire
        // just because the cluster was picked up and put down.
        XCTAssertEqual(app.buttons["viewer.review"].label, marksBefore, "moving the cluster decided something")
    }

    // MARK: - Turning the buttons off

    /// The buttons are an option; swiping is not. Turning them off hides the
    /// cluster and its grip, and every decision stays reachable.
    func testPlayTurningTheButtonsOffKeepsSwipingWorking() {
        let app = launchApp()
        setShowButtons(app, on: false)
        let photo = startViewer(app)

        XCTAssertFalse(app.buttons["control.keep"].exists, "the buttons are off")
        XCTAssertFalse(element(app, "viewer.grip").exists, "the grip is off")
        capture("Play — buttons turned off")

        photo.swipeLeft()
        XCTAssertTrue(
            app.buttons["viewer.review"].waitForExistence(timeout: 5),
            "swiping must still decide with the buttons hidden"
        )

        setShowButtons(app, on: true)
        _ = startViewer(app)
        XCTAssertTrue(app.buttons["control.keep"].waitForExistence(timeout: 5), "the buttons come back")
    }

    // MARK: - Preferences across a relaunch

    /// Where the cluster sits is physical, so it has to survive a relaunch, and
    /// the direction choice has to come back with it.
    func testPlayPreferencesSurviveRelaunch() {
        let app = launchApp(persistentStore: true, resetStore: true)
        chooseDirection(app, "Newer first")

        _ = startViewer(app)
        dragGrip(app, to: leftTarget(app))
        XCTAssertEqual(clusterDock(app), "Docked left edge")
        let closeFrame = app.buttons["viewer.close"].frame
        goHome(app)

        app.terminate()
        let relaunched = launchApp(persistentStore: true)
        XCTAssertTrue(relaunched.buttons["entry.preset.everything"].waitForExistence(timeout: 10))
        _ = startViewer(relaunched)
        XCTAssertEqual(clusterDock(relaunched), "Docked left edge", "the position must survive a relaunch")
        XCTAssertEqual(relaunched.buttons["viewer.close"].frame, closeFrame, "the top strip must not move between launches")
        capture("Play — cluster position after relaunch")

        goHome(relaunched)
        _ = openChoosePhoto(relaunched)
        XCTAssertTrue(
            relaunched.staticTexts
                .containing(NSPredicate(format: "label CONTAINS[c] %@", "toward newer"))
                .firstMatch
                .waitForExistence(timeout: 5),
            "the direction choice must survive, and Choose a photo must say which way it walks"
        )
    }

    // MARK: - Default direction

    /// The direction choice is a real choice, and Choose a photo says out loud
    /// which way it will walk. Newest is deliberately pinned to the newest photo
    /// and walks older, whatever the setting, so the explanation must not promise
    /// the user something Newest does not do.
    func testPlayTheDirectionChoiceMatchesWhereChooseAPhotoWalks() {
        let app = launchApp()

        // Older first is the default: fake-19's older neighbour is fake-18.
        startAt(app, cell: "fake-19")
        XCTAssertEqual(element(app, "viewer.photo").label, fixtureLabel(19))
        keepCurrent(app)
        XCTAssertEqual(
            element(app, "viewer.photo").label,
            fixtureLabel(18),
            "Older first must walk into the past"
        )
        goHome(app)

        // Newer first walks the other way from the same photo.
        chooseDirection(app, "Newer first")
        startAt(app, cell: "fake-19")
        keepCurrent(app)
        XCTAssertEqual(
            element(app, "viewer.photo").label,
            fixtureLabel(20),
            "Newer first must walk into the future"
        )
        goHome(app)

        // ...and Choose a photo says so before the user commits to it.
        _ = openChoosePhoto(app)
        XCTAssertTrue(
            app.staticTexts
                .containing(NSPredicate(format: "label CONTAINS[c] %@", "toward newer"))
                .firstMatch
                .waitForExistence(timeout: 5),
            "Choose a photo walks toward newer photos, so it must say that, not 'toward older'"
        )
        capture("Play — Choose a photo direction wording")
        app.buttons["choosePhoto.back"].tap()
        app.buttons["filter.back"].tap()
        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 10))

        // Newest ignores the choice on purpose: it always starts at the newest.
        chooseDirection(app, "Older first")
        XCTAssertEqual(startViewer(app).label, fixtureLabel(23), "Newest starts at the newest photo")
        goHome(app)
        chooseDirection(app, "Newer first")
        XCTAssertEqual(
            startViewer(app).label,
            fixtureLabel(23),
            "Newest starts at the newest photo whatever the direction choice"
        )
    }

    // MARK: - Statistics

    /// Only confirmed deletions may be counted, and Settings has to show the
    /// same number for the session as for the lifetime on a first run.
    func testPlayStatisticsCountConfirmedDeletionsOnly() {
        let app = launchApp()
        let photo = startViewer(app)

        let markedPhoto = photo.label
        photo.swipeLeft()                                  // mark 1
        element(app, "viewer.photo").swipeRight()          // keep and advance
        XCTAssertNotEqual(element(app, "viewer.photo").label, markedPhoto)
        element(app, "viewer.photo").swipeLeft()           // mark 2

        let review = app.buttons["viewer.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        XCTAssertEqual(review.label, "2 photos marked for deletion")
        review.tap()

        let delete = app.buttons["review.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        XCTAssertTrue(delete.label.contains("2 photos"))
        delete.tap()

        XCTAssertTrue(app.buttons["result.done"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.staticTexts["2 photos deleted"].waitForExistence(timeout: 10),
            "the result must report the two confirmed deletions"
        )
        app.buttons["result.done"].tap()

        goHome(app)
        app.buttons["entry.settings"].tap()
        let lifetime = element(app, "settings.statistics.lifetimeDeleted")
        XCTAssertTrue(lifetime.waitForExistence(timeout: 10))
        XCTAssertEqual(lifetime.label, "2", "lifetime deletions should be 2")
        // The session's own row is present only while its session is active.
        let current = element(app, "settings.statistics.currentSession")
        if current.exists {
            XCTAssertTrue(current.label.hasPrefix("2 deleted"), "this session should show 2, saw \(current.label)")
        }
        capture("Play — statistics after two deletions")
    }

    // MARK: - Choose a photo's grid

    /// Every cell in a grid occupies exactly one column: no thumbnail may draw
    /// over its neighbours. Panorama fixtures are what break this, because
    /// filling a square-ish cell from a 4:1 image asks for four times the width.
    private func assertGridCellsShareOneColumn(
        _ app: XCUIApplication,
        prefix: String,
        _ context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let cells = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
        var widths: [String: CGFloat] = [:]
        for cell in cells.allElementsBoundByIndex {
            widths[cell.identifier] = max(widths[cell.identifier] ?? 0, cell.frame.width)
        }
        XCTAssertGreaterThanOrEqual(
            widths.count,
            3,
            "\(context): expected a grid of several cells, saw \(widths.count)",
            file: file,
            line: line
        )
        guard let column = widths.values.min() else { return }
        for (identifier, width) in widths {
            XCTAssertEqual(
                width,
                column,
                accuracy: 2,
                "\(context): \(identifier) is \(width) wide instead of one column (\(column))",
                file: file,
                line: line
            )
        }
    }

    func testPlayChoosePhotoCellsStayInTheirColumns() {
        let app = launchApp()
        goHome(app)
        _ = openChoosePhoto(app)
        XCTAssertTrue(element(app, "choosePhoto.cell.fake-23").waitForExistence(timeout: 10))

        assertGridCellsShareOneColumn(app, prefix: "choosePhoto.cell.", "Choose a photo grid")
        capture("Play — Choose a photo grid columns")
    }

    /// Newest starts the session the old Recent did, at the newest photo.
    func testPlayNewestAndRandomStartTheSessionsTheyPromise() {
        let app = launchApp()
        goHome(app)
        let newest = openChoosePhoto(app)
        newest.tap()
        XCTAssertEqual(element(app, "viewer.photo").label, fixtureLabel(23), "Newest starts at the newest photo")
        goHome(app)

        _ = openChoosePhoto(app)
        let random = app.buttons["choosePhoto.random"]
        XCTAssertTrue(random.waitForExistence(timeout: 10))
        random.tap()
        let randomPhoto = element(app, "viewer.photo")
        XCTAssertTrue(randomPhoto.waitForExistence(timeout: 10), "Random starts a Tumbler session")
        // The Tumbler seed is random, so the opening photo is any fixture, never a
        // specific one; that it is a library photo is what the entry promises.
        XCTAssertTrue(
            (0..<24).contains { fixtureLabel($0) == randomPhoto.label },
            "Random must open on a library photo, got \(randomPhoto.label)"
        )
    }

    // MARK: - Marked photos are skipped everywhere

    /// A marked photo is waiting in Review, not for another decision. Choose a
    /// photo says so on the cell, and tapping it must not quietly start a session
    /// on a photo that sorting is supposed to skip.
    func testPlayChoosePhotoRefusesToStartOnAMarkedPhoto() {
        let app = launchApp()
        let photo = startViewer(app)
        let markedID = "fake-23"
        XCTAssertEqual(photo.label, fixtureLabel(23), "Newest starts at the newest fixture")
        photo.swipeLeft()
        goHome(app)

        _ = openChoosePhoto(app)
        let cell = element(app, "choosePhoto.cell.\(markedID)").firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        XCTAssertEqual(cell.label, "\(markedID), marked for deletion")

        cell.tap()
        XCTAssertFalse(
            element(app, "viewer.photo").waitForExistence(timeout: 2),
            "tapping a marked cell must not start a session on it"
        )
        XCTAssertTrue(app.buttons["choosePhoto.jump"].exists, "a refused tap should leave the user on the grid")
        capture("Play — Choose a photo with a marked photo")
    }

    // MARK: - The ends of the flow

    /// Sorting the whole library and deleting all of it is the end of the app's
    /// rope. Every entry point that needs photos has to go quiet, and the app
    /// must still say something honest rather than presenting a broken action.
    func testPlayDeletingEverythingLeavesAnHonestEmptyApp() {
        let app = launchApp()
        _ = startViewer(app)
        for _ in 0..<24 { markCurrent(app) }

        let reviewFinished = app.buttons["viewer.reviewFinished"]
        XCTAssertTrue(reviewFinished.waitForExistence(timeout: 10), "marking everything should offer review")
        XCTAssertTrue(reviewFinished.label.contains("24"))
        reviewFinished.tap()

        let delete = app.buttons["review.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()

        XCTAssertTrue(
            app.staticTexts["24 photos deleted"].waitForExistence(timeout: 20),
            "the result must report the confirmed deletions"
        )
        app.buttons["result.done"].tap()

        XCTAssertTrue(app.buttons["entry.preset.everything"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["entry.preset.everything"].isEnabled, "the media choices need photos")
        XCTAssertTrue(element(app, "entry.empty").exists, "the empty state must say there is nothing to sort")
        XCTAssertFalse(app.buttons["entry.review"].exists, "there is nothing left to review")
        XCTAssertFalse(element(app, "entry.resume").exists, "there is nothing to resume")
        capture("Play — home with an empty library")
    }

    /// Select mode is how a person restores several marks at once. A single tap
    /// has to select exactly one photo, and restoring the last of them has to
    /// land on the empty state rather than a grid of nothing.
    func testPlaySelectModeRestoresSeveralMarksAtOnce() {
        let app = launchApp()
        _ = startViewer(app)
        for _ in 0..<3 {
            markCurrent(app)
            keepCurrent(app)
        }

        let review = app.buttons["viewer.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        review.tap()
        XCTAssertTrue(app.buttons["review.selectToggle"].waitForExistence(timeout: 5))
        assertGridCellsShareOneColumn(app, prefix: "review.cell.", "Review grid")
        app.buttons["review.selectToggle"].tap()

        let first = element(app, "review.cell.0").firstMatch
        let second = element(app, "review.cell.1").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        let restore = app.buttons["review.restoreSelected"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        XCTAssertEqual(restore.label, "Restore 1 selected", "one tap must select exactly one photo")

        second.tap()
        XCTAssertEqual(restore.label, "Restore 2 selected", "two taps must select two photos")
        capture("Play — select mode with two marks chosen")
        restore.tap()
        XCTAssertEqual(
            element(app, "review.markedCount").label,
            "1 photo marked for deletion",
            "restoring two of three marks should leave one"
        )

        let onlyCell = element(app, "review.cell.0").firstMatch
        XCTAssertTrue(onlyCell.waitForExistence(timeout: 5))
        onlyCell.tap()
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        XCTAssertTrue(
            app.staticTexts["Nothing is marked for deletion"].waitForExistence(timeout: 5),
            "restoring the last mark should show the empty state"
        )
        capture("Play — review emptied by restoring")
    }

    /// A save that cannot be retried may be discarded, and discarding has to say
    /// what it did rather than quietly move on.
    func testPlayAFailedSaveCanBeDiscarded() {
        let app = launchApp(extraArguments: ["-uiTestingFailFirstDecisionSave"])
        let photo = startViewer(app)
        let before = photo.label

        photo.swipeLeft()
        let banner = element(app, "saveFailure.banner")
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "viewer.photo").label, before, "nothing may advance past an unsaved decision")

        let discard = app.buttons["Discard"]
        XCTAssertTrue(discard.exists)
        discard.tap()

        XCTAssertTrue(app.buttons["entry.preset.everything"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            element(app, "persistence.notice").waitForExistence(timeout: 5),
            "discarding a decision must be stated, not silent"
        )
        XCTAssertTrue(
            app.staticTexts["That decision was not saved, so it was left out. Nothing else changed."].exists
        )
        capture("Play — discarded decision notice")
    }

    /// Stored progress this build cannot read is the one case where writing would
    /// destroy user data. The banner must say so, and starting fresh must clear it.
    func testPlayUnreadableSavedProgressIsExplainedNotOverwritten() {
        let app = launchApp(extraArguments: ["-uiTestingUnreadableState"])
        let banner = element(app, "persistence.readOnly")
        XCTAssertTrue(banner.waitForExistence(timeout: 10), "unreadable progress must be reported")
        XCTAssertTrue(app.staticTexts["Saved progress can't be read"].exists)
        capture("Play — unreadable saved progress")

        let startFresh = app.buttons["Start fresh"]
        XCTAssertTrue(startFresh.exists)
        startFresh.tap()
        XCTAssertFalse(banner.waitForExistence(timeout: 3), "starting fresh must clear the read-only banner")
        XCTAssertTrue(app.buttons["entry.preset.everything"].waitForExistence(timeout: 10))
    }

    /// A saved file from a newer build gets the same treatment as unreadable
    /// data: it is reported, and nothing is written over it.
    func testPlaySavedProgressFromANewerVersionIsNotOverwritten() {
        let app = launchApp(extraArguments: ["-uiTestingFutureVersionState"])
        let banner = element(app, "persistence.readOnly")
        XCTAssertTrue(banner.waitForExistence(timeout: 10), "newer-version progress must be reported")
        XCTAssertTrue(app.staticTexts["Saved progress can't be read"].exists)
        XCTAssertTrue(
            app.staticTexts
                .containing(NSPredicate(format: "label CONTAINS[c] %@", "newer version"))
                .firstMatch
                .exists,
            "the banner must say why it cannot be read"
        )
        XCTAssertTrue(app.buttons["Start fresh"].exists)
        capture("Play — saved progress from a newer version")
    }

    /// Tumbler promises a randomised session that never repeats a photo. Playing
    /// one to the end is the only way to see that promise kept.
    func testPlayTumblerVisitsEveryPhotoExactlyOnce() {
        let app = launchApp()
        goHome(app)
        _ = openChoosePhoto(app)
        let random = app.buttons["choosePhoto.random"]
        XCTAssertTrue(random.waitForExistence(timeout: 10))
        random.tap()
        XCTAssertTrue(element(app, "viewer.photo").waitForExistence(timeout: 10))

        var seen: [String] = []
        for step in 0..<24 {
            let photo = element(app, "viewer.photo")
            XCTAssertTrue(photo.waitForExistence(timeout: 5), "Tumbler stopped after \(step) photos")
            let label = photo.label
            XCTAssertFalse(seen.contains(label), "Tumbler showed \(label) twice")
            seen.append(label)
            keepCurrent(app)
        }

        XCTAssertEqual(seen.count, 24, "a Tumbler session should visit the whole library")
        XCTAssertTrue(
            app.buttons["viewer.finish"].waitForExistence(timeout: 5),
            "with nothing marked, finishing is the way out of a finished session"
        )
        app.buttons["viewer.finish"].tap()
        XCTAssertTrue(app.buttons["entry.preset.everything"].waitForExistence(timeout: 10))
    }

    /// An element the user must be able to reach: it exists, its centre can be
    /// scrolled on screen, and it can then be tapped.
    private func assertReachable(
        _ app: XCUIApplication,
        _ identifier: String,
        _ context: String,
        scrollUpTo attempts: Int = 0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = element(app, identifier)
        XCTAssertTrue(target.waitForExistence(timeout: 10), "\(context): \(identifier) is missing", file: file, line: line)
        let window = app.windows.firstMatch.frame
        func reachable() -> Bool {
            target.isHittable && window.contains(CGPoint(x: target.frame.midX, y: target.frame.midY))
        }
        for _ in 0..<attempts where !reachable() { app.swipeUp() }
        XCTAssertTrue(
            reachable(),
            "\(context): \(identifier) at \(target.frame) could not be brought on screen and tapped",
            file: file,
            line: line
        )
    }

    /// An element that has to be wholly on screen, for the one way forward out of
    /// a screen: a button the user cannot see is a button they cannot press.
    private func assertFullyOnScreen(
        _ app: XCUIApplication,
        _ identifier: String,
        _ context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = app.buttons[identifier]
        XCTAssertTrue(target.waitForExistence(timeout: 10), "\(context): \(identifier) is missing", file: file, line: line)
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(
            window.contains(target.frame),
            "\(context): \(identifier) at \(target.frame) escapes the screen \(window)",
            file: file,
            line: line
        )
        XCTAssertTrue(target.isHittable, "\(context): \(identifier) cannot be tapped", file: file, line: line)
    }

    /// A phone set to the largest accessibility text is still a phone running
    /// this app. Every screen a person must get through has to keep its ways in
    /// and out on screen — especially the ones with a single way forward.
    func testPlayEveryScreenAtTheLargestAccessibilityTextSize() {
        let app = launchApp(showTutorial: true, extraArguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        let context = "largest text size"

        // Home: the one action and the settings gear.
        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 10))
        assertReachable(app, "entry.wordmark", context)
        assertReachable(app, "entry.preset.everything", context)
        capture("Play — home at the largest text size")

        // The one-time explanation has to stay readable and dismissable.
        _ = startViewer(app)
        assertFullyOnScreen(app, "viewer.tutorial.dismiss", "\(context) tutorial")
        capture("Play — tutorial at the largest text size")
        app.buttons["viewer.tutorial.dismiss"].tap()

        assertClusterIsUsable(app, context: context)
        capture("Play — viewer at the largest text size")

        // Mark one and walk the whole deletion flow.
        markCurrent(app)
        assertFullyOnScreen(app, "viewer.review", "\(context) viewer")
        app.buttons["viewer.review"].tap()
        assertReachable(app, "review.delete", "\(context) review", scrollUpTo: 4)
        capture("Play — review at the largest text size")
        app.buttons["review.delete"].tap()
        assertReachable(app, "result.done", "\(context) result", scrollUpTo: 4)
        capture("Play — result at the largest text size")
        app.buttons["result.done"].tap()

        // Choose a photo, including its explanation and the way back. The jump
        // bar can sit a few points low at AX5, so it only has to stay tappable.
        goHome(app)
        _ = openChoosePhoto(app)
        assertReachable(app, "choosePhoto.jump", "\(context) Choose a photo", scrollUpTo: 4)
        XCTAssertTrue(element(app, "choosePhoto.explanation").waitForExistence(timeout: 10))
        assertReachable(app, "choosePhoto.newest", context, scrollUpTo: 4)
        // The fix that keeps the labels whole: at this size they stack.
        XCTAssertLessThan(
            app.buttons["choosePhoto.newest"].frame.maxY,
            app.buttons["choosePhoto.random"].frame.minY + 1,
            "at the largest text size the traversal buttons stack so their labels survive"
        )
        capture("Play — Choose a photo at the largest text size")
        app.buttons["choosePhoto.back"].tap()
        app.buttons["filter.back"].tap()

        // Settings: the inline statistics, then the controls people change most,
        // then the last row on the way back.
        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 10))
        app.buttons["entry.settings"].tap()
        assertReachable(app, "settings.statistics.lifetimeDeleted", context, scrollUpTo: 10)
        // The fix that stops mid-word breaks: the value stacks under its label.
        let statLabel = element(app, "settings.statistics.lifetimeDeleted.label")
        let statValue = element(app, "settings.statistics.lifetimeDeleted")
        XCTAssertGreaterThanOrEqual(
            statValue.frame.minY,
            statLabel.frame.maxY - 1,
            "at the largest text size the value stacks under its label"
        )
        capture("Play — settings at the largest text size")
        for identifier in [
            "settings.showButtons", "settings.position.bottom", "settings.undoSide.leading", "settings.resetControls",
        ] {
            assertReachable(app, identifier, context, scrollUpTo: 10)
        }
        assertReachable(app, "settings.howToUse", context, scrollUpTo: 10)
    }

    /// The entry screen is captured in every reachable state so its restraint
    /// can be inspected by eye. A marked photo always implies a resumable
    /// session, so the states are: nothing waiting, a session waiting, and both.
    func testPlayEntryScreenInEveryState() {
        let app = launchApp(persistentStore: true, resetStore: true)

        XCTAssertTrue(app.buttons["entry.preset.everything"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["entry.resume"].exists)
        XCTAssertFalse(app.buttons["entry.review"].exists)
        capture("Entry — nothing waiting")

        startViewer(app)
        keepCurrent(app)
        goHome(app)
        XCTAssertTrue(app.buttons["entry.resume"].exists)
        capture("Entry — a session waiting")

        startViewer(app)
        markCurrent(app)
        goHome(app)
        XCTAssertTrue(app.buttons["entry.review"].exists)
        XCTAssertTrue(app.buttons["entry.resume"].exists)
        capture("Entry — a session and marks waiting")
    }
}
