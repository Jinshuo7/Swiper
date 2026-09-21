import SwiperKit
import XCTest
@testable import Swiper

/// App-level integration tests: `AppModel` operations against the fake photo
/// library and a controllable persistence store.
///
/// These cover the seam between the pure engine and the app: what is saved,
/// when it is acknowledged, and what the user is told when a write fails. They
/// never touch a real photo library.
@MainActor
final class AppModelTests: XCTestCase {
    /// Tutorial state lives in user defaults, so every test gets its own domain
    /// and can never inherit another run's answer.
    private func isolatedDefaults() -> UserDefaults {
        let name = "SwiperAppTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeModel(
        library: FakePhotoLibrary = FakePhotoLibrary.demo(count: 8),
        store: InMemorySessionStore = InMemorySessionStore()
    ) -> (model: AppModel, library: FakePhotoLibrary, store: InMemorySessionStore) {
        let model = AppModel(library: library, store: store, defaults: isolatedDefaults())
        return (model, library, store)
    }

    private func bootstrapped(
        library: FakePhotoLibrary = FakePhotoLibrary.demo(count: 8),
        store: InMemorySessionStore = InMemorySessionStore()
    ) async -> (model: AppModel, library: FakePhotoLibrary, store: InMemorySessionStore) {
        let made = makeModel(library: library, store: store)
        await made.model.bootstrap()
        await made.model.settle()
        return made
    }

    // MARK: - Durable acknowledgement

    func testStartingASessionIsSavedBeforeTheViewerAppears() async {
        let (model, _, store) = await bootstrapped()
        XCTAssertEqual(model.route, .entry)

        model.startRecent()
        await model.settle()

        XCTAssertEqual(model.route, .viewer)
        XCTAssertEqual(store.savedStates.count, 1)
        XCTAssertNotNil(store.state?.session)
        XCTAssertEqual(store.state?.session?.currentAssetID, model.currentAsset?.id)
    }

    func testFailedSavePausesSortingAndKeepsTheDecisionRecoverable() async {
        let (model, _, store) = await bootstrapped()
        model.startRecent()
        await model.settle()

        let before = model.currentAsset?.id
        let savesBefore = store.savedStates.count
        store.failsWrites = true

        model.apply(.queueDeletion)
        await model.settle()

        XCTAssertTrue(model.isDecisionInputBlocked)
        XCTAssertNotNil(model.pendingDecision)
        XCTAssertEqual(model.currentAsset?.id, before, "the session must not advance before the decision is saved")
        XCTAssertEqual(model.queueCount, 0, "an unsaved mark must not appear in the UI")
        XCTAssertEqual(store.savedStates.count, savesBefore)
        XCTAssertEqual(store.state?.marks ?? [], [])

        // Further gestures are refused while a decision is parked.
        model.apply(.queueDeletion)
        await model.settle()
        XCTAssertEqual(model.pendingDecision?.engine.queue.count, 1)
    }

    func testRetryAcknowledgesTheParkedDecisionExactlyOnce() async {
        let (model, _, store) = await bootstrapped()
        model.startRecent()
        await model.settle()
        let marked = model.currentAsset?.id

        store.failsWrites = true
        model.apply(.queueDeletion)
        await model.settle()
        XCTAssertNotNil(model.pendingDecision)

        store.failsWrites = false
        await model.retryPendingDecision()
        await model.settle()

        XCTAssertNil(model.pendingDecision)
        XCTAssertFalse(model.isDecisionInputBlocked)
        XCTAssertEqual(model.markedIDs, [marked].compactMap { $0 })
        XCTAssertEqual(store.state?.marks, [marked].compactMap { $0 })
        XCTAssertNotEqual(model.currentAsset?.id, marked, "a saved decision advances the session")
    }

    func testRetryDoesNotRepeatTheFavoriteEffect() async {
        let (model, library, store) = await bootstrapped()
        model.startRecent()
        await model.settle()
        let favorited = model.currentAsset?.id

        store.failsWrites = true
        model.apply(.favorite)
        await model.settle()

        XCTAssertEqual(library.favoriteWrites.count, 1, "the favorite is written once while staging")
        XCTAssertNotNil(model.pendingDecision)

        store.failsWrites = false
        await model.retryPendingDecision()
        await model.settle()

        XCTAssertEqual(library.favoriteWrites.count, 1, "retrying must not repeat the library effect")
        XCTAssertEqual(library.favoriteWrites.first?.id, favorited)
        XCTAssertTrue(library.favoriteWrites.first?.isFavorite ?? false)
        XCTAssertNil(model.pendingDecision)
    }

