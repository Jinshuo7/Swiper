import SWIPRKit
import XCTest
@testable import SWIPR

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
        let name = "SWIPRAppTests-\(UUID().uuidString)"
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

        model.startNewest()
        await model.settle()

        XCTAssertEqual(model.route, .viewer)
        XCTAssertEqual(store.savedStates.count, 1)
        XCTAssertNotNil(store.state?.session)
        XCTAssertEqual(store.state?.session?.currentAssetID, model.currentAsset?.id)
    }

    // MARK: - Limited Photos access

    func testLimitedAccessKeepsHiddenMarksAndRestoresThemWhenAccessWidens() async {
        let library = FakePhotoLibrary.demo(count: 6)
        let (model, _, store) = await bootstrapped(library: library)

        // Mark three photos in a known order.
        model.startNewest()
        await model.settle()
        var marked: [String] = []
        for _ in 0..<3 {
            guard let id = model.currentAsset?.id else { break }
            marked.append(id)
            model.apply(.queueDeletion)
            await model.settle()
        }
        XCTAssertEqual(model.markedIDs, marked)
        let statisticsBefore = model.statistics

        // Limited access now hides the first two marks but keeps the rest live.
        let hidden = Set(marked.prefix(2))
        let allIDs = Set((0..<6).map { "fake-\($0)" })
        library.authorization = .limited
        library.limitedSelectionIDs = allIDs.subtracting(hidden)
        await model.refreshAuthorization()
        await model.settle()

        XCTAssertEqual(model.hiddenMarkCount, 2, "hidden marks are counted")
        XCTAssertEqual(Set(model.markedIDs), Set(marked).subtracting(hidden), "only visible marks are shown")
        XCTAssertEqual(Set(store.state?.marks ?? []), Set(marked), "the durable list keeps the hidden marks")
        XCTAssertEqual(model.statistics, statisticsBefore, "hiding a mark credits no deletion")
        XCTAssertNotNil(model.persistenceNotice, "the user is told some marks are hidden")

        // Widening access brings the hidden marks back in their saved order.
        library.authorization = .authorized
        library.limitedSelectionIDs = nil
        await model.refreshAuthorization()
        await model.settle()

        XCTAssertEqual(model.markedIDs, marked, "marks reappear in their saved order")
        XCTAssertEqual(model.hiddenMarkCount, 0)
    }

    func testHiddenMarksSurviveARelaunchUnderLimitedAccess() async {
        let library = FakePhotoLibrary.demo(count: 6)
        let store = InMemorySessionStore()
        let (model, _, _) = await bootstrapped(library: library, store: store)

        model.startNewest()
        await model.settle()
        var marked: [String] = []
        for _ in 0..<2 {
            guard let id = model.currentAsset?.id else { break }
            marked.append(id)
            model.apply(.queueDeletion)
            await model.settle()
        }

        // Relaunch with the same store while a Limited selection hides every mark.
        let hidden = Set(marked)
        let allIDs = Set((0..<6).map { "fake-\($0)" })
        library.authorization = .limited
        library.limitedSelectionIDs = allIDs.subtracting(hidden)
        let (relaunched, _, _) = await bootstrapped(library: library, store: store)

        XCTAssertEqual(relaunched.hiddenMarkCount, 2, "the relaunch still counts the hidden marks")
        XCTAssertTrue(relaunched.markedIDs.isEmpty, "no hidden mark is presented")
        XCTAssertEqual(
            Set(store.state?.marks ?? []),
            Set(marked),
            "the durable deletion list still holds every mark"
        )
    }

    func testConfirmingDeletionUnderLimitedAccessKeepsHiddenMarks() async {
        let library = FakePhotoLibrary.demo(count: 6)
        let (model, _, store) = await bootstrapped(library: library)

        model.startNewest()
        await model.settle()
        var marked: [String] = []
        for _ in 0..<3 {
            guard let id = model.currentAsset?.id else { break }
            marked.append(id)
            model.apply(.queueDeletion)
            await model.settle()
        }

        // Limited access hides two marks; only the third can be deleted now.
        let hidden = Set(marked.prefix(2))
        let allIDs = Set((0..<6).map { "fake-\($0)" })
        library.authorization = .limited
        library.limitedSelectionIDs = allIDs.subtracting(hidden)
        await model.refreshAuthorization()
        await model.settle()
        XCTAssertEqual(Set(model.markedIDs), Set(marked).subtracting(hidden))

        await model.confirmDeletion()
        await model.settle()

        XCTAssertEqual(
            Set(store.state?.marks ?? []),
            hidden,
            "deleting the visible marks must not drop the hidden ones"
        )
        XCTAssertEqual(model.hiddenMarkCount, 2)
    }

    func testFailedSavePausesSortingAndKeepsTheDecisionRecoverable() async {
        let (model, _, store) = await bootstrapped()
        model.startNewest()
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
        model.startNewest()
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

    /// A decision performs no library work of its own: it changes the session and
    /// the deletion list, and the photo stays until a deletion is confirmed. So
    /// retrying a parked save re-attempts the write and nothing else.
    func testRetrySavesTheParkedDecisionAgainAndTouchesNoPhotos() async {
        let (model, library, store) = await bootstrapped()
        model.startNewest()
        await model.settle()
        let marked = model.currentAsset?.id
        let savesBefore = store.saveAttempts

        store.failsWrites = true
        model.apply(.queueDeletion)
        await model.settle()

        XCTAssertNotNil(model.pendingDecision)
        XCTAssertEqual(model.currentAsset?.id, marked, "an unsaved decision must not advance the session")
        XCTAssertEqual(store.saveAttempts, savesBefore + 1, "the failed save is attempted once")
        XCTAssertEqual(store.state?.marks, [], "a failed save leaves the stored state alone")
        let ids = [marked].compactMap { $0 }
        let stillThere = await library.existingAssetIDs(among: ids)
        XCTAssertEqual(stillThere, Set(ids), "marking a photo removes nothing from the library")

        store.failsWrites = false
        await model.retryPendingDecision()
        await model.settle()

        XCTAssertNil(model.pendingDecision)
        XCTAssertNotEqual(model.currentAsset?.id, marked, "the retried decision advances the session")
        XCTAssertEqual(store.state?.marks, ids)
        XCTAssertEqual(store.saveAttempts, savesBefore + 2, "retrying re-attempts the write and nothing else")
    }

    func testASuccessfulDecisionIsSavedBeforeTheSessionAdvances() async {
        let (model, _, store) = await bootstrapped()
        model.startNewest()
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
        model.startNewest()
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

    /// Two gestures in the same run-loop turn must serialise, and neither marking
    /// nor undoing may touch the library: nothing is deleted until review.
    func testMarkingThenUndoingInOneTurnLeavesTheLibraryAlone() async {
        let (model, library, _) = await bootstrapped()
        model.startNewest()
        await model.settle()
        let marked = model.currentAsset?.id

        model.apply(.queueDeletion)
        model.apply(.undo)
        await model.settle()

        XCTAssertEqual(model.currentAsset?.id, marked, "undo returns to the marked photo")
        XCTAssertTrue(model.markedIDs.isEmpty, "undo removes the mark")
        let ids = [marked].compactMap { $0 }
        let stillThere = await library.existingAssetIDs(among: ids)
        XCTAssertEqual(stillThere, Set(ids), "marking and undoing touch nothing")
        XCTAssertNil(model.pendingDecision)
    }

    // MARK: - Restart

    func testRestartRestoresPositionAndUndoFromStoredState() async {
        let store = InMemorySessionStore()
        let first = await bootstrapped(store: store)
        first.model.startNewest()
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
        first.model.startNewest()
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

        model.startNewest()
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

        model.startNewest()
        await model.settle()
        XCTAssertEqual(model.route, .viewer)
        XCTAssertFalse(store.savedStates.isEmpty)
    }

    func testNewerVersionStoredStateIsNeverOverwritten() async {
        let store = InMemorySessionStore(content: .unsupportedVersion(found: PersistedState.currentSchemaVersion + 1))
        let (model, _, _) = await bootstrapped(store: store)

        XCTAssertTrue(model.isPersistenceReadOnly)
        XCTAssertNotNil(model.persistenceNotice)

        model.startNewest()
        await model.settle()
        XCTAssertEqual(model.route, .entry)
        XCTAssertTrue(store.savedStates.isEmpty, "newer-version data must not be replaced")
        XCTAssertFalse(store.quarantined, "there is no recovery action for newer data")
    }

    // MARK: - External changes

    func testExternallyRemovedMarksAreReportedOnReturn() async {
        let library = FakePhotoLibrary.demo(count: 6)
        let store = InMemorySessionStore(content: .state(PersistedState(marks: ["fake-0", "gone"], session: nil)))
        let (model, _, _) = await bootstrapped(library: library, store: store)

        XCTAssertEqual(model.markedIDs, ["fake-0"])
        XCTAssertEqual(
            model.persistenceNotice,
            "One marked photo is no longer in your library, so it was removed from the list.",
            "a mark that vanished outside SWIPR must be explained, not silently dropped"
        )
        XCTAssertEqual(model.statistics.lifetimeDeletedCount, 0)
    }

    // MARK: - Interruption (airplane / Uber)

    func testKillingTheAppMidSessionLosesNothingAndResumesClearly() async {
        let library = FakePhotoLibrary.demo(count: 8)
        let store = InMemorySessionStore()

        // Beginning: open, sort a little, then the user is interrupted.
        let first = AppModel(library: library, store: store, defaults: isolatedDefaults())
        await first.bootstrap()
        await first.settle()
        first.startNewest()
        await first.settle()
        first.apply(.keep)
        await first.settle()
        first.apply(.queueDeletion)
        await first.settle()
        let positionAtKill = first.currentAsset?.id
        let marksAtKill = first.markedIDs
        XCTAssertFalse(marksAtKill.isEmpty)

        // The app is killed, not merely backgrounded: a brand-new model over the
        // same store and the same device library.
        let second = AppModel(library: library, store: store, defaults: isolatedDefaults())
        await second.bootstrap()
        await second.settle()

        // Middle: home is unambiguous about what can be resumed and reviewed.
        XCTAssertEqual(second.route, .entry)
        XCTAssertNotNil(second.resumableSession, "the session must be offered as Resume")
        XCTAssertEqual(second.markedIDs, marksAtKill, "marks survive the kill")

        second.resumeSession()
        XCTAssertEqual(second.currentAsset?.id, positionAtKill, "sorting resumes at the same photo")
        XCTAssertTrue(second.engine?.undoStack.canUndo ?? false, "Undo survives the kill")

        // End: still reachable after the interruption.
        second.goToReview(from: .entry)
        XCTAssertEqual(second.route, .review)
        XCTAssertEqual(second.markedIDs, marksAtKill)
    }

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
        model.startNewest()
        await model.settle()
        let marked = model.currentAsset?.id
        model.apply(.queueDeletion)
        await model.settle()
        XCTAssertEqual(model.markedIDs, [marked].compactMap { $0 })

        // Switching to Tumbler replaces the session but never the marks. It is a
        // replacement, so it asks first; asking must change nothing.
        model.startTumbler()
        await model.settle()
        XCTAssertNotNil(model.pendingReplacement, "switching modes while a session exists must ask first")
        XCTAssertEqual(model.markedIDs, [marked].compactMap { $0 }, "asking changes nothing")

        model.confirmReplacement()
        await model.settle()

        XCTAssertNil(model.pendingReplacement)
        XCTAssertEqual(model.markedIDs, [marked].compactMap { $0 })
        XCTAssertEqual(store.state?.marks, [marked].compactMap { $0 })
        XCTAssertNotEqual(model.currentAsset?.id, marked, "a marked photo is skipped while sorting")
    }

    // MARK: - Replacement confirmation (#56)

    /// Requesting a start while a session waits asks first and touches nothing;
    /// **Keep current** leaves the saved session and Undo exactly as they were.
    func testKeepCurrentLeavesTheUnfinishedSessionUntouched() async {
        let (model, library, store) = await bootstrapped()
        model.startNewest()
        await model.settle()
        model.apply(.queueDeletion)
        await model.settle()
        model.apply(.keep)
        await model.settle()

        let engineBefore = model.engine
        let resumableBefore = model.resumableSession
        let savedBefore = store.state
        let savesBefore = store.savedStates.count

        model.startTumbler()
        await model.settle()

        XCTAssertNotNil(model.pendingReplacement, "a replacement start must ask before it discards work")
        XCTAssertEqual(model.engine, engineBefore, "asking replaces nothing")
        XCTAssertEqual(model.resumableSession, resumableBefore)
        XCTAssertEqual(store.state, savedBefore)
        XCTAssertEqual(store.savedStates.count, savesBefore, "asking writes nothing")

        model.keepCurrentSession()
        await model.settle()

        XCTAssertNil(model.pendingReplacement)
        XCTAssertEqual(model.engine, engineBefore, "Keep current must leave the session byte-for-byte unchanged")
        XCTAssertEqual(model.resumableSession, resumableBefore)
        XCTAssertEqual(model.currentAsset?.id, engineBefore?.current?.id)
        XCTAssertEqual(store.state, savedBefore)
        XCTAssertEqual(store.savedStates.count, savesBefore)

        // And nothing was deleted while the confirmation was on screen.
        let allIDs = FakePhotoLibrary.demoDescriptors(count: 8).map(\.id)
        let stillThere = await library.existingAssetIDs(among: allIDs)
        XCTAssertEqual(stillThere, Set(allIDs), "the confirmation deletes nothing")
    }

    /// **Start new** replaces the position and session Undo, never the durable
    /// deletion list: every mark stays marked and the new traversal skips it.
    func testStartNewReplacesPositionAndUndoButKeepsEveryMark() async {
        let (model, library, store) = await bootstrapped()
        model.startNewest()
        await model.settle()
        let marked = model.currentAsset?.id
        model.apply(.queueDeletion)
        await model.settle()
        model.apply(.keep)
        await model.settle()
        XCTAssertTrue(model.engine?.undoStack.canUndo ?? false, "the old session has Undo history")

        model.startTumbler()
        await model.settle()
        XCTAssertNotNil(model.pendingReplacement)

        model.confirmReplacement()
        await model.settle()

        XCTAssertNil(model.pendingReplacement)
        XCTAssertEqual(model.engine?.mode, .tumbler)
        XCTAssertFalse(model.engine?.undoStack.canUndo ?? true, "session Undo is replaced")
        XCTAssertTrue(model.engine?.decidedIDs.isEmpty ?? false, "traversal is reset")
        XCTAssertEqual(model.markedIDs, [marked].compactMap { $0 }, "the deletion list is untouched")
        XCTAssertEqual(store.state?.marks, [marked].compactMap { $0 })
        XCTAssertNotEqual(model.currentAsset?.id, marked, "a marked photo stays skipped")

        // A replacement deletes nothing; only an explicit review commit can.
        let allIDs = FakePhotoLibrary.demoDescriptors(count: 8).map(\.id)
        let stillThere = await library.existingAssetIDs(among: allIDs)
        XCTAssertEqual(stillThere, Set(allIDs), "replacing a session deletes nothing")
    }

    /// A replacement can also start at one specific item; it asks first and,
    /// once confirmed, keeps the deletion list while moving the position.
    func testStartingAtASpecificItemAsksBeforeReplacingTheSession() async {
        let (model, _, store) = await bootstrapped()
        model.startNewest()
        await model.settle()
        model.apply(.keep)
        await model.settle()
        let marked = model.currentAsset?.id
        model.apply(.queueDeletion)
        await model.settle()
        let positionBeforeRequest = model.currentAsset?.id
        let target = "fake-0"

        model.startFrom(assetID: target)
        await model.settle()

        XCTAssertNotNil(model.pendingReplacement, "starting at a specific item is a replacement too")
        XCTAssertEqual(model.currentAsset?.id, positionBeforeRequest, "requesting moves nothing")
        XCTAssertNotEqual(positionBeforeRequest, marked)

        model.confirmReplacement()
        await model.settle()

        XCTAssertEqual(model.currentAsset?.id, target)
        XCTAssertEqual(model.markedIDs, [marked].compactMap { $0 })
        XCTAssertEqual(store.state?.marks, [marked].compactMap { $0 })
    }

    /// With no unfinished session there is nothing to replace, so the first start
    /// must happen without a confirmation.
    func testNoConfirmationWithoutAnUnfinishedSession() async {
        let (model, _, _) = await bootstrapped()
        XCTAssertFalse(model.hasUnfinishedSession)

        model.startNewest()
        await model.settle()

        XCTAssertNil(model.pendingReplacement, "a first start has nothing to replace")
        XCTAssertEqual(model.route, .viewer)
    }

    /// Every kind of replacement start — Newest, Oldest, Random and a specific
    /// item — asks before it discards the unfinished session.
    func testEveryReplacementEntryPointAsksFirst() async {
        func assertAsks(_ start: (AppModel) -> Void) async {
            let (model, _, _) = await bootstrapped()
            model.startNewest()
            await model.settle()
            XCTAssertNil(model.pendingReplacement, "the first start has nothing to replace")

            start(model)
            await model.settle()
            XCTAssertNotNil(model.pendingReplacement, "this start must ask before it replaces")

            model.keepCurrentSession()
            await model.settle()
            XCTAssertNil(model.pendingReplacement)
        }

        await assertAsks { $0.startNewest() }
        await assertAsks { $0.startOldest() }
        await assertAsks { $0.startTumbler() }
        await assertAsks { $0.startFrom(assetID: "fake-0") }
    }

    /// A marked item cannot start a session at all, so it is refused rather than
    /// becoming a replacement request.
    func testStartingAtAMarkedItemIsRefusedWithoutAConfirmation() async {
        let (model, _, _) = await bootstrapped()
        model.startNewest()
        await model.settle()
        let marked = model.currentAsset?.id
        model.apply(.queueDeletion)
        await model.settle()

        model.startFrom(assetID: marked ?? "")
        await model.settle()

        XCTAssertNil(model.pendingReplacement, "a marked item cannot start a session, so there is nothing to confirm")
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.markedIDs, [marked].compactMap { $0 })
    }

    func testMarkedPhotosAreSkippedAfterRestart() async {
        let store = InMemorySessionStore()
        let first = await bootstrapped(store: store)
        first.model.startNewest()
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
        model.startNewest()
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
        model.startNewest()
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
        model.startNewest()
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
        first.model.startNewest()
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
        made.model.startNewest()
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
        // Relaunching means the same device library and the same store, so the
        // library instance is shared deliberately: reusing a fresh one would
        // "restore" the photo and test nothing.
        let library = FakePhotoLibrary.demo(count: 8)
        let store = InMemorySessionStore()
        let made = await bootstrapped(library: library, store: store)
        made.model.startNewest()
        await made.model.settle()
        let deleted = made.model.currentAsset?.id
        made.model.apply(.queueDeletion)
        await made.model.settle()
        XCTAssertEqual(made.model.markedIDs, [deleted].compactMap { $0 })

        // The library deletion succeeds but the local save fails, as if the app
        // died between the PhotoKit effect and the write.
        store.failsWrites = true
        await made.model.confirmDeletion()
        XCTAssertNotNil(made.model.persistenceNotice)
        XCTAssertEqual(made.model.statistics.lifetimeDeletedCount, 1)
        XCTAssertEqual(store.state?.marks, [deleted].compactMap { $0 }, "the stale list is still stored")

        store.failsWrites = false
        let relaunched = await bootstrapped(library: library, store: store)
        XCTAssertEqual(relaunched.model.markedIDs, [], "the vanished mark is reconciled away")
        XCTAssertEqual(
            relaunched.model.statistics.lifetimeDeletedCount,
            1,
            "reconciliation never counts the deletion a second time"
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
        made.model.startNewest()
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
        made.model.startNewest()
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

        // 4. Switching mode resets traversal and Undo, never the marks. It is a
        //    replacement, so it is confirmed first.
        model.startTumbler()
        await model.settle()
        XCTAssertNotNil(model.pendingReplacement)
        model.confirmReplacement()
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

    // MARK: - Saved sessions, migration and the fixed pool (#45)

    /// A relaunch is a fresh model over the same store and the same library.
    /// Every piece of saved progress — pool, filter, position, marks and Undo —
    /// must survive, and no photo may be deleted without an explicit
    /// confirmation.
    func testSavedProgressSurvivesRelaunchWithPoolFilterAndUndoAndNothingIsDeleted() async {
        let library = FakePhotoLibrary.demo(count: 6)
        let pool = ["fake-0", "fake-1", "fake-2", "fake-3", "fake-4", "fake-5"]
        let store = InMemorySessionStore(
            content: .state(
                PersistedState(
                    marks: ["fake-5"],
                    session: PersistedSession(
                        currentAssetID: "fake-4",
                        direction: .older,
                        decidedIDs: ["fake-5"],
                        keptIDs: [],
                        undoEntries: [UndoEntry(assetID: "fake-5", effect: .queuedDeletion)],
                        filterCategories: [.screenshot, .otherPhoto],
                        poolIDs: pool
                    )
                )
            )
        )
        let (model, lib, _) = await bootstrapped(library: library, store: store)

        XCTAssertNotNil(model.resumableSession)
        XCTAssertEqual(model.resumableSession?.filterCategories, [.screenshot, .otherPhoto])
        XCTAssertEqual(model.resumableSession?.poolIDs, pool, "the exact stable-ID pool round-trips")

        model.resumeSession()
        XCTAssertEqual(model.route, .viewer)
        XCTAssertEqual(model.currentAsset?.id, "fake-4", "position survives relaunch")
        XCTAssertEqual(model.markedIDs, ["fake-5"], "the deletion list survives relaunch")
        XCTAssertTrue(model.engine?.undoStack.canUndo ?? false, "Undo survives relaunch")
        XCTAssertEqual(model.engine?.poolIDs, Set(pool), "the engine stays confined to the pool")

        // The fixed pool keeps the traversal inside its members: the marked
        // photo is skipped and nothing outside the pool is offered.
        var seen: [String] = []
        while let id = model.currentAsset?.id {
            seen.append(id)
            model.apply(.keep)
            await model.settle()
        }
        XCTAssertFalse(seen.contains("fake-5"), "a marked photo is never presented again")

        // Nothing was deleted: sorting never mutates the library, and no
        // confirmation ever happened.
        let allIDs = FakePhotoLibrary.demoDescriptors(count: 6).map(\.id)
        let stillThere = await lib.existingAssetIDs(among: allIDs)
        XCTAssertEqual(stillThere, Set(allIDs), "relaunch and sorting delete nothing")
    }

    /// A store reporting already-migrated state is saved to finish the migration
    /// and keeps every piece of progress; the library is untouched.
    func testMigratedStateIsSavedAndPreservesProgressWithoutDeletingAnything() async {
        let library = FakePhotoLibrary.demo(count: 6)
        let store = InMemorySessionStore(
            content: .migrated(
                PersistedState(
                    schemaVersion: PersistedState.currentSchemaVersion,
                    marks: ["fake-1"],
                    session: PersistedSession(
                        currentAssetID: "fake-4",
                        direction: .older,
                        decidedIDs: ["fake-5"],
                        keptIDs: ["fake-5"],
                        undoEntries: [UndoEntry(assetID: "fake-5", effect: .kept)],
                        filterCategories: [.video],
                        poolIDs: ["fake-0", "fake-2", "fake-4", "fake-5"]
                    )
                )
            )
        )
        let (model, lib, _) = await bootstrapped(library: library, store: store)

        XCTAssertFalse(store.savedStates.isEmpty, "the migration is completed by a save")
        XCTAssertNotNil(model.resumableSession)
        XCTAssertEqual(model.resumableSession?.filterCategories, [.video])
        XCTAssertEqual(model.resumableSession?.poolIDs, ["fake-0", "fake-2", "fake-4", "fake-5"])

        model.resumeSession()
        XCTAssertEqual(model.currentAsset?.id, "fake-4")
        XCTAssertEqual(model.markedIDs, ["fake-1"])
        XCTAssertTrue(model.engine?.undoStack.canUndo ?? false)

        let allIDs = FakePhotoLibrary.demoDescriptors(count: 6).map(\.id)
        let stillThere = await lib.existingAssetIDs(among: allIDs)
        XCTAssertEqual(stillThere, Set(allIDs), "migration and relaunch delete nothing")
    }

    // MARK: - Home filters and the filtered pool (#46)

    /// Each Home media choice opens its documented defaults, and choosing a
    /// preset again starts clean rather than reusing the last exclusions.
    func testHomePresetsStartFromDocumentedDefaultsAndNeverReuseExclusions() async {
        let (model, _, _) = await bootstrapped(library: FakePhotoLibrary.mixedMedia())

        model.showFilters(.everything)
        XCTAssertEqual(model.route, .filters)
        XCTAssertEqual(model.filter.categories, MediaFilter.everything.categories)
        XCTAssertTrue(model.filter.contains(.video), "Everything includes videos")

        model.showFilters(.photos)
        XCTAssertEqual(model.filter.categories, MediaFilter.photos.categories)
        XCTAssertFalse(model.filter.contains(.video), "Photos leaves videos out")

        // Exclude a category, then choose the same preset again: the exclusion
        // must not leak into the fresh attempt.
        model.toggleFilterCategory(.screenshot)
        XCTAssertFalse(model.filter.contains(.screenshot))
        model.showFilters(.photos)
        XCTAssertTrue(model.filter.contains(.screenshot), "a fresh preset drops the previous exclusion")

        model.showFilters(.videos)
        XCTAssertEqual(model.filter.categories, [.video], "Videos selects only the video category")
    }

    /// Toggle changes one category, Only isolates one, and the summary names the
    /// selection and its matching count.
    func testFilterRowsToggleIndependentlyAndOnlyIsolates() async {
        let (model, _, _) = await bootstrapped(library: FakePhotoLibrary.mixedMedia())
        model.showFilters(.everything)

        model.toggleFilterCategory(.video)
        XCTAssertFalse(model.filter.contains(.video))
        XCTAssertTrue(model.filter.contains(.screenshot), "toggling one row leaves the others alone")
        XCTAssertTrue(model.filter.contains(.livePhoto))

        model.onlyFilterCategory(.panorama)
        XCTAssertEqual(model.filter.categories, [.panorama], "Only replaces the whole selection")
        XCTAssertEqual(model.filterSummary, "Panoramas · 1 item")

        model.showFilters(.videos)
        XCTAssertEqual(model.filterSummary, "Videos · 1 item")

        model.showFilters(.photos)
        XCTAssertEqual(model.filterSummary, "Photos · 6 items")
    }

    /// Continue is a no-op when nothing is selected, and the empty filter is a
    /// clear state rather than a hidden crash.
    func testContinueIsRefusedWhenNothingIsSelected() async {
        let (model, _, _) = await bootstrapped(library: FakePhotoLibrary.mixedMedia())
        model.showFilters(.videos)
        model.clearFilter()

        XCTAssertTrue(model.filter.isEmpty)
        XCTAssertEqual(model.filteredCount, 0)
        model.continueToChoosePhoto()

        XCTAssertEqual(model.route, .filters, "an empty filter cannot reach the grid")
    }

    /// Starting a session captures the filtered stable-ID pool and its filter
    /// categories; the saved session carries exactly those.
    func testStartingASessionCapturesTheFilteredPool() async {
        let (model, _, store) = await bootstrapped(library: FakePhotoLibrary.mixedMedia())

        model.showFilters(.videos)
        XCTAssertEqual(model.filteredCount, 1)
        model.startNewest()
        await model.settle()

        XCTAssertEqual(model.route, .viewer)
        XCTAssertEqual(model.engine?.order.ids, ["mixed-video"])
        XCTAssertEqual(store.state?.session?.poolIDs, ["mixed-video"])
        XCTAssertEqual(store.state?.session?.filterCategories, [.video])
        XCTAssertEqual(model.currentAsset?.id, "mixed-video")
    }

    /// Continue sorting restores the saved filters and the captured pool, not
    /// whatever the Home filters happen to show now.
    func testContinueRestoresTheSavedFiltersAndPool() async {
        let library = FakePhotoLibrary.mixedMedia()
        let store = InMemorySessionStore()

        let first = await bootstrapped(library: library, store: store)
        first.model.showFilters(.photos)
        first.model.startNewest()
        await first.model.settle()
        first.model.apply(.keep)
        await first.model.settle()

        let savedPool = store.state?.session?.poolIDs
        XCTAssertEqual(Set(savedPool ?? []), Set(FakePhotoLibrary.mixedMediaDescriptors().filter { !$0.isVideo }.map(\.id)))

        // A relaunch starts with the default filter; Continue must restore the
        // session's own saved filters and pool.
        let second = AppModel(library: library, store: store, defaults: isolatedDefaults())
        await second.bootstrap()
        second.showFilters(.everything)
        XCTAssertTrue(second.filter.contains(.video), "the Home filter starts from its own preset")

        second.resumeSession()
        XCTAssertEqual(second.route, .viewer)
        XCTAssertEqual(second.filter.categories, MediaFilter.photos.categories, "the session's saved filters are restored")
        XCTAssertEqual(second.resumableSession?.poolIDs, savedPool, "the captured pool is restored")
        XCTAssertEqual(second.engine?.poolIDs, Set(savedPool ?? []))
    }

    /// A captured pool is fixed: library assets outside it are arrivals that
    /// wait for a new session instead of being appended to this one.
    func testAssetsOutsideTheCapturedPoolAreNeverOffered() async {
        let library = FakePhotoLibrary.demo(count: 6)
        let store = InMemorySessionStore(
            content: .state(
                PersistedState(
                    marks: [],
                    session: PersistedSession(
                        currentAssetID: "fake-2",
                        direction: .older,
                        filterCategories: [.otherPhoto, .livePhoto],
                        poolIDs: ["fake-2"]
                    )
                )
            )
        )
        let (model, _, _) = await bootstrapped(library: library, store: store)
        model.resumeSession()

        var seen: [String] = []
        while let id = model.currentAsset?.id {
            seen.append(id)
            model.apply(.keep)
            await model.settle()
        }
        XCTAssertEqual(seen, ["fake-2"], "only the captured member is walked")
        XCTAssertTrue(model.engine?.isFinished ?? false)
    }

    /// A captured member that left the library is dropped while the rest of the
    /// session survives untouched.
    func testAVanishedPoolMemberReconcilesWithoutLosingTheSession() async {
        let store = InMemorySessionStore(
            content: .state(
                PersistedState(
                    marks: [],
                    session: PersistedSession(
                        currentAssetID: "mixed-video",
                        direction: .older,
                        filterCategories: [.video, .otherPhoto],
                        poolIDs: ["ghost-id", "mixed-video", "mixed-other-photo"]
                    )
                )
            )
        )
        let (model, _, _) = await bootstrapped(library: FakePhotoLibrary.mixedMedia(), store: store)

        XCTAssertEqual(
            model.resumableSession?.poolIDs?.sorted(),
            ["mixed-other-photo", "mixed-video"],
            "only the vanished member is dropped"
        )
        model.resumeSession()
        XCTAssertEqual(model.route, .viewer)
        XCTAssertEqual(model.currentAsset?.id, "mixed-video")
        XCTAssertNotNil(model.engine)
    }

    // MARK: - Random traversal (#57)

    /// Random builds one persisted order. Navigation, termination and relaunch
    /// all come back to the same order and the same position, and the walk
    /// never serves a photo twice.
    func testPersistedRandomOrderSurvivesNavigationAndRelaunch() async throws {
        let library = FakePhotoLibrary.demo(count: 6)
        let store = InMemorySessionStore()

        // First launch: start Random, make one decision, then leave the viewer.
        let first = await bootstrapped(library: library, store: store)
        first.model.startTumbler()
        await first.model.settle()
        XCTAssertEqual(first.model.route, .viewer)
        XCTAssertEqual(first.model.engine?.mode, .tumbler)
        let seed = try XCTUnwrap(first.model.engine?.tumbler?.seed)
        XCTAssertEqual(store.state?.session?.tumbler?.seed, seed, "the seed is saved once, at session start")

        first.model.apply(.keep)
        await first.model.settle()
        let savedPosition = try XCTUnwrap(first.model.currentAsset?.id)
        XCTAssertEqual(store.state?.session?.currentAssetID, savedPosition)
        XCTAssertEqual(store.state?.session?.tumbler?.seed, seed, "a decision never reseeds the order")

        // Navigation away and back keeps the same order and position.
        first.model.closeViewer()
        XCTAssertEqual(first.model.route, .entry)
        first.model.resumeSession()
        XCTAssertEqual(first.model.currentAsset?.id, savedPosition, "navigation restores the position")
        XCTAssertEqual(first.model.engine?.tumbler?.seed, seed, "navigation keeps the same order")

        // What the saved order still has to serve, in order.
        var probe = try XCTUnwrap(first.model.engine)
        var expected: [String] = []
        while let id = probe.current?.id {
            expected.append(id)
            probe.apply(.keep)
        }
        XCTAssertEqual(expected.count, 5, "one decision left five photos to serve")
        XCTAssertEqual(expected.count, Set(expected).count)

        // Termination and relaunch: a fresh model over the same store and library.
        let second = await bootstrapped(library: library, store: store)
        XCTAssertEqual(second.model.resumableSession?.tumbler?.seed, seed, "the same order survives a relaunch")
        second.model.resumeSession()
        XCTAssertEqual(second.model.route, .viewer)
        XCTAssertEqual(second.model.currentAsset?.id, savedPosition, "the position survives a relaunch")

        var actual: [String] = []
        while let id = second.model.currentAsset?.id {
            actual.append(id)
            second.model.apply(.keep)
            await second.model.settle()
        }
        XCTAssertEqual(actual, expected, "the resumed Random order is exactly the saved one")
        XCTAssertEqual(actual.count, Set(actual).count, "Random never serves a photo twice")
    }

    /// A saved Random session with a vanished current asset and a vanished mark
    /// reconciles safely: the ghost members drop, the surviving mark stays,
    /// nothing is deleted or counted, and the walk still never repeats.
    func testReconcilingARandomSessionDropsVanishedMembersAndCreditsNoDeletion() async {
        let library = FakePhotoLibrary.demo(count: 6)
        let ids = FakePhotoLibrary.demoDescriptors(count: 6).map(\.id)
        let store = InMemorySessionStore(
            content: .state(
                PersistedState(
                    marks: ["fake-0", "ghost-mark"],
                    session: PersistedSession(
                        currentAssetID: "ghost-current",
                        direction: .older,
                        mode: .tumbler,
                        tumbler: TumblerPlan(assetIDs: ids, seed: 31),
                        poolIDs: ids
                    )
                )
            )
        )
        let (model, lib, _) = await bootstrapped(library: library, store: store)

        XCTAssertEqual(model.markedIDs, ["fake-0"], "a vanished mark is dropped, never counted")
        XCTAssertEqual(model.statistics.lifetimeDeletedCount, 0, "reconciliation deletes nothing")
        XCTAssertEqual(model.statistics.currentSessionDeletedCount, 0)

        model.resumeSession()
        XCTAssertEqual(model.route, .viewer)

        var seen: [String] = []
        while let id = model.currentAsset?.id {
            seen.append(id)
            model.apply(.keep)
            await model.settle()
        }
        XCTAssertEqual(seen.count, Set(seen).count, "Random never repeats a photo")
        XCTAssertEqual(Set(seen).count, 5, "the marked photo is skipped and the vanished current is gone")
        XCTAssertFalse(seen.contains("fake-0"))

        let stillThere = await lib.existingAssetIDs(among: ids)
        XCTAssertEqual(stillThere, Set(ids), "reconciliation never mutates the library")
    }
}
