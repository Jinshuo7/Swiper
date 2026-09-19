import XCTest
@testable import SwiperKit

final class DeletionQueueTests: XCTestCase {
    func testAddKeepsOrderAndDeduplicates() {
        var queue = DeletionQueue()
        queue.add("a")
        queue.add("b")
        queue.add("a")
        XCTAssertEqual(queue.ids, ["a", "b"])
        XCTAssertEqual(queue.count, 2)
        XCTAssertTrue(queue.contains("a"))
        XCTAssertFalse(queue.contains("c"))
    }

    func testRemovePreservesRemainingOrder() {
        var queue = DeletionQueue(orderedIDs: ["a", "b", "c"])
        queue.remove("b")
        XCTAssertEqual(queue.ids, ["a", "c"])
        queue.remove("missing")
        XCTAssertEqual(queue.ids, ["a", "c"])
    }

    func testRemoveAll() {
        var queue = DeletionQueue(orderedIDs: ["a", "b"])
        queue.removeAll()
        XCTAssertTrue(queue.isEmpty)
        XCTAssertFalse(queue.contains("a"))
    }

    func testRoundTripsThroughCodable() throws {
        let queue = DeletionQueue(orderedIDs: ["a", "b", "b", "c"])
        let data = try JSONEncoder().encode(queue)
        let decoded = try JSONDecoder().decode(DeletionQueue.self, from: data)
        XCTAssertEqual(decoded.ids, ["a", "b", "c"])
        XCTAssertTrue(decoded.contains("c"))
    }
}