    func testASuccessfulDecisionIsSavedBeforeTheSessionAdvances() async {
        let (model, _, store) = await bootstrapped()
        model.startRecent()
        await model.settle()
        let first = model.currentAsset?.id

        model.apply(.queueDeletion)
        await model.settle()

        XCTAssertEqual(store.state?.marks, [first].compactMap { $0 })
        let persistedCurrent = store.state?.session?.currentAssetID
        XCTAssertEqual(persistedCurrent, model.currentAsset?.id)
        XCTAssertNotEqual(model.currentAsset?.id, first)
    }

    func testDiscardingAParkedDecisionLeavesStoredStateUntouched() async {
        let (model, _, store) = await bootstrapped()
        model.startRecent()
        await model.settle()
        let savedSession = store.state?.session

        store.failsWrites = true
        model.apply(.queueDeletion)
        await model.settle()
        model.discardPendingDecision()
        await model.settle()

        XCTAssertNil(model.pendingDecision)
        XCTAssertEqual(store.state?.session, savedSession)
        XCTAssertEqual(store.state?.marks, [])
        XCTAssertEqual(model.route, .entry)
    }

    // MARK: - Restart

    func testRestartRestoresPositionAndUndoFromStoredState() async {
        let store = InMemorySessionStore()
        let first = await bootstrapped(store: store)
        first.model.startRecent()
        await first.model.settle()
        first.model.apply(.queueDeletion)
        await first.model.settle()
        first.model.apply(.keep)
        await first.model.settle()

        let positionAtQuit = first.model.currentAsset?.id
        let marksAtQuit = first.model.markedIDs
        XCTAssertFalse(marksAtQuit.isEmpty)

        // A fresh model over the same store is what a relaunch looks like.
        let second = await bootstrapped(store: store)
        XCTAssertEqual(second.model.route, .entry)
        XCTAssertNotNil(second.model.resumableSession)

        second.model.resumeSession()
        XCTAssertEqual(second.model.route, .viewer)
        XCTAssertEqual(second.model.currentAsset?.id, positionAtQuit)
        XCTAssertEqual(second.model.markedIDs, marksAtQuit)
        XCTAssertTrue(second.model.engine?.undoStack.canUndo ?? false, "Undo survives a relaunch")
    }

    func testUndoAfterRestartRemovesTheDurableMark() async {
        let store = InMemorySessionStore()
        let first = await bootstrapped(store: store)
        first.model.startRecent()
        await first.model.settle()
        let marked = first.model.currentAsset?.id
        first.model.apply(.queueDeletion)
        await first.model.settle()

        let second = await bootstrapped(store: store)
        second.model.resumeSession()

        second.model.undo()
        await second.model.settle()

        XCTAssertEqual(second.model.currentAsset?.id, marked)
        XCTAssertEqual(second.model.markedIDs, [])
        XCTAssertEqual(second.store.state?.marks, [])
    }

    // MARK: - Unreadable and newer stored data

    func testUnreadableStoredStateIsReportedAndNotOverwritten() async {
        let store = InMemorySessionStore(content: .unreadable)
        let (model, _, _) = await bootstrapped(store: store)

        XCTAssertTrue(model.isPersistenceReadOnly)
        XCTAssertNotNil(model.persistenceNotice)

        model.startRecent()
        await model.settle()
        XCTAssertEqual(model.route, .entry, "a blocked write must not open the viewer")
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(store.quarantined)
    }

    func testRecoveringFromUnreadableStatePreservesTheOldFileAndStartsFresh() async {
        let store = InMemorySessionStore(content: .unreadable)
        let (model, _, _) = await bootstrapped(store: store)

        await model.recoverFromUnreadableState()

        XCTAssertTrue(store.quarantined)
        XCTAssertFalse(model.isPersistenceReadOnly)

        model.startRecent()
        await model.settle()
        XCTAssertEqual(model.route, .viewer)
        XCTAssertFalse(store.savedStates.isEmpty)
    }

