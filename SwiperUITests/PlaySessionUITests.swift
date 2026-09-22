import XCTest

/// "Play like a user" tests: they walk Swiper the way a curious person would —
/// every preset, every rail edge and anchor, marking, reviewing, deleting,
/// relaunching — against the in-memory fake library (`-uiTestingFakeLibrary`), so
/// no real photo is ever touched.
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
    /// it, because the strip is where the way out, the way into Review, the
    /// favorite and the Live Photo badge live.
    private let topStripElements = [
        "viewer.close", "viewer.liveBadge", "viewer.favorite", "viewer.review",
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

    /// Returns to the entry screen from wherever the app currently is.
    private func goHome(_ app: XCUIApplication) {
        if app.buttons["viewer.close"].exists {
            app.buttons["viewer.close"].tap()
        }
        XCTAssertTrue(
            app.buttons["entry.settings"].waitForExistence(timeout: 10),
            "could not get back to the entry screen"
        )
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
        XCTAssertTrue(app.buttons["entry.recent"].waitForExistence(timeout: 10))
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
        XCTAssertTrue(app.buttons["entry.recent"].waitForExistence(timeout: 10))
    }

    @discardableResult
    private func startViewer(_ app: XCUIApplication) -> XCUIElement {
        goHome(app)
        app.buttons["entry.recent"].tap()
        let photo = element(app, "viewer.photo")
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        return photo
    }

    /// Opens Start Here, finds one cell — scrolling to it if the month is below
    /// the fold — and begins sorting there.
    private func startAt(_ app: XCUIApplication, cell identifier: String) {
        goHome(app)
        app.buttons["entry.startHere"].tap()
        let cell = element(app, "startHere.cell.\(identifier)").firstMatch
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

    /// Decides on the current photo the way the active preset says to: the Keep
    /// button when the rail has one, otherwise a drag to the right. Button
    /// presets deliberately disable the drag, so a test that always swiped would
    /// sit on one photo forever.
    private func keepCurrent(_ app: XCUIApplication) {
        if app.buttons["control.keep"].exists {
            app.buttons["control.keep"].tap()
        } else {
            element(app, "viewer.photo").swipeRight()
        }
    }

    /// Marks the current photo the way the active preset says to.
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
        let badge = element(app, "viewer.liveBadge")
        var steps = 0
        while !badge.exists && steps < 8 {
            keepCurrent(app)
            steps += 1
        }
        XCTAssertTrue(badge.exists, "never reached a Live Photo to put a badge in the top strip")
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
            XCTAssertTrue(
                control.isHittable,
                "\(context): \(identifier) cannot be tapped",
                file: file,
                line: line
            )
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

        for fixed in topStripElements + ["viewer.review"] {
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

    /// What the cluster says about where it is docked, once it has finished
    /// settling after a move: the lift is held briefly so a button under the
    /// finger cannot decide as the touch ends.
    private func clusterDock(_ app: XCUIApplication) -> String {
        let deadline = Date().addingTimeInterval(3)
        var value = rawClusterDock(app)
        while value.hasPrefix("Moving"), Date() < deadline {
            usleep(100_000)
            value = rawClusterDock(app)
        }
        return value
    }

    private func rawClusterDock(_ app: XCUIApplication) -> String {
        (element(app, "viewer.cluster").value as? String) ?? ""
    }

    /// Touch and hold the cluster's edge, then drag it, the way a person moves
    /// it. The hold is what lifts it, so a plain drag can never move it.
    private func dragCluster(_ app: XCUIApplication, by offset: CGVector) {
        let cluster = element(app, "viewer.cluster")
        XCTAssertTrue(cluster.waitForExistence(timeout: 10), "there is no control cluster")
        // Guard the query itself: a cluster reporting the whole screen would
        // make every drag below start on the photo instead.
        let window = app.windows.firstMatch.frame
        XCTAssertLessThan(cluster.frame.width, window.width, "viewer.cluster should be the cluster, not the screen")
        XCTAssertLessThan(cluster.frame.height, window.height, "viewer.cluster should be the cluster, not the screen")
        // The tray beside the first control: the controls are buttons and claim
        // their own touches, so the tray is the handle.
        let delete = app.buttons["control.delete"]
        XCTAssertTrue(delete.exists, "the cluster has no Delete control")
        let start = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: delete.frame.minX - 8, dy: delete.frame.midY))
        start.press(
            forDuration: 0.7,
            thenDragTo: start.withOffset(offset),
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )
        // Let the cluster settle before the next grab reads its frame.
        _ = clusterDock(app)
        usleep(300_000)
    }

    /// Wherever the cluster is docked, every control has to stay on screen and
    /// clear of the other controls and of the top strip. The strip is carrying
    /// everything it can carry here: a Live Photo badge and a Review entry.
    func testPlayEveryClusterDock() {
        let app = launchApp()
        _ = startViewer(app)
        if !app.buttons["viewer.review"].exists { markCurrent(app) }
        let review = app.buttons["viewer.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 5), "the Review entry should appear once a photo is marked")
        let marksBefore = review.label
        advanceToALivePhoto(app)

        assertClusterIsUsable(app, context: "bottom centre")
        capture("Play — cluster docked bottom")

        dragCluster(app, by: CGVector(dx: -240, dy: -240))
        XCTAssertEqual(clusterDock(app), "Docked left edge")
        assertClusterIsUsable(app, context: "left edge")
        capture("Play — cluster docked left")

        dragCluster(app, by: CGVector(dx: 320, dy: 0))
        XCTAssertEqual(clusterDock(app), "Docked right edge")
        assertClusterIsUsable(app, context: "right edge")
        capture("Play — cluster docked right")

        // Back to the bottom, then slide along it: different finger lengths need
        // somewhere in between, and sliding must not tip it onto a side edge.
        dragCluster(app, by: CGVector(dx: -180, dy: 220))
        XCTAssertEqual(clusterDock(app), "Docked bottom")
        let firstStop = app.buttons["control.keep"].frame.midX
        dragCluster(app, by: CGVector(dx: -40, dy: 0))
        XCTAssertEqual(clusterDock(app), "Docked bottom")
        XCTAssertLessThan(
            app.buttons["control.keep"].frame.midX,
            firstStop,
            "the cluster slides along its edge for different finger lengths"
        )
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.contains(app.buttons["control.delete"].frame), "it stays on screen")
        assertClusterIsUsable(app, context: "bottom, slid along")
        capture("Play — cluster slid along the bottom edge")

        // Three moves and a slide must not have decided anything: no button may
        // fire just because the cluster was picked up and put down.
        XCTAssertEqual(
            app.buttons["viewer.review"].label,
            marksBefore,
            "moving the cluster decided something"
        )
    }

    // MARK: - Each preset

    /// Every preset keeps the same three controls. The preset decides only
    /// whether dragging the photo decides anything, and Tap to keep adds a tap.
    func testPlayEachPresetDoesWhatSettingsPromises() {
        let app = launchApp()

        // Swipe: the drag decides, and the three buttons are still there.
        choose(app, "settings.preset.swipe")
        let swipePhoto = startViewer(app)
        for identifier in allClusterControls {
            XCTAssertTrue(app.buttons[identifier].exists, "the cluster is the same in every preset")
        }
        XCTAssertTrue(app.buttons["viewer.favorite"].exists, "the heart is always in the top strip")
        swipePhoto.swipeLeft()
        XCTAssertTrue(
            app.buttons["viewer.review"].waitForExistence(timeout: 5),
            "a swipe left must delete in the Swipe preset"
        )
        goHome(app)

        // Buttons only: a swipe decides nothing, and the buttons still decide.
        choose(app, "settings.preset.thumb")
        _ = startViewer(app)
        let beforeSwipe = element(app, "viewer.photo").label
        element(app, "viewer.photo").swipeLeft()
        XCTAssertEqual(
            element(app, "viewer.photo").label,
            beforeSwipe,
            "Buttons only must not decide on a swipe"
        )
        app.buttons["control.delete"].tap()
        XCTAssertTrue(
            app.buttons["viewer.review"].waitForExistence(timeout: 5),
            "the Trash button still decides"
        )
        goHome(app)

        // Tap to keep: the tap keeps, and dragging still decides nothing.
        choose(app, "settings.preset.deleteOnly")
        _ = startViewer(app)
        let beforeTap = element(app, "viewer.photo").label
        element(app, "viewer.photo").swipeLeft()
        XCTAssertEqual(
            element(app, "viewer.photo").label,
            beforeTap,
            "Tap to keep must not decide on a swipe"
        )
        element(app, "viewer.photo").tap()
        XCTAssertNotEqual(
            element(app, "viewer.photo").label,
            beforeTap,
            "tapping the photo must keep it and advance"
        )
        capture("Play — tap-to-keep preset")
    }

    // MARK: - Preferences across a relaunch

    /// Where the cluster is docked is physical, so it has to survive a relaunch,
    /// and the direction choice has to come back with it.
    func testPlayPreferencesSurviveRelaunch() {
        let app = launchApp(persistentStore: true, resetStore: true)
        choose(app, "settings.preset.swipe")
        chooseDirection(app, "Newer first")

        _ = startViewer(app)
        dragCluster(app, by: CGVector(dx: -240, dy: -240))
        XCTAssertEqual(clusterDock(app), "Docked left edge")
        let closeFrame = app.buttons["viewer.close"].frame
        goHome(app)

        app.terminate()
        let relaunched = launchApp(persistentStore: true)
        XCTAssertTrue(relaunched.buttons["entry.recent"].waitForExistence(timeout: 10))
        _ = startViewer(relaunched)
        XCTAssertEqual(
            clusterDock(relaunched),
            "Docked left edge",
            "the dock must survive a relaunch"
        )
        XCTAssertEqual(
            relaunched.buttons["viewer.close"].frame,
            closeFrame,
            "the top strip must not move between launches"
        )
        capture("Play — cluster dock after relaunch")

        goHome(relaunched)
        relaunched.buttons["entry.startHere"].tap()
        XCTAssertTrue(
            relaunched.staticTexts
                .containing(NSPredicate(format: "label CONTAINS[c] %@", "toward newer"))
                .firstMatch
                .waitForExistence(timeout: 5),
            "the direction choice must survive, and Start Here must say which way it walks"
        )
    }

    // MARK: - Default direction

    /// The direction choice is a real choice, and Start Here says out loud which
    /// way it will walk. Recent is deliberately pinned to the newest photo and
    /// walks older, whatever the setting (SPEC §2), so the explanation must not
    /// promise the user something Recent does not do.
    func testPlayTheDirectionChoiceMatchesWhereStartHereWalks() {
        let app = launchApp()
        choose(app, "settings.preset.swipe")

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

        // ...and Start Here says so before the user commits to it.
        app.buttons["entry.startHere"].tap()
        XCTAssertTrue(
            app.staticTexts
                .containing(NSPredicate(format: "label CONTAINS[c] %@", "toward newer"))
                .firstMatch
                .waitForExistence(timeout: 5),
            "Start Here walks toward newer photos, so it must say that, not 'toward older'"
        )
        capture("Play — Start Here direction wording")
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 10))

        // Recent ignores the choice on purpose: it always starts at the newest.
        chooseDirection(app, "Older first")
        XCTAssertEqual(startViewer(app).label, fixtureLabel(23), "Recent starts at the newest photo")
        goHome(app)
        chooseDirection(app, "Newer first")
        XCTAssertEqual(
            startViewer(app).label,
            fixtureLabel(23),
            "Recent starts at the newest photo whatever the direction choice"
        )
    }

    // MARK: - Statistics

    /// Only confirmed deletions may be counted, and the screen has to show the
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
        let statistics = app.buttons["settings.statistics"]
        XCTAssertTrue(statistics.waitForExistence(timeout: 10))
        statistics.tap()

        XCTAssertTrue(app.staticTexts["Statistics"].waitForExistence(timeout: 10))
        // Both "Photos deleted" rows — this session and lifetime — must say 2.
        let twos = app.staticTexts.matching(NSPredicate(format: "label == %@", "2"))
        XCTAssertEqual(
            twos.count,
            2,
            "this-session and lifetime deletion counts should both be 2, saw \(twos.count)"
        )
        capture("Play — statistics after two deletions")
    }

    // MARK: - Start Here's grid

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

    func testPlayStartHereCellsStayInTheirColumns() {
        let app = launchApp()
        goHome(app)
        app.buttons["entry.startHere"].tap()
        XCTAssertTrue(element(app, "startHere.cell.fake-23").waitForExistence(timeout: 10))

        assertGridCellsShareOneColumn(app, prefix: "startHere.cell.", "Start Here grid")
        capture("Play — Start Here grid columns")
    }

    // MARK: - Marked photos are skipped everywhere

    /// A marked photo is waiting in Review, not for another decision. Start Here
    /// says so on the cell, and tapping it must not quietly start a session on a
    /// photo that sorting is supposed to skip.
    func testPlayStartHereRefusesToStartOnAMarkedPhoto() {
        let app = launchApp()
        let photo = startViewer(app)
        let markedID = "fake-23"
        XCTAssertEqual(photo.label, fixtureLabel(23), "Recent starts at the newest fixture")
        photo.swipeLeft()
        goHome(app)

        app.buttons["entry.startHere"].tap()
        let cell = element(app, "startHere.cell.\(markedID)").firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        XCTAssertEqual(cell.label, "\(markedID), marked for deletion")

        cell.tap()
        XCTAssertFalse(
            element(app, "viewer.photo").waitForExistence(timeout: 2),
            "tapping a marked cell must not start a session on it"
        )
        XCTAssertTrue(
            app.buttons["startHere.jump"].exists,
            "a refused tap should leave the user on the Start Here grid"
        )
        capture("Play — Start Here with a marked photo")
    }

    // MARK: - The ends of the flow

    /// Sorting the whole library and deleting all of it is the end of the app's
    /// rope. Every entry point that needs photos has to go quiet, and the app
    /// must still say something honest rather than presenting a broken Recent.
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

        XCTAssertTrue(app.buttons["entry.recent"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["entry.recent"].isEnabled, "Recent needs photos")
        XCTAssertFalse(app.buttons["entry.startHere"].isEnabled, "Start Here needs photos")
        XCTAssertFalse(app.buttons["entry.tumbler"].isEnabled, "Tumbler needs photos")
        XCTAssertFalse(app.buttons["entry.review"].exists, "there is nothing left to review")
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

        XCTAssertTrue(app.buttons["entry.recent"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.buttons["entry.recent"].waitForExistence(timeout: 10))
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
        app.buttons["entry.tumbler"].tap()
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
        XCTAssertTrue(app.buttons["entry.recent"].waitForExistence(timeout: 10))
    }

    /// An element the user must be able to reach: it exists, its centre can be
    /// scrolled on screen, and it can then be tapped. A row taller than the
    /// screen can never be *wholly* visible, so this checks the centre.
    private func assertReachable(
        _ app: XCUIApplication,
        _ identifier: String,
        _ context: String,
        scrollUpTo attempts: Int = 0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = app.buttons[identifier]
        XCTAssertTrue(
            target.waitForExistence(timeout: 10),
            "\(context): \(identifier) is missing",
            file: file,
            line: line
        )
        let window = app.windows.firstMatch.frame
        func reachable() -> Bool {
            target.isHittable
                && window.contains(CGPoint(x: target.frame.midX, y: target.frame.midY))
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
        XCTAssertTrue(
            target.waitForExistence(timeout: 10),
            "\(context): \(identifier) is missing",
            file: file,
            line: line
        )
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(
            window.contains(target.frame),
            "\(context): \(identifier) at \(target.frame) escapes the screen \(window)",
            file: file,
            line: line
        )
        XCTAssertTrue(
            target.isHittable,
            "\(context): \(identifier) cannot be tapped",
            file: file,
            line: line
        )
    }

    /// A phone set to the largest accessibility text is still a phone running
    /// this app. Every screen a person must get through has to keep its ways in
    /// and out on screen — especially the ones with a single way forward.
    func testPlayEveryScreenAtTheLargestAccessibilityTextSize() {
        let app = launchApp(showTutorial: true, extraArguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        let context = "largest text size"
        let window = app.windows.firstMatch.frame

        // Home: every way in, and the footer that explains the gestures.
        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 10))
        for identifier in ["entry.recent", "entry.startHere", "entry.tumbler"] {
            assertReachable(app, identifier, context)
        }
        let footer = element(app, "entry.footer")
        XCTAssertTrue(footer.exists, "\(context): the home footer is missing")
        // At this size the screen cannot hold everything at its natural height,
        // so it has to scroll — otherwise the footer is compressed and truncated
        // where no eye can read it.
        let footerTop = footer.frame.minY
        app.swipeUp()
        XCTAssertLessThan(
            footer.frame.minY,
            footerTop,
            "\(context): the home screen does not scroll, so its content is clipped"
        )
        for _ in 0..<4 where !window.contains(footer.frame) { app.swipeUp() }
        XCTAssertTrue(
            window.contains(footer.frame),
            "\(context): the home footer at \(footer.frame) cannot be brought fully on screen"
        )
        capture("Play — home at the largest text size")

        // The one-time explanation has to stay readable and dismissable.
        _ = startViewer(app)
        assertFullyOnScreen(app, "viewer.tutorial.dismiss", "\(context) tutorial")
        capture("Play — tutorial at the largest text size")
        app.buttons["viewer.tutorial.dismiss"].tap()

        assertClusterIsUsable(app, context: context)
        capture("Play — viewer at the largest text size")

        // Mark one and walk the whole deletion flow. Each of these is the only
        // way forward, so each has to be reachable and tappable; the result card
        // scrolls at this size, so it may need bringing into view.
        markCurrent(app)
        assertFullyOnScreen(app, "viewer.review", "\(context) viewer")
        app.buttons["viewer.review"].tap()
        assertReachable(app, "review.delete", "\(context) review", scrollUpTo: 4)
        capture("Play — review at the largest text size")
        app.buttons["review.delete"].tap()
        assertReachable(app, "result.done", "\(context) result", scrollUpTo: 4)
        capture("Play — result at the largest text size")
        app.buttons["result.done"].tap()

        // Start Here, including its explanation and the way back.
        goHome(app)
        app.buttons["entry.startHere"].tap()
        assertFullyOnScreen(app, "startHere.jump", "\(context) Start Here")
        XCTAssertTrue(element(app, "startHere.explanation").waitForExistence(timeout: 10))
        capture("Play — Start Here at the largest text size")
        app.buttons["Back"].firstMatch.tap()

        // Settings: the rows people change most, then statistics behind its row,
        // then the last row on the way back.
        XCTAssertTrue(app.buttons["entry.settings"].waitForExistence(timeout: 10))
        app.buttons["entry.settings"].tap()
        for identifier in [
            "settings.preset.thumb", "settings.resetControls",
        ] {
            assertReachable(app, identifier, context, scrollUpTo: 10)
        }
        capture("Play — settings at the largest text size")
        assertReachable(app, "settings.statistics", context, scrollUpTo: 10)
        app.buttons["settings.statistics"].tap()
        XCTAssertTrue(app.staticTexts["Statistics"].waitForExistence(timeout: 10))
        capture("Play — statistics at the largest text size")
        assertFullyOnScreen(app, "Back", "\(context) statistics")

        app.buttons["Back"].firstMatch.tap()
        assertReachable(app, "settings.howToUse", context, scrollUpTo: 10)
    }
}
