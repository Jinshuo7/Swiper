import XCTest
@testable import SWIPRKit

final class AssetReconcilerTests: XCTestCase {
    func testDropsExternallyRemovedAssetsFromMarksAndDecisionHistory() {
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
            keptIDs: ["c"]
        )
        let reconciled = AssetReconciler.reconcile(persisted, order: liveOrder, marks: ["b", "d"])
        XCTAssertEqual(reconciled.externallyRemovedIDs, ["d"])
        XCTAssertEqual(reconciled.marks, ["b"])
        XCTAssertFalse(reconciled.session.decidedIDs.contains("d"))
        XCTAssertEqual(reconciled.session.keptIDs, ["c"])
    }

    func testLimitedAccessKeepsMarksAndMembershipOutsideTheVisibleSnapshot() {
        let liveOrder = LibraryOrder([
            TestLibrary.descriptor(id: "a", dayOffset: 0),
            TestLibrary.descriptor(id: "b", dayOffset: 1),
        ])
        let state = PersistedState(
            marks: ["a", "hidden"],
            session: PersistedSession(
                currentAssetID: "b",
                direction: .older,
                decidedIDs: ["hidden"],
                keptIDs: ["hidden"],
                poolIDs: ["a", "b", "hidden"]
            )
        )
        let reconciled = AssetReconciler.reconcile(
            state,
            order: liveOrder,
            libraryAccessIsLimited: true
        )
        XCTAssertEqual(reconciled.state.marks, ["a", "hidden"], "a hidden mark is not dropped")
        XCTAssertEqual(reconciled.state.session?.decidedIDs, ["hidden"])
        XCTAssertEqual(reconciled.state.session?.keptIDs, ["hidden"])
        XCTAssertEqual(reconciled.state.session?.poolIDs, ["a", "b", "hidden"])
        XCTAssertEqual(reconciled.state.session?.currentAssetID, "b")
        XCTAssertEqual(reconciled.externallyRemovedIDs, [], "Limited access credits nothing as removed")
    }

    func testLimitedAccessKeepsAMarksOnlyStateWhole() {
        let liveOrder = LibraryOrder([TestLibrary.descriptor(id: "a", dayOffset: 0)])
        let state = PersistedState(marks: ["a", "hidden"])
        let reconciled = AssetReconciler.reconcile(
            state,
            order: liveOrder,
            libraryAccessIsLimited: true
        )
        XCTAssertEqual(reconciled.state.marks, ["a", "hidden"])
        XCTAssertEqual(reconciled.externallyRemovedIDs, [])
    }

    func testLimitedAccessKeepsThePendingTumblerPlan() {
        let liveOrder = LibraryOrder([TestLibrary.descriptor(id: "a", dayOffset: 0)])
        let state = PersistedState(
            session: PersistedSession(
                currentAssetID: "a",
                mode: .tumbler,
                tumbler: TumblerPlan(assetIDs: ["a", "hidden"], seed: 3)
            )
        )
        let reconciled = AssetReconciler.reconcile(
            state,
            order: liveOrder,
            libraryAccessIsLimited: true
        )
        XCTAssertEqual(
            reconciled.state.session?.tumbler?.remaining.count,
            2,
            "a hidden plan member is preserved, not reconciled away"
        )
    }

    func testLimitedAccessDoesNotFinishASessionWithHiddenUndecidedMembers() {
        let liveOrder = LibraryOrder([TestLibrary.descriptor(id: "a", dayOffset: 0)])
        let state = PersistedState(
            session: PersistedSession(
                currentAssetID: "a",
                direction: .older,
                decidedIDs: ["a"],
                poolIDs: ["a", "hidden"]
            )
        )
        let reconciled = AssetReconciler.reconcile(
            state,
            order: liveOrder,
            libraryAccessIsLimited: true
        )
        XCTAssertEqual(
            reconciled.state.session?.isFinished,
            false,
            "a hidden undecided pool member keeps the session open"
        )
    }

    func testStateReconcileKeepsMarksAndSessionCoherent() {
        let liveOrder = LibraryOrder(TestLibrary.sequential())
        let state = PersistedState(
            marks: ["b", "vanished"],
            session: PersistedSession(currentAssetID: "c", direction: .older, decidedIDs: ["c"])
        )
        let reconciled = AssetReconciler.reconcile(state, order: liveOrder)
        XCTAssertEqual(reconciled.state.marks, ["b"])
        XCTAssertEqual(reconciled.state.session?.currentAssetID, "c")
        XCTAssertEqual(reconciled.externallyRemovedIDs, ["vanished"])
    }

    func testStateReconcileKeepsMarksWhenThereIsNoSession() {
        let liveOrder = LibraryOrder(TestLibrary.sequential())
        let state = PersistedState(marks: ["a", "gone", "e"])
        let reconciled = AssetReconciler.reconcile(state, order: liveOrder)
        XCTAssertEqual(reconciled.state.marks, ["a", "e"])
        XCTAssertNil(reconciled.state.session)
        XCTAssertEqual(reconciled.externallyRemovedIDs, ["gone"])
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

    func testRecoverySkipsMarkedAssets() {
        let liveOrder = LibraryOrder(TestLibrary.sequential())
        let persisted = PersistedSession(
            currentAssetID: "deleted",
            currentAssetDate: TestLibrary.descriptor(id: "deleted", dayOffset: 3).creationDate,
            direction: .older
        )
        let reconciled = AssetReconciler.reconcile(persisted, order: liveOrder, marks: ["c", "d"])
        XCTAssertEqual(reconciled.session.currentAssetID, "b")
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
        let persisted = PersistedSession(currentAssetID: "a", direction: .older)
        let reconciled = AssetReconciler.reconcile(persisted, order: .empty, marks: ["a"])
        XCTAssertNil(reconciled.session.currentAssetID)
        XCTAssertTrue(reconciled.marks.isEmpty)
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

    func testSessionIsFinishedWhenEveryRemainingAssetIsMarked() {
        let liveOrder = LibraryOrder(TestLibrary.sequential())
        let persisted = PersistedSession(currentAssetID: "deleted", direction: .older)
        let reconciled = AssetReconciler.reconcile(
            persisted,
            order: liveOrder,
            marks: liveOrder.ids
        )
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

    // MARK: - Captured pool reconciliation

    func testCapturedPoolDropsInaccessibleIDsAndKeepsNewArrivalsOut() {
        // The live library gained "f" and lost "d" since the pool was captured.
        let liveOrder = LibraryOrder([
            TestLibrary.descriptor(id: "a", dayOffset: 0),
            TestLibrary.descriptor(id: "b", dayOffset: 1),
            TestLibrary.descriptor(id: "c", dayOffset: 2),
            TestLibrary.descriptor(id: "e", dayOffset: 4),
            TestLibrary.descriptor(id: "f", dayOffset: 5),
        ])
        let persisted = PersistedSession(
            currentAssetID: "b",
            direction: .older,
            poolIDs: ["a", "b", "c", "d"]
        )
        let reconciled = AssetReconciler.reconcile(persisted, order: liveOrder)
        XCTAssertEqual(
            reconciled.session.poolIDs,
            ["a", "b", "c"],
            "inaccessible pool members drop and new arrivals never enter"
        )
        XCTAssertEqual(reconciled.session.currentAssetID, "b")
    }

    func testMissingCurrentAssetRecoversWithinThePool() {
        // Pool: a, b, c. "c" (the current asset) vanished; d and e are outside
        // the pool and must never be offered as a recovery target.
        let liveOrder = LibraryOrder([
            TestLibrary.descriptor(id: "a", dayOffset: 0),
            TestLibrary.descriptor(id: "b", dayOffset: 1),
            TestLibrary.descriptor(id: "d", dayOffset: 3),
            TestLibrary.descriptor(id: "e", dayOffset: 4),
        ])
        let persisted = PersistedSession(
            currentAssetID: "c",
            currentAssetDate: TestLibrary.descriptor(id: "c", dayOffset: 2).creationDate,
            direction: .older,
            poolIDs: ["a", "b", "c"]
        )
        let reconciled = AssetReconciler.reconcile(persisted, order: liveOrder)
        XCTAssertEqual(reconciled.session.poolIDs, ["a", "b"])
        XCTAssertEqual(reconciled.session.currentAssetID, "b", "recovery stays inside the pool")
    }

    func testFilterCategoriesSurviveReconciliation() {
        let liveOrder = TestLibrary.order()
        let persisted = PersistedSession(
            currentAssetID: "c",
            direction: .older,
            filterCategories: [.screenshot, .video],
            poolIDs: ["a", "b", "c"]
        )
        let reconciled = AssetReconciler.reconcile(persisted, order: liveOrder)
        XCTAssertEqual(reconciled.session.filterCategories, [.screenshot, .video])
    }

    func testLegacySessionWithoutPoolKeepsTheFullOrder() {
        let liveOrder = TestLibrary.order()
        let persisted = PersistedSession(
            currentAssetID: "c",
            direction: .older,
            poolIDs: nil
        )
        let reconciled = AssetReconciler.reconcile(persisted, order: liveOrder)
        XCTAssertNil(reconciled.session.poolIDs, "no pool means the whole library order")
        XCTAssertEqual(reconciled.session.currentAssetID, "c")
    }
}