    func testNewerVersionStoredStateIsNeverOverwritten() async {
        let store = InMemorySessionStore(content: .unsupportedVersion(found: PersistedState.currentSchemaVersion + 1))
        let (model, _, _) = await bootstrapped(store: store)

        XCTAssertTrue(model.isPersistenceReadOnly)
        XCTAssertNotNil(model.persistenceNotice)

        model.startRecent()
        await model.settle()
        XCTAssertEqual(model.route, .entry)
        XCTAssertTrue(store.savedStates.isEmpty, "newer-version data must not be replaced")
        XCTAssertFalse(store.quarantined, "there is no recovery action for newer data")
    }

    // MARK: - External changes

    func testExternallyRemovedMarksAreDroppedWithoutCountingAsDeletions() async {
        let library = FakePhotoLibrary.demo(count: 6)
        let store = InMemorySessionStore(
            content: .state(
                PersistedState(marks: ["fake-0", "gone"], session: nil)
            )
        )
        let (model, _, _) = await bootstrapped(library: library, store: store)

        XCTAssertEqual(model.markedIDs, ["fake-0"])
        XCTAssertEqual(model.statistics.lifetimeDeletedCount, 0)
        XCTAssertEqual(model.statistics.currentSessionDeletedCount, 0)
    }

    // MARK: - Cross-session marks

    func testMarksSurviveSwitchingSortingMode() async {
        let store = InMemorySessionStore()
        let (model, _, _) = await bootstrapped(store: store)
        model.startRecent()
        await model.settle()
        let marked = model.currentAsset?.id
        model.apply(.queueDeletion)
        await model.settle()
        XCTAssertEqual(model.markedIDs, [marked].compactMap { $0 })

        // Switching to Tumbler replaces the session but never the marks.
        model.startTumbler()
        await model.settle()

        XCTAssertEqual(model.markedIDs, [marked].compactMap { $0 })
        XCTAssertEqual(store.state?.marks, [marked].compactMap { $0 })
        XCTAssertNotEqual(model.currentAsset?.id, marked, "a marked photo is skipped while sorting")
    }

    func testMarkedPhotosAreSkippedAfterRestart() async {
        let store = InMemorySessionStore()
        let first = await bootstrapped(store: store)
        first.model.startRecent()
        await first.model.settle()
        let marked = first.model.currentAsset?.id
        first.model.apply(.queueDeletion)
        await first.model.settle()

        let second = await bootstrapped(store: store)
        XCTAssertEqual(second.model.markedIDs, [marked].compactMap { $0 })
        XCTAssertNotNil(second.model.resumableSession)

        second.model.resumeSession()
        XCTAssertEqual(second.model.route, .viewer)
        XCTAssertNotEqual(second.model.currentAsset?.id, marked)

        // Walking the whole session never lands on the marked photo.
        var seen: [String] = []
        while let id = second.model.currentAsset?.id {
            seen.append(id)
            second.model.apply(.keep)
            await second.model.settle()
        }
        XCTAssertFalse(seen.contains(marked ?? ""))
        XCTAssertEqual(second.model.markedIDs, [marked].compactMap { $0 })
    }

    func testAFinishedSessionKeepsItsMarksForLaterReview() async {
        let store = InMemorySessionStore()
        let (model, _, _) = await bootstrapped(store: store)
        model.startRecent()
        await model.settle()
        let marked = model.currentAsset?.id
        model.apply(.queueDeletion)
        await model.settle()

        model.finishSession()
        await model.settle()

        XCTAssertNil(model.engine)
        XCTAssertNil(model.resumableSession)
        XCTAssertEqual(model.markedIDs, [marked].compactMap { $0 })

        model.goToReview(from: .entry)
        XCTAssertEqual(model.route, .review)
        XCTAssertEqual(model.markedIDs, [marked].compactMap { $0 })
    }

    func testRestoringFromHomeReviewUnmarksWithoutASession() async {
        let store = InMemorySessionStore()
        let (model, _, _) = await bootstrapped(store: store)
        model.startRecent()
        await model.settle()
        let marked = model.currentAsset?.id
        model.apply(.queueDeletion)
        await model.settle()
        model.finishSession()
        await model.settle()
        XCTAssertNil(model.engine)

        model.restore(ids: [marked].compactMap { $0 })
        await model.settle()

        XCTAssertEqual(model.markedIDs, [])
        XCTAssertEqual(store.state?.marks, [])
        XCTAssertNil(store.state?.session)
    }

