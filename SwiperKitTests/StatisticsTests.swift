import XCTest
@testable import SwiperKit

final class StatisticsTests: XCTestCase {
    private func descriptors(_ ids: [String]) -> [String: AssetDescriptor] {
        var result = [String: AssetDescriptor]()
        for (index, id) in ids.enumerated() {
            result[id] = TestLibrary.descriptor(id: id, dayOffset: index)
        }
        return result
    }

    func testDeletionResolverSeparatesDeletedFromFailed() {
        let descriptors = descriptors(["a", "b", "c"])
        let outcome = DeletionResolver.outcome(
            requestedIDs: ["a", "b", "c"],
            submittedIDs: ["a", "b", "c"],
            descriptors: descriptors,
            stillPresentIDs: ["b"]
        )
        XCTAssertEqual(outcome.deletedIDs, ["a", "c"])
        XCTAssertEqual(outcome.failedIDs, ["b"])
        XCTAssertEqual(outcome.deletedCount, 2)
        XCTAssertEqual(outcome.deletedBytes, descriptors["a"]!.estimatedBytes + descriptors["c"]!.estimatedBytes)
    }

    func testOnlyConfirmedDeletionsAreCounted() {
        var statistics = SessionStatistics.empty
        let descriptors = descriptors(["a", "b"])
        let outcome = DeletionResolver.outcome(
            requestedIDs: ["a", "b"],
            submittedIDs: ["a", "b"],
            descriptors: descriptors,
            stillPresentIDs: ["a"]
        )
        statistics.record(outcome)
        XCTAssertEqual(statistics.currentSessionDeletedCount, 1)
        XCTAssertEqual(statistics.lifetimeDeletedCount, 1)
        XCTAssertEqual(statistics.lifetimeCompletedSessions, 0)
        XCTAssertEqual(statistics.lifetimeReclaimedBytes, descriptors["b"]!.estimatedBytes)
    }

    func testQueuedButNeverDeletedIsNotCounted() {
        var statistics = SessionStatistics.empty
        let outcome = DeletionResolver.outcome(
            requestedIDs: ["a"],
            submittedIDs: ["a"],
            descriptors: descriptors(["a"]),
            stillPresentIDs: ["a"]
        )
        statistics.record(outcome)
        XCTAssertEqual(statistics, .empty)
    }

    func testUnsubmittedAssetsAreFailedEvenWhenAbsentAfterDeletion() {
        let outcome = DeletionResolver.outcome(
            requestedIDs: ["a", "b"],
            submittedIDs: ["b"],
            descriptors: descriptors(["a", "b"]),
            stillPresentIDs: []
        )
        XCTAssertEqual(outcome.deletedIDs, ["b"])
        XCTAssertEqual(outcome.failedIDs, ["a"])
    }

    func testDeletionOutcomeDoesNotCompleteSession() {
        var statistics = SessionStatistics.empty
        statistics.record(DeletionOutcome(requestedIDs: ["a"], deletedIDs: ["a"], failedIDs: [], deletedBytes: 1))
        XCTAssertEqual(statistics.lifetimeCompletedSessions, 0)
        XCTAssertEqual(statistics.lifetimeDeletedCount, 1)
    }

    func testSessionCompletionIsCountedWithoutDeletion() {
        var statistics = SessionStatistics.empty
        statistics.completeSession()
        XCTAssertEqual(statistics.lifetimeCompletedSessions, 1)
        XCTAssertEqual(statistics.lifetimeDeletedCount, 0)
    }

    func testBeginSessionResetsCurrentButKeepsLifetime() {
        var statistics = SessionStatistics.empty
        let outcome = DeletionResolver.outcome(
            requestedIDs: ["a"],
            submittedIDs: ["a"],
            descriptors: descriptors(["a"]),
            stillPresentIDs: []
        )
        statistics.record(outcome)
        statistics.beginSession()
        XCTAssertEqual(statistics.currentSessionDeletedCount, 0)
        XCTAssertEqual(statistics.lifetimeDeletedCount, 1)
        XCTAssertEqual(statistics.lifetimeCompletedSessions, 0)
    }

    func testRoundTripsThroughCodable() throws {
        var statistics = SessionStatistics.empty
        let outcome = DeletionResolver.outcome(
            requestedIDs: ["a"],
            submittedIDs: ["a"],
            descriptors: descriptors(["a"]),
            stillPresentIDs: []
        )
        statistics.record(outcome)
        let data = try JSONEncoder().encode(statistics)
        let decoded = try JSONDecoder().decode(SessionStatistics.self, from: data)
        XCTAssertEqual(decoded, statistics)
    }
}
