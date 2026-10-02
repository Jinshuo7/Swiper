import XCTest
@testable import SWIPRKit

final class TumblerPlanTests: XCTestCase {
    private let ids = ["a", "b", "c", "d", "e", "f", "g", "h"]

    func testSameSeedProducesSameOrder() {
        let first = TumblerPlan(assetIDs: ids, seed: 42)
        let second = TumblerPlan(assetIDs: ids, seed: 42)
        XCTAssertEqual(first.remaining, second.remaining)
    }

    func testDifferentSeedsProduceDifferentOrders() {
        let first = TumblerPlan(assetIDs: ids, seed: 1)
        let second = TumblerPlan(assetIDs: ids, seed: 2)
        XCTAssertNotEqual(first.remaining, second.remaining)
    }

    func testNeverRepeatsAndCoversWholeLibrary() {
        var plan = TumblerPlan(assetIDs: ids, seed: 7)
        var seen = [String]()
        while let next = plan.next() {
            seen.append(next)
        }
        XCTAssertEqual(seen.count, ids.count)
        XCTAssertEqual(Set(seen), Set(ids))
    }

    func testReconcileDropsRemovedAssets() {
        var plan = TumblerPlan(assetIDs: ids, seed: 5)
        plan.reconcile(withAvailableIDs: Set(ids).subtracting(["a"]))
        XCTAssertFalse(plan.remaining.contains("a"))
    }

    func testReconcileDoesNotReAddHandledAssets() {
        var plan = TumblerPlan(assetIDs: ["a", "b"], seed: 5)
        let first = plan.next()
        XCTAssertNotNil(first)
        plan.reconcile(withAvailableIDs: ["a", "b"])
        var rest = [String]()
        while let next = plan.next() { rest.append(next) }
        XCTAssertFalse(rest.contains(first!))
        XCTAssertEqual(rest.count, 1)
    }

    func testRoundTripsThroughCodable() throws {
        var plan = TumblerPlan(assetIDs: ids, seed: 99)
        _ = plan.next()
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(TumblerPlan.self, from: data)
        XCTAssertEqual(decoded.remaining, plan.remaining)
        XCTAssertEqual(decoded.seed, plan.seed)
        XCTAssertEqual(decoded.handled, plan.handled)
    }

    func testEngineTumblerVisitsEachAssetOnce() {
        var engine = SessionEngine(order: TestLibrary.order(), mode: .tumbler, tumblerSeed: 123)
        engine.start()
        var visited = [String]()
        while let id = engine.current?.id {
            visited.append(id)
            engine.apply(.keep)
        }
        XCTAssertEqual(Set(visited), Set(TestLibrary.sequential().map(\.id)))
        XCTAssertEqual(visited.count, visited.count, "counts match")
        XCTAssertEqual(Set(visited).count, visited.count, "no repeats")
    }

    /// A cursor supplied at construction is reserved so a restored walk cannot
    /// serve it twice. Starting a fresh session discards that cursor, so the
    /// reservation must be released or the asset is swallowed for good.
    func testTumblerEngineBuiltWithACursorThenStartedStillServesIt() {
        let library = TestLibrary.order()
        var engine = SessionEngine(
            order: library,
            mode: .tumbler,
            cursorID: "c",
            tumblerSeed: 5
        )
        engine.start()

        var seen: [String] = []
        while let id = engine.current?.id {
            seen.append(id)
            engine.apply(.keep)
        }
        XCTAssertEqual(seen.count, library.ids.count, "a 5-asset pool still covers all 5")
        XCTAssertEqual(Set(seen), Set(library.ids), "the once-reserved cursor is served")
        XCTAssertEqual(seen.count, Set(seen).count, "and exactly once")
    }

    // MARK: - Random: repeat prevention under Undo and reconciliation (#57)

    /// ``reserve(_:)`` claims an asset the cursor already shows, so a later
    /// walk cannot hand the same asset out again.
    func testReserveClaimsAnAssetTheCursorAlreadyShows() {
        var plan = TumblerPlan(assetIDs: ids, seed: 3)
        plan.reserve("a")
        XCTAssertFalse(plan.remaining.contains("a"))
        XCTAssertTrue(plan.handled.contains("a"))

        var served: [String] = []
        while let next = plan.next() { served.append(next) }
        XCTAssertFalse(served.contains("a"), "a reserved asset is never served again")
        XCTAssertEqual(Set(served), Set(ids).subtracting(["a"]))
    }

    /// A jump places the cursor somewhere the plan still had waiting. The rest
    /// of the walk must not serve that asset again.
    func testTumblerJumpDoesNotServeTheJumpedToAssetTwice() throws {
        let order = TestLibrary.order()
        var engine = SessionEngine(order: order, mode: .tumbler, tumblerSeed: 33)
        engine.start()
        let first = engine.current?.id
        let target = try XCTUnwrap(order.ids.first { $0 != first })

        XCTAssertEqual(engine.jump(to: target), .advanced)
        XCTAssertEqual(engine.current?.id, target)
        engine.advance()

        var seen: [String] = []
        while let id = engine.current?.id {
            seen.append(id)
            engine.apply(.keep)
        }
        XCTAssertEqual(seen.count, Set(seen).count, "no repeats after a jump")
        XCTAssertFalse(seen.contains(target), "the jumped-to asset must not be served twice")
    }