    func testLeaveReviewReturnsToWhereItWasOpenedFrom() async {
        let (model, _, _) = await bootstrapped()
        model.startRecent()
        await model.settle()

        model.goToReview(from: .viewer)
        XCTAssertEqual(model.route, .review)
        model.leaveReview()
        XCTAssertEqual(model.route, .viewer)

        model.finishSession()
        await model.settle()
        model.goToReview(from: .entry)
        model.leaveReview()
        XCTAssertEqual(model.route, .entry)
    }

    func testStaleUndoCannotReapplyARestoredMark() async {
        let store = InMemorySessionStore()
        let first = await bootstrapped(store: store)
        first.model.startRecent()
        await first.model.settle()
        let marked = first.model.currentAsset?.id
        first.model.apply(.queueDeletion)
        await first.model.settle()
        first.model.restore(ids: [marked].compactMap { $0 })
        await first.model.settle()
        XCTAssertEqual(first.model.markedIDs, [])

        let second = await bootstrapped(store: store)
        second.model.resumeSession()
        second.model.undo()
        await second.model.settle()

        XCTAssertEqual(second.model.markedIDs, [])
        XCTAssertEqual(second.store.state?.marks, [])
    }

    // MARK: - Teaching (#15)

    func testTutorialIsShownOnceAndCanBeReplayedWithoutTouchingSavedWork() async {
        let defaults = isolatedDefaults()
        let store = InMemorySessionStore()
        let model = AppModel(library: FakePhotoLibrary.demo(count: 4), store: store, defaults: defaults)
        await model.bootstrap()
        await model.settle()

        XCTAssertFalse(model.isShowingTutorial)
        model.presentTutorialIfNeeded()
        XCTAssertTrue(model.isShowingTutorial)

        model.dismissTutorial()
        XCTAssertFalse(model.isShowingTutorial)
        XCTAssertTrue(model.hasSeenTutorial)

        model.presentTutorialIfNeeded()
        XCTAssertFalse(model.isShowingTutorial, "the tutorial is shown once")

        model.replayTutorial()
        XCTAssertTrue(model.isShowingTutorial, "Settings can replay it")
        model.dismissTutorial()
        XCTAssertTrue(store.savedStates.isEmpty, "teaching never writes session state")
    }

    // MARK: - Deletion recovery (#14)

    private func markTwo(
        _ made: (model: AppModel, library: FakePhotoLibrary, store: InMemorySessionStore)
    ) async -> [String] {
        made.model.startRecent()
        await made.model.settle()
        made.model.apply(.queueDeletion)
        await made.model.settle()
        made.model.apply(.queueDeletion)
        await made.model.settle()
        return made.model.markedIDs
    }

    func testACancelledSystemDeletionPreservesEveryMarkAndCountsNothing() async {
        let made = await bootstrapped()
        let marks = await markTwo(made)
        XCTAssertEqual(marks.count, 2)

        // PhotoKit reports the assets as submitted, but the system confirmation
        // was cancelled, so they are all still present afterwards.
        made.library.faults.failedDeleteIDs = Set(marks)
        await made.model.confirmDeletion()

        XCTAssertEqual(made.model.markedIDs, marks, "cancellation preserves marks")
        XCTAssertEqual(made.model.lastDeletion.deletedCount, 0)
        XCTAssertEqual(made.model.lastDeletion.failedCount, 2)
        XCTAssertEqual(made.model.statistics.lifetimeDeletedCount, 0)
        XCTAssertEqual(made.store.state?.marks, marks)
    }

    func testPartialDeletionLeavesUnsuccessfulItemsMarked() async {
        let made = await bootstrapped()
        let marks = await markTwo(made)
        let failing = marks[0]
        made.library.faults.failedDeleteIDs = [failing]

        await made.model.confirmDeletion()

        XCTAssertEqual(made.model.markedIDs, [failing])
        XCTAssertEqual(made.model.lastDeletion.deletedIDs, [marks[1]])
        XCTAssertEqual(made.model.lastDeletion.failedIDs, [failing])
        XCTAssertEqual(made.model.statistics.currentSessionDeletedCount, 1)
        XCTAssertEqual(made.model.statistics.lifetimeDeletedCount, 1)
        XCTAssertEqual(made.store.state?.marks, [failing])
    }

