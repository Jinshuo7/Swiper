import XCTest
@testable import SWIPRKit

final class SessionEngineTests: XCTestCase {
    private func freshEngine(direction: TraversalDirection = .older) -> SessionEngine {
        SessionEngine(order: TestLibrary.order(), direction: direction)
    }

    func testDefaultsToOlderAndStartsAtNewest() {
        var engine = freshEngine()
        XCTAssertEqual(engine.direction, .older)
        XCTAssertEqual(engine.start(), .advanced)
        XCTAssertEqual(engine.current?.id, "e")
    }

    func testKeepAdvancesTowardOlder() {
        var engine = freshEngine()
        engine.start()
        XCTAssertEqual(engine.apply(.keep), [.advanced])
        XCTAssertEqual(engine.current?.id, "d")
        XCTAssertTrue(engine.keptIDs.contains("e"))
        XCTAssertTrue(engine.decidedIDs.contains("e"))
    }

    func testQueueDeletionAddsToQueueAndAdvances() {
        var engine = freshEngine()
        engine.start()
        let effects = engine.apply(.queueDeletion)
        XCTAssertEqual(effects, [.queuedDeletion(id: "e"), .advanced])
        XCTAssertEqual(engine.queue.ids, ["e"])
        XCTAssertEqual(engine.current?.id, "d")
        XCTAssertFalse(engine.keptIDs.contains("e"))
    }

    func testUndoReversesKeepAndReturnsToAsset() {
        var engine = freshEngine()
        engine.start()
        engine.apply(.keep)
        XCTAssertEqual(engine.current?.id, "d")
        XCTAssertEqual(engine.undo(), [.undoApplied(assetID: "e")])
        XCTAssertEqual(engine.current?.id, "e")
        XCTAssertFalse(engine.decidedIDs.contains("e"))
    }

    func testUndoReversesQueueDeletion() {
        var engine = freshEngine()
        engine.start()
        engine.apply(.queueDeletion)
        let effects = engine.undo()
        XCTAssertEqual(effects, [.unqueuedDeletion(id: "e"), .undoApplied(assetID: "e")])
        XCTAssertTrue(engine.queue.isEmpty)
        XCTAssertEqual(engine.current?.id, "e")
    }

    func testApplyUndoAfterFinalDecisionReturnsToAsset() {
        let order = LibraryOrder([TestLibrary.descriptor(id: "a", dayOffset: 0)])
        var engine = SessionEngine(order: order)
        engine.start()
        engine.apply(.keep)

        XCTAssertEqual(engine.apply(.undo), [.undoApplied(assetID: "a")])
        XCTAssertEqual(engine.current?.id, "a")
        XCTAssertFalse(engine.isFinished)
    }

    func testUndoOnEmptyHistoryIsNoOp() {
        var engine = freshEngine()
        engine.start()
        XCTAssertEqual(engine.undo(), [.noOp])
    }

    func testFlipsDirectionAtEndOfLibrary() {
        var engine = freshEngine()
        engine.jump(to: "a")
        XCTAssertEqual(engine.advance(), .advanced)
        XCTAssertEqual(engine.current?.id, "b")
        XCTAssertEqual(engine.direction, .newer)
    }

    func testFinishesWhenEverythingDecided() {
        var engine = freshEngine()
        engine.start()
        for _ in 0..<4 {
            XCTAssertEqual(engine.apply(.keep), [.advanced])
        }
        XCTAssertEqual(engine.apply(.keep), [.sessionFinished])
        XCTAssertTrue(engine.isFinished)
        XCTAssertNil(engine.current)
    }

    func testJumpToStartHereAsset() {
        var engine = freshEngine()
        XCTAssertEqual(engine.jump(to: "c"), .advanced)
        XCTAssertEqual(engine.current?.id, "c")
        XCTAssertEqual(engine.jump(to: "missing"), .noOp)
    }

    func testUpcomingIDsFollowSequentialTraversalWithoutMutatingEngine() {
        var engine = freshEngine()
        engine.jump(to: "a")
        XCTAssertEqual(engine.upcomingIDs(limit: 2), ["b", "c"])
        XCTAssertEqual(engine.current?.id, "a")
        XCTAssertEqual(engine.direction, .older)
    }

    func testUpcomingIDsFollowTumblerPlan() {
        var engine = SessionEngine(order: TestLibrary.order(), mode: .tumbler, tumblerSeed: 17)
        engine.start()
        let expected = engine.upcomingIDs(limit: 2)

        engine.apply(.keep)
        let first = engine.current?.id
        engine.apply(.keep)
        let second = engine.current?.id

        XCTAssertEqual(expected, [first, second].compactMap { $0 })
    }

    func testTumblerUndoRequeuesTheUndoneAndDisplacedPhotos() {
        var engine = SessionEngine(order: TestLibrary.order(), mode: .tumbler, tumblerSeed: 17)
        engine.start()
        engine.apply(.keep)
        let undone = engine.current!.id
        engine.apply(.keep)
        let displaced = engine.current?.id

        engine.undo()
        XCTAssertEqual(engine.current?.id, undone)
        XCTAssertFalse(engine.tumbler!.handled.contains(undone))
        engine.apply(.keep)
        XCTAssertEqual(engine.current?.id, displaced)

        while !engine.isFinished {
            engine.apply(.keep)
        }
        XCTAssertEqual(engine.keptIDs, engine.order.idSet)
    }

