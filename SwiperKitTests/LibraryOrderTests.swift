import XCTest
@testable import SwiperKit

final class LibraryOrderTests: XCTestCase {
    func testSortsOldestToNewestRegardlessOfInputOrder() {
        let order = LibraryOrder(TestLibrary.sequential().reversed())
        XCTAssertEqual(order.ids, ["a", "b", "c", "d", "e"])
        XCTAssertEqual(order.count, 5)
    }

    func testAssetLookupByIndexAndIdentifier() {
        let order = TestLibrary.order()
        XCTAssertEqual(order.asset(at: 0)?.id, "a")
        XCTAssertEqual(order.asset(at: 4)?.id, "e")
        XCTAssertNil(order.asset(at: 99))
        XCTAssertEqual(order.asset(byID: "c")?.id, "c")
        XCTAssertNil(order.asset(byID: "zzz"))
        XCTAssertEqual(order.index(of: "b"), 1)
    }

    func testNeighborWalksInDirection() {
        let order = TestLibrary.order()
        XCTAssertEqual(order.neighborIndex(from: 2, direction: .older), 1)
        XCTAssertEqual(order.neighborIndex(from: 2, direction: .newer), 3)
        XCTAssertNil(order.neighborIndex(from: 0, direction: .older))
        XCTAssertNil(order.neighborIndex(from: 4, direction: .newer))
    }

    func testNearestIndexResolvesMissingDateTowardDirection() {
        let order = TestLibrary.order()
        let cDate = order.asset(byID: "c")!.creationDate!
        // Between c and d: older resolves to c, newer resolves to d.
        let between = cDate.addingTimeInterval(43_200)
        XCTAssertEqual(order.nearestIndex(toDate: between, direction: .older), 2)
        XCTAssertEqual(order.nearestIndex(toDate: between, direction: .newer), 3)
    }

    func testNearestIndexFallsBackToExtremes() {
        let order = TestLibrary.order()
        let farFuture = Date(timeIntervalSince1970: 4_000_000_000)
        let farPast = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(order.nearestIndex(toDate: farFuture, direction: .older), 4)
        XCTAssertEqual(order.nearestIndex(toDate: farPast, direction: .newer), 0)
    }

    func testEmptyOrder() {
        let order = LibraryOrder([])
        XCTAssertTrue(order.isEmpty)
        XCTAssertNil(order.nearestIndex(toDate: Date(), direction: .older))
    }
}