    func testRetryingAPartialDeletionNeverDoubleCounts() async {
        let made = await bootstrapped()
        let marks = await markTwo(made)
        let failing = marks[0]
        made.library.faults.failedDeleteIDs = [failing]
        await made.model.confirmDeletion()
        XCTAssertEqual(made.model.statistics.lifetimeDeletedCount, 1)

        // The library now accepts the remaining one.
        made.library.faults.failedDeleteIDs = []
        await made.model.confirmDeletion()

        XCTAssertEqual(made.model.markedIDs, [])
        XCTAssertEqual(made.model.lastDeletion.deletedIDs, [failing])
        XCTAssertEqual(
            made.model.statistics.lifetimeDeletedCount,
            2,
            "a retry must count only the newly confirmed deletion"
        )
        XCTAssertEqual(made.store.state?.marks, [])
    }

    func testInterruptedCommitIsReconciledAfterRelaunchWithoutCountingTwice() async {
        let store = InMemorySessionStore()
        let made = await bootstrapped(store: store)
        let marks = await markTwo(made)
        let deleted = marks[0]

        // The library deletion succeeds but the local save fails, as if the app
        // died between the PhotoKit effect and the write.
        store.failsWrites = true
        await made.model.confirmDeletion()
        XCTAssertNotNil(made.model.persistenceNotice)
        XCTAssertEqual(made.model.statistics.lifetimeDeletedCount, 1)
        XCTAssertEqual(store.state?.marks, marks, "the stale list is still stored")

        store.failsWrites = false
        let relaunched = await bootstrapped(store: store)
        XCTAssertEqual(relaunched.model.markedIDs, [marks[1]], "the vanished mark is reconciled away")
        XCTAssertEqual(
            relaunched.model.statistics.lifetimeDeletedCount,
            1,
            "reconciliation never credits a deletion Swiper did not confirm"
        )
    }

    func testResultContinuationReturnsToTheSortingPositionWhileTheSessionContinues() async {
        let made = await bootstrapped()
        await markTwo(made)
        made.library.faults.failedDeleteIDs = []
        await made.model.confirmDeletion()
        XCTAssertEqual(made.model.route, .result)

        made.model.continueAfterResult()
        XCTAssertEqual(made.model.route, .viewer, "an active session continues where it left off")
    }

    func testResultContinuationReachesCompletionWithRemainingMarks() async {
        let made = await bootstrapped(library: FakePhotoLibrary.demo(count: 2))
        made.model.startRecent()
        await made.model.settle()
        made.model.apply(.queueDeletion)
        await made.model.settle()
        made.model.apply(.keep)
        await made.model.settle()
        XCTAssertTrue(made.model.engine?.isFinished ?? false)

        made.model.continueAfterResult()
        XCTAssertEqual(made.model.route, .review, "an exhausted session with marks left lands in review")
    }

    func testResultContinuationReturnsHomeWithNoActiveSession() async {
        let made = await bootstrapped()
        await markTwo(made)
        made.model.finishSession()
        await made.model.settle()
        XCTAssertNil(made.model.engine)

        made.model.continueAfterResult()

        XCTAssertEqual(made.model.route, .entry)
    }

    func testCloseLeavesEveryDecisionSaved() async {
        let made = await bootstrapped()
        made.model.startRecent()
        await made.model.settle()
        let marked = made.model.currentAsset?.id
        made.model.apply(.queueDeletion)
        await made.model.settle()

        made.model.closeViewer()

        XCTAssertEqual(made.model.route, .entry)
        XCTAssertEqual(made.store.state?.marks, [marked].compactMap { $0 })
        XCTAssertNotNil(made.model.resumableSession)
    }

    // MARK: - Integrated journey (#16)

