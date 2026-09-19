import XCTest
@testable import SwiperKit

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
}
