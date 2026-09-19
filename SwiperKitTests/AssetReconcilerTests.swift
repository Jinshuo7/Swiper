import XCTest
@testable import SwiperKit

final class AssetReconcilerTests: XCTestCase {
    func testDropsExternallyRemovedAssetsFromQueueAndDecisionHistory() {
        let liveOrder = LibraryOrder([
            TestLibrary.descriptor(id: "a", dayOffset: 0),
            TestLibrary.descriptor(id: "b", dayOffset: 1),
            TestLibrary.descriptor(id: "c", dayOffset: 2),
            TestLibrary.descriptor(id: "e", dayOffset: 4),
        ])
        let persisted = PersistedSession(
            currentAssetID: "d",
            currentAssetDate: TestLibrary.descriptor(id: "d", dayOffset: 3).creationDate,
            direction: .older,
            decidedIDs: ["b", "c", "d"],
            keptIDs: ["c"],
            queueIDs: ["b", "d"]
        )
        let reconciled = AssetReconciler.reconcile(persisted, order: liveOrder)
        XCTAssertEqual(reconciled.externallyRemovedIDs, ["d"])
        XCTAssertEqual(reconciled.session.queueIDs, ["b"])
        XCTAssertFalse(reconciled.session.decidedIDs.contains("d"))
        XCTAssertEqual(reconciled.session.keptIDs, ["c"])
    }

    func testRecoversMissingCurrentAssetToNearestUndecided() {
        let liveOrder = LibraryOrder(TestLibrary.sequential())
        let persisted = PersistedSession(
            currentAssetID: "deleted",
            currentAssetDate: TestLibrary.descriptor(id: "deleted", dayOffset: 2).creationDate,
            direction: .older,
            decidedIDs: ["d"]
        )
        let reconciled = AssetReconciler.reconcile(persisted, order: liveOrder)
        // Closest older asset to day 2 is c (undecided).
        XCTAssertEqual(reconciled.session.currentAssetID, "c")
    }

    func testKeepsCurrentAssetWhenStillPresent() {
        let liveOrder = LibraryOrder(TestLibrary.sequential())
        let persisted = PersistedSession(currentAssetID: "c", direction: .older)
        let reconciled = AssetReconciler.reconcile(persisted, order: liveOrder)
        XCTAssertEqual(reconciled.session.currentAssetID, "c")
        XCTAssertEqual(reconciled.session.currentAssetDate, liveOrder.asset(byID: "c")?.creationDate)
    }

    func testMissingCurrentFallsBackOppositeDirectionWhenPreferredSideIsDecided() {
        let liveOrder = LibraryOrder(TestLibrary.sequential())
        let persisted = PersistedSession(
            currentAssetID: "deleted",
            currentAssetDate: TestLibrary.descriptor(id: "deleted", dayOffset: 3).creationDate,
            direction: .older,
            decidedIDs: ["a", "b", "c", "d"]
        )
        let reconciled = AssetReconciler.reconcile(persisted, order: liveOrder)
        XCTAssertEqual(reconciled.session.currentAssetID, "e")
    }

    func testHandlesEmptyLibrary() {
        let persisted = PersistedSession(currentAssetID: "a", direction: .older, queueIDs: ["a"])
        let reconciled = AssetReconciler.reconcile(persisted, order: .empty)
        XCTAssertNil(reconciled.session.currentAssetID)
        XCTAssertTrue(reconciled.session.queueIDs.isEmpty)
        XCTAssertEqual(reconciled.externallyRemovedIDs, ["a"])
    }

    func testMissingCurrentMarksSessionFinishedWhenNothingUndecidedRemains() {
        let liveOrder = LibraryOrder(TestLibrary.sequential())
        let persisted = PersistedSession(
            currentAssetID: "deleted",
            currentAssetDate: TestLibrary.descriptor(id: "deleted", dayOffset: 6).creationDate,
            decidedIDs: liveOrder.ids
        )
        let reconciled = AssetReconciler.reconcile(persisted, order: liveOrder)
        XCTAssertNil(reconciled.session.currentAssetID)
        XCTAssertTrue(reconciled.session.isFinished)
    }

    func testReconcilesTumblerPlanWithLibraryChanges() {
        let liveOrder = LibraryOrder([
            TestLibrary.descriptor(id: "a", dayOffset: 0),
            TestLibrary.descriptor(id: "b", dayOffset: 1),
            TestLibrary.descriptor(id: "f", dayOffset: 5),
        ])
        var plan = TumblerPlan(assetIDs: ["a", "b", "c", "d"], seed: 3)
        _ = plan.next()
        let persisted = PersistedSession(mode: .tumbler, tumbler: plan)
        let reconciled = AssetReconciler.reconcile(persisted, order: liveOrder)
        let remaining = reconciled.session.tumbler?.remaining ?? []
        XCTAssertFalse(remaining.contains("c"))
        XCTAssertFalse(remaining.contains("d"))
        XCTAssertFalse(remaining.contains("f"))
    }
}