    /// One pass through everything the redesign promises, over a single store:
    /// restored cross-session state, sorting, an interrupted save with retry, a
    /// mode switch, review and restore, a cancelled deletion, a partial deletion
    /// with a successful retry, and continuation.
    func testFullJourneyFromRestoredStateThroughRecoveryAndDeletion() async {
        let library = FakePhotoLibrary.demo(count: 6)
        let store = InMemorySessionStore(
            content: .state(
                PersistedState(
                    marks: ["fake-0"],
                    session: PersistedSession(currentAssetID: "fake-5", direction: .older)
                )
            )
        )
        let model = AppModel(library: library, store: store, defaults: isolatedDefaults())
        await model.bootstrap()
        await model.settle()

        // 1. Restored state: one mark, a resumable position, nothing deleted.
        XCTAssertEqual(model.markedIDs, ["fake-0"])
        XCTAssertNotNil(model.resumableSession)
        XCTAssertEqual(model.statistics.lifetimeDeletedCount, 0)
        model.resumeSession()
        XCTAssertEqual(model.currentAsset?.id, "fake-5")

        // 2. Sorting skips the mark and advances.
        model.apply(.keep)
        await model.settle()
        XCTAssertEqual(model.currentAsset?.id, "fake-4")
        model.apply(.queueDeletion)
        await model.settle()
        model.apply(.keep)
        await model.settle()
        XCTAssertEqual(model.markedIDs, ["fake-0", "fake-4"])
        XCTAssertEqual(model.currentAsset?.id, "fake-2")

        // 3. A failed save pauses sorting, keeps the decision recoverable and
        //    does not move the session on.
        store.failsWrites = true
        model.apply(.queueDeletion)
        await model.settle()
        XCTAssertNotNil(model.pendingDecision)
        XCTAssertEqual(model.currentAsset?.id, "fake-2")
        XCTAssertEqual(model.markedIDs, ["fake-0", "fake-4"])

        store.failsWrites = false
        await model.retryPendingDecision()
        await model.settle()
        XCTAssertNil(model.pendingDecision)
        XCTAssertEqual(model.markedIDs, ["fake-0", "fake-4", "fake-2"])
        XCTAssertEqual(model.currentAsset?.id, "fake-1")

        // 4. Switching mode resets traversal and Undo, never the marks.
        model.startTumbler()
        await model.settle()
        XCTAssertEqual(model.markedIDs, ["fake-0", "fake-4", "fake-2"])
        XCTAssertTrue(model.engine?.decidedIDs.isEmpty ?? false)
        XCTAssertFalse(model.engine?.undoStack.canUndo ?? true)

        // 5. Review from the viewer restores one mark.
        model.goToReview(from: .viewer)
        XCTAssertEqual(model.route, .review)
        model.restore(ids: ["fake-0"])
        await model.settle()
        XCTAssertEqual(model.markedIDs, ["fake-4", "fake-2"])
        XCTAssertTrue(model.engine?.decidedIDs.contains("fake-0") ?? false)

        // 6. A cancelled system deletion keeps every mark and counts nothing.
        library.faults.failedDeleteIDs = Set(FakePhotoLibrary.demoDescriptors(count: 6).map(\.id))
        await model.confirmDeletion()
        XCTAssertEqual(model.lastDeletion.deletedCount, 0)
        XCTAssertEqual(model.lastDeletion.failedCount, 2)
        XCTAssertEqual(model.markedIDs, ["fake-4", "fake-2"])
        XCTAssertEqual(model.statistics.lifetimeDeletedCount, 0)
        XCTAssertEqual(store.state?.marks, ["fake-4", "fake-2"])

        // 7. A partial deletion leaves the unsuccessful item marked.
        model.continueAfterResult()
        XCTAssertEqual(model.route, .viewer)
        library.faults.failedDeleteIDs = ["fake-4"]
        await model.confirmDeletion()
        XCTAssertEqual(model.lastDeletion.deletedIDs, ["fake-2"])
        XCTAssertEqual(model.lastDeletion.failedIDs, ["fake-4"])
        XCTAssertEqual(model.markedIDs, ["fake-4"])
        XCTAssertEqual(model.statistics.lifetimeDeletedCount, 1)

        // 8. Retrying deletes the rest without double counting.
        library.faults.failedDeleteIDs = []
        await model.confirmDeletion()
        XCTAssertEqual(model.markedIDs, [])
        XCTAssertEqual(model.statistics.lifetimeDeletedCount, 2)
        XCTAssertEqual(store.state?.marks, [])

        // 9. Continuation, then an explicit finish, returns home.
        model.continueAfterResult()
        XCTAssertEqual(model.route, .viewer)
        model.finishSession()
        await model.settle()
        XCTAssertEqual(model.route, .entry)
        XCTAssertNil(model.engine)
        XCTAssertNil(store.state?.session)
    }
}
