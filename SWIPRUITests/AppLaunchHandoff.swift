import XCTest

/// The launch, terminate and starting-point handoff every UI test goes through.
///
/// Issue #81: every test drives one installed app, so nearly every test crosses a
/// launch or a terminate handoff, and every reported failure is one of those
/// handoffs going wrong — `Failed to terminate com.zhangjinshuo.swipr:<pid>:
/// Failed to terminate com.zhangjinshuo.swipr:0` raised from
/// `XCUIApplication.launch()`, a Home that never appeared after a launch, a
/// viewer that never appeared after a relaunch, and a Home entry asserted before
/// the decision behind it had been saved.
///
/// Three rules keep the handoff honest:
///
/// * the app is stopped through the one `XCUIApplication` that launched it,
///   because `terminate()` resolves the process through that instance's launch
///   record, and a never-launched proxy fails with the `:0` above;
/// * a stop blocks until the system reports the process gone, so the next
///   `launch()` begins from `notRunning` instead of having to terminate a dying
///   app itself;
/// * a launch and a starting point return only once the screen they promise is
///   on screen, instead of assuming the app is ready the moment a call returns.
///
/// All of this is synchronisation: no test is removed, skipped, shortened,
/// loosened or retried.
enum AppLaunchHandoff {
    /// How long the system may take to finish stopping a previous instance.
    static let stopTimeout: TimeInterval = 30
    /// How long a freshly launched app may take to put its first screen up.
    static let readyTimeout: TimeInterval = 30
    /// How long the grid may take to hand over to the viewer, or to the
    /// replacement confirmation a saved session raises.
    static let beginSessionTimeout: TimeInterval = 30

    private static let pollInterval: UInt32 = 100_000

    /// The `XCUIApplication` that launched the app that is running now.
    ///
    /// XCTest keeps the launch record on the instance that launched the app, and
    /// `terminate()` resolves the process through that record. Stopping through a
    /// second, never-launched proxy is what reports `Failed to terminate
    /// <bundle>:<pid>: Failed to terminate <bundle>:0`: the outer pid is the one
    /// the app is running under, the inner `:0` is the record the fresh proxy
    /// does not have. So the app is always stopped through the instance that
    /// started it, and tests run one after another on a single thread.
    private static var launchedApp: XCUIApplication?

    /// Stops the app the current test was driving and returns only once it is
    /// gone, so the next test's launch has nothing left to terminate.
    static func stopAppUnderTest() {
        guard let app = launchedApp else { return }
        stop(app)
        launchedApp = nil
    }

    /// Stops any running instance and returns only once it is gone.
    private static func stop(_ app: XCUIApplication) {
        guard app.state != .notRunning else { return }
        app.terminate()
        let deadline = Date().addingTimeInterval(stopTimeout)
        while app.state != .notRunning, Date() < deadline {
            usleep(pollInterval)
        }
        XCTAssertEqual(app.state, .notRunning, "the previous instance of the app never stopped")
    }

    /// Stops the running instance, launches `app`, and waits until it is in the
    /// foreground with `firstScreen` on screen.
    static func launch(_ app: XCUIApplication, firstScreen: String) {
        stopAppUnderTest()
        launchedApp = app
        app.launch()
        let deadline = Date().addingTimeInterval(readyTimeout)
        while app.state != .runningForeground, Date() < deadline {
            usleep(pollInterval)
        }
        XCTAssertEqual(app.state, .runningForeground, "the app did not come to the foreground after launching")
        XCTAssertTrue(
            app.descendants(matching: .any)[firstScreen].waitForExistence(timeout: readyTimeout),
            "the app never reached \(firstScreen) after launching"
        )
    }

    /// Taps a starting point and waits for the app to settle on the next screen:
    /// the viewer, or the **Start a new session?** confirmation a saved session
    /// raises first, which is then answered with **Start new**.
    ///
    /// The confirmation can only appear once the saved session has been read, so
    /// treating it as optional after a fixed one-second guess can leave it
    /// covering a viewer that then never arrives.
    static func beginSession(_ start: XCUIElement, in app: XCUIApplication) {
        start.tap()
        let confirmation = app.buttons["replaceSession.startNew"]
        let viewer = app.descendants(matching: .any)["viewer.photo"]
        let deadline = Date().addingTimeInterval(beginSessionTimeout)
        while !confirmation.exists, !viewer.exists, Date() < deadline {
            usleep(pollInterval)
        }
        guard confirmation.exists else { return }
        confirmation.tap()
    }
}
