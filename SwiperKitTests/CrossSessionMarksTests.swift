import XCTest
@testable import SwiperKit

/// The deletion list outlives sorting sessions. These tests pin that contract
/// on the pure engine: a new session resets traversal and Undo, never marks, and
/// a marked photo is never presented again.
final class CrossSessionMarksTests: XCTestCase {
    private var order: LibraryOrder { TestLibrary.order() }

    private func makeEngine(marks: [String] = [], mode: SessionMode = .sequential) -> SessionEngine {
        SessionEngine(order: order, mode: mode, queue: DeletionQueue(orderedIDs: marks))
    }

    func testANewSessionStartsTraversalOverButKeepsEveryMark() {
        var first = makeEngine()
        first.start()
        first.apply(.queueDeletion) // e
        first.apply(.queueDeletion) // d
        first.apply(.keep)          // c
        XCTAssertEqual(first.queue.ids, ["e", "d"])
        XCTAssertFalse(first.undoStack.entries.isEmpty)

        // Starting a fresh session is exactly this: a new engine seeded with the
        // durable marks.
        var second = makeEngine(marks: first.queue.ids)
        second.start()
        XCTAssertEqual(second.queue.ids, ["e", "d"], "a new session never clears marks")
        XCTAssertTrue(second.decidedIDs.isEmpty, "a new session resets traversal decisions")
        XCTAssertFalse(second.undoStack.canUndo, "a new session resets Undo")
    }

    func testANewSessionSkipsMarkedAssets() {
        var engine = makeEngine(marks: ["e", "d"])
        XCTAssertEqual(engine.start(), .advanced)
        XCTAssertEqual(engine.current?.id, "c")
    }

    func testMarkedAssetsAreSkippedInBothDirections() {
        var engine = makeEngine(marks: ["a", "e"])
        engine.start()
        XCTAssertEqual(engine.current?.id, "d")

        engine.setDirection(.newer)
        var visited: [String] = []
        while let id = engine.current?.id {
            visited.append(id)
            engine.apply(.keep)
        }
        XCTAssertEqual(visited, ["d", "c", "b"])
        XCTAssertFalse(visited.contains("a"))
        XCTAssertFalse(visited.contains("e"))
    }

    func testUpcomingIDsSkipMarkedAssets() {
        var engine = makeEngine(marks: ["c"])
        engine.jump(to: "a")
        XCTAssertEqual(engine.upcomingIDs(limit: 3), ["b", "d", "e"])
    }

    func testRemainingCountExcludesMarks() {
        var engine = makeEngine(marks: ["e", "d"])
        engine.start()
        XCTAssertEqual(engine.remainingCount, 3)
    }

    func testSessionFinishesWhenEverythingLeftIsMarked() {
        var engine = makeEngine(marks: ["a", "b", "c", "d"])
        XCTAssertEqual(engine.start(), .advanced)
        XCTAssertEqual(engine.current?.id, "e")
        engine.apply(.keep)
        XCTAssertTrue(engine.isFinished)

        var allMarked = makeEngine(marks: order.ids)
        XCTAssertEqual(allMarked.start(), .sessionFinished)
    }

    func testTumblerSkipsMarkedAssets() {
        var engine = makeEngine(marks: ["a", "b"], mode: .tumbler)
        var visited: [String] = []
        engine.start()
        while let id = engine.current?.id {
            visited.append(id)
            engine.apply(.keep)
        }
        XCTAssertEqual(Set(visited), Set(["c", "d", "e"]))
        XCTAssertEqual(visited.count, 3)
    }

    func testTumblerPeekSkipsMarkedAssets() {
        let engine = SessionEngine(
            order: order,
            mode: .tumbler,
            queue: DeletionQueue(orderedIDs: ["a", "b"]),
            tumblerSeed: 5
        )
        let upcoming = engine.upcomingIDs(limit: 3)
        XCTAssertEqual(upcoming.count, 3)
        XCTAssertFalse(upcoming.contains("a"))
        XCTAssertFalse(upcoming.contains("b"))
    }

    func testJumpRefusesAMarkedAsset() {
        var engine = makeEngine(marks: ["c"])
        XCTAssertEqual(engine.jump(to: "c"), .noOp)
        XCTAssertNil(engine.current)
        XCTAssertEqual(engine.jump(to: "b"), .advanced)
    }

    func testRestoreMakesThePhotoKeptForThisSession() {
        var engine = makeEngine(marks: ["e", "d"])
        engine.start()
        XCTAssertEqual(engine.current?.id, "c")

        let effects = engine.restore(ids: ["e"])
        XCTAssertEqual(effects, [.unqueuedDeletion(id: "e")])
        XCTAssertEqual(engine.queue.ids, ["d"])
        XCTAssertTrue(engine.keptIDs.contains("e"))
        XCTAssertTrue(engine.decidedIDs.contains("e"), "a restored photo is kept for the current session")

        // "e" must not come back within this session.
        var visited: [String] = []
        while let id = engine.current?.id {
            visited.append(id)
            engine.apply(.keep)
        }
        XCTAssertFalse(visited.contains("e"))

        // A later session is allowed to present it again.
        var next = makeEngine(marks: engine.queue.ids)
        next.start()
        XCTAssertTrue(next.isUnavailable("d"), "the remaining mark is still skipped")
        XCTAssertFalse(next.isUnavailable("e"))
        XCTAssertEqual(next.current?.id, "e", "a restored photo may appear in a later session")
    }

    func testRestoreInvalidatesUndoEntriesForThatAsset() {
        var engine = makeEngine()
        engine.start()
        engine.apply(.queueDeletion) // e
        XCTAssertTrue(engine.undoStack.canUndo)

        engine.restore(ids: ["e"])
        XCTAssertFalse(
            engine.undoStack.entries.contains { $0.assetID == "e" },
            "a stale Undo must not be able to reapply a restored mark"
        )
        XCTAssertEqual(engine.undo(), [.noOp])
        XCTAssertTrue(engine.queue.isEmpty)
    }

    func testUndoAfterRestoreDoesNotReapplyTheMark() {
        var engine = makeEngine()
        engine.start()
        engine.apply(.queueDeletion) // e
        engine.apply(.queueDeletion) // d
        engine.restore(ids: ["e"])

        // Undo still reverses the most recent *remaining* decision, which is d.
        XCTAssertEqual(engine.undo(), [.unqueuedDeletion(id: "d"), .undoApplied(assetID: "d")])
        XCTAssertTrue(engine.queue.isEmpty)
        XCTAssertEqual(engine.current?.id, "d")
    }

    func testRestoringFromReviewWithoutASessionOnlyUnmarks() {
        var marks = DeletionQueue(orderedIDs: ["e", "d", "c"])
        marks.remove("d")
        XCTAssertEqual(marks.ids, ["e", "c"])
    }

    func testMarkedAssetsSurviveEnginePersistenceRoundTrip() {
        var first = makeEngine()
        first.start()
        first.apply(.queueDeletion)
        first.apply(.keep)
        let marks = first.queue.ids

        let restored = SessionEngine.restored(
            from: first.persisted(),
            order: order,
            marks: marks
        )
        XCTAssertEqual(restored.queue.ids, marks)
        XCTAssertEqual(restored.current?.id, first.current?.id)
        XCTAssertEqual(restored.undoStack.entries, first.undoStack.entries)
    }
}
