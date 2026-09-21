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
    private func makeModel(
        library: FakePhotoLibrary = FakePhotoLibrary.demo(count: 8),
        store: InMemorySessionStore = InMemorySessionStore()
    ) -> (model: AppModel, library: FakePhotoLibrary, store: InMemorySessionStore) {
        let model = AppModel(library: library, store: store)
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
}