    func testRestoreReturnsQueuedAssetsToKept() {
        var engine = freshEngine()
        engine.start()
        engine.apply(.queueDeletion) // e
        engine.apply(.queueDeletion) // d
        XCTAssertEqual(engine.queue.ids, ["e", "d"])
        let effects = engine.restore(ids: ["e"])
        XCTAssertEqual(effects, [.unqueuedDeletion(id: "e")])
        XCTAssertEqual(engine.queue.ids, ["d"])
        XCTAssertTrue(engine.keptIDs.contains("e"))
        XCTAssertTrue(engine.decidedIDs.contains("e"))
    }

    func testCommitDeletionDropsAssetsFromQueueAndDecisionHistory() {
        var engine = freshEngine()
        engine.start()
        engine.apply(.queueDeletion) // e
        let outcome = DeletionOutcome(
            requestedIDs: ["e"],
            deletedIDs: ["e"],
            failedIDs: [],
            deletedBytes: 1_000
        )
        engine.commitDeletion(outcome: outcome)
        XCTAssertTrue(engine.queue.isEmpty)
        XCTAssertFalse(engine.decidedIDs.contains("e"))
        XCTAssertTrue(engine.undoStack.canUndo == false || engine.undoStack.last?.assetID != "e")
    }

    func testDisabledUndoOnEmptyLibrary() {
        var engine = SessionEngine(order: .empty)
        XCTAssertEqual(engine.start(), .sessionFinished)
        XCTAssertTrue(engine.isFinished)
    }

    // MARK: - Captured pool

    func testPoolConfinesTraversalAndExcludesNewArrivals() {
        // "f" arrived after the pool was captured and must never be presented.
        let full = LibraryOrder([
            TestLibrary.descriptor(id: "a", dayOffset: 0),
            TestLibrary.descriptor(id: "b", dayOffset: 1),
            TestLibrary.descriptor(id: "c", dayOffset: 2),
            TestLibrary.descriptor(id: "d", dayOffset: 3),
            TestLibrary.descriptor(id: "e", dayOffset: 4),
            TestLibrary.descriptor(id: "f", dayOffset: 5),
        ])
        var engine = SessionEngine(order: full, direction: .older, poolIDs: Set(["a", "c", "e"]))
        engine.start()

        var visited: [String] = []
        while let id = engine.current?.id {
            visited.append(id)
            engine.apply(.keep)
        }
        XCTAssertEqual(visited, ["e", "c", "a"], "a captured pool walks only its own members")
        XCTAssertFalse(visited.contains("f"))
        XCTAssertTrue(engine.isFinished)
    }

    func testLegacyEngineWithoutPoolWalksTheFullOrder() {
        var engine = SessionEngine(order: TestLibrary.order(), direction: .older)
        engine.start()
        var visited: [String] = []
        while let id = engine.current?.id {
            visited.append(id)
            engine.apply(.keep)
        }
        XCTAssertEqual(visited, ["e", "d", "c", "b", "a"], "no pool means the prior full order")
    }

    func testPoolUpcomingIDsIgnoreNewArrivals() {
        let full = LibraryOrder([
            TestLibrary.descriptor(id: "a", dayOffset: 0),
            TestLibrary.descriptor(id: "b", dayOffset: 1),
            TestLibrary.descriptor(id: "c", dayOffset: 2),
            TestLibrary.descriptor(id: "f", dayOffset: 5),
        ])
        var engine = SessionEngine(order: full, direction: .older, poolIDs: Set(["a", "c"]))
        engine.start()
        XCTAssertEqual(engine.upcomingIDs(limit: 3), ["a"])
        XCTAssertEqual(engine.remainingCount, 2)
    }

    func testTumblerPoolNeverServesNewArrivals() {
        let full = LibraryOrder([
            TestLibrary.descriptor(id: "a", dayOffset: 0),
            TestLibrary.descriptor(id: "b", dayOffset: 1),
            TestLibrary.descriptor(id: "c", dayOffset: 2),
            TestLibrary.descriptor(id: "f", dayOffset: 5),
        ])
        var engine = SessionEngine(
            order: full,
            mode: .tumbler,
            tumblerSeed: 7,
            poolIDs: Set(["a", "b", "c"])
        )
        engine.start()
        var visited: [String] = []
        while let id = engine.current?.id {
            visited.append(id)
            engine.apply(.keep)
        }
        XCTAssertEqual(Set(visited), Set(["a", "b", "c"]))
        XCTAssertFalse(visited.contains("f"))
    }

    func testPersistedKeepsPoolMembersHiddenFromTheCurrentOrder() {
        // A Limited-access snapshot can hide pool members; they must survive a
        // save so widening access restores the same fixed pool.
        let visible = LibraryOrder(TestLibrary.sequential())
        var engine = SessionEngine(
            order: visible,
            direction: .older,
            poolIDs: Set(["a", "c", "hidden"])
        )
        engine.start()

        XCTAssertEqual(
            engine.persisted().poolIDs,
            ["a", "c", "hidden"],
            "a hidden pool member is kept after the visible ones"
        )
    }
}