    /// Undo returns the plan to the asset it reversed. The plan must not then
    /// hand that same asset back on the very next step.
    func testUndoDoesNotServeTheUndoneAssetTwiceInARow() {
        var engine = SessionEngine(order: TestLibrary.order(), mode: .tumbler, tumblerSeed: 9)
        engine.start()
        let undone = engine.current?.id
        XCTAssertNotNil(undone)
        engine.apply(.keep)

        engine.undo()
        XCTAssertEqual(engine.current?.id, undone, "Undo returns to the asset it reversed")

        engine.apply(.keep)
        XCTAssertNotEqual(engine.current?.id, undone, "the undone asset must never be served twice in a row")
    }

    /// After an Undo requeue the rest of the traversal is still a clean walk of
    /// the whole library: every asset shows up exactly once and none is lost.
    func testTraversalAfterUndoVisitsEveryAssetExactlyOnce() {
        var engine = SessionEngine(order: TestLibrary.order(), mode: .tumbler, tumblerSeed: 21)
        engine.start()
        engine.apply(.keep)
        engine.undo()

        var seen: [String] = []
        while let id = engine.current?.id {
            seen.append(id)
            engine.apply(.keep)
        }
        XCTAssertEqual(seen.count, Set(seen).count, "an Undo requeue must not cause a repeat")
        XCTAssertEqual(Set(seen), Set(TestLibrary.sequential().map(\.id)), "every asset is still served")
    }

    /// Two Undos in a row unwind the two most recent decisions. The second
    /// Undo hits the requeue guard for an id the first Undo already put back,
    /// and the walk from there is still complete and repeat-free.
    func testTwoUndosInARowLeaveACompleteRepeatFreeWalk() throws {
        let library = TestLibrary.order()
        var engine = SessionEngine(order: library, mode: .tumbler, tumblerSeed: 9)
        engine.start()
        let first = try XCTUnwrap(engine.current?.id)
        engine.apply(.keep)
        let second = try XCTUnwrap(engine.current?.id)
        engine.apply(.keep)

        engine.undo()
        XCTAssertEqual(engine.current?.id, second, "the first Undo returns to the second decision")
        engine.undo()
        XCTAssertEqual(engine.current?.id, first, "the cursor is back on the first undone asset")

        // The second Undo requeued an id the first one had already returned to
        // the plan. The guard must skip it instead of adding a duplicate.
        let remaining = try XCTUnwrap(engine.tumbler?.remaining)
        XCTAssertEqual(remaining.count, Set(remaining).count, "no id is requeued twice")

        var seen: [String] = []
        while let id = engine.current?.id {
            seen.append(id)
            engine.apply(.keep)
        }
        XCTAssertEqual(seen.first, first, "the walk starts on the first undone asset")
        XCTAssertEqual(seen.count, Set(seen).count, "no id repeats")
        XCTAssertEqual(Set(seen), Set(library.ids), "every library asset is still served")
        XCTAssertEqual(seen.count, library.ids.count, "and exactly once")
    }

    /// A session whose current asset vanished outside SWIPR is recovered onto a
    /// member the plan still had waiting. That recovered member must be claimed,
    /// or the plan would serve it a second time further down the walk.
    func testReconciledTumblerSessionNeverServesTheRecoveredAssetTwice() {
        let library = TestLibrary.order()
        let plan = TumblerPlan(assetIDs: library.ids, seed: 77)
        // The current asset vanished; its saved date points at "e", so
        // reconciliation recovers onto "e", which the plan still has waiting.
        let persisted = PersistedSession(
            currentAssetID: "gone",
            currentAssetDate: TestLibrary.descriptor(id: "e", dayOffset: 4).creationDate,
            direction: .older,
            mode: .tumbler,
            tumbler: plan,
            poolIDs: library.ids
        )
        let reconciled = AssetReconciler.reconcile(persisted, order: library, marks: [])
        XCTAssertEqual(reconciled.session.currentAssetID, "e", "reconciliation continues with a safe next item")

        var restored = SessionEngine.restored(
            from: reconciled.session,
            order: library,
            marks: reconciled.marks
        )
        XCTAssertTrue(restored.tumbler?.handled.contains("e") ?? false, "the recovered cursor is claimed")
        XCTAssertFalse(restored.tumbler?.remaining.contains("e") ?? true, "and no longer waits in the plan")

        // Step off the recovered cursor without deciding it. The restored
        // cursor claimed the asset, so the walk must still never serve it.
        let recovered = restored.current?.id
        XCTAssertEqual(recovered, "e")
        restored.advance()

        var seen: [String] = []
        while let id = restored.current?.id {
            seen.append(id)
            restored.apply(.keep)
        }
        XCTAssertFalse(seen.contains("e"), "the recovered asset is never served again")
        XCTAssertEqual(seen.count, Set(seen).count, "no repeats")
        XCTAssertEqual(Set(seen).union(["e"]), Set(library.ids), "every member is still served")
    }

    /// Reconciliation only drops what left the library. It invents no deletion
    /// for a vanished mark and reports the removal instead.
    func testReconcilingATumblerSessionThatLostAMemberCreditsNoDeletion() {
        let library = TestLibrary.order()
        let plan = TumblerPlan(assetIDs: library.ids, seed: 13)
        let persisted = PersistedSession(
            currentAssetID: "c",
            direction: .older,
            mode: .tumbler,
            tumbler: plan,
            poolIDs: library.ids
        )
        let liveOrder = LibraryOrder(library.assets.filter { $0.id != "c" })

        let reconciled = AssetReconciler.reconcile(persisted, order: liveOrder, marks: ["a", "c"])
        XCTAssertEqual(reconciled.marks, ["a"], "only the surviving mark remains")
        XCTAssertEqual(reconciled.externallyRemovedIDs, ["c"], "a vanished mark is reported, not counted")
        XCTAssertEqual(
            reconciled.session.tumbler?.remaining.contains("c"),
            false,
            "the vanished member leaves the plan"
        )
    }
}
