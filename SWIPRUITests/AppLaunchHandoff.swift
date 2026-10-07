import XCTest

/// The launch, terminate and starting-point handoff every UI test goes through.
///
/// Issue #81: `XCUIApplication.launch()` stops a previously running instance of
/// the app itself, and it does so asynchronously — it returns while the old
/// process is still tearing down. A launch that starts during that teardown can
/// attach to the dying process, which keeps the *previous* launch arguments, so
/// the app comes up as the real PhotoKit app on its permission screen instead of
/// the fake-library Home the test asked for, and the test fails on a screen that
/// should have been there. The same race is reported from the other side as
/// `Failed to terminate <bundle>:<pid>: Failed to terminate <bundle>:0`.
///
/// `stop(_:)` blocks until the system reports the old process gone, so the next
/// `launch()` has nothing to terminate, and `launch(_:firstScreen:)` then waits
/// for the screen the launch promises. All of this is synchronisation: no test
/// is removed, skipped, shortened, loosened or retried.
enum AppLaunchHandoff {
    /// How long the system may take to finish stopping a previous instance.
    static let stopTimeout: TimeInterval = 30
    /// How long a freshly launched app may take to put its first screen up.
    static let readyTimeout: TimeInterval = 30
    /// How long the grid may take to hand over to the viewer, or to the
    /// replacement confirmation a saved session raises.
    static let beginSessionTimeout: TimeInterval = 30

    private static let pollInterval: UInt32 = 100_000

    /// Stops the app the current test was driving and returns only once it is
    /// gone. Every test ends here, so the next test's launch has nothing left to
    /// terminate — which is the call that reports `Failed to terminate
    /// <bundle>:<pid>: Failed to terminate <bundle>:0` when it races a teardown.
    static func stopAppUnderTest() {
        stop(XCUIApplication())
    }

    /// Stops any running instance and returns only once it is gone.
    static func stop(_ app: XCUIApplication) {
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
        stop(app)
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
