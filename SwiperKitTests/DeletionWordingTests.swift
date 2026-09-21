import XCTest
@testable import SwiperKit

final class DeletionWordingTests: XCTestCase {
    func testMarkedForDeletionUsesSingularAndPlural() {
        XCTAssertEqual(DeletionWording.markedForDeletion(0), "0 photos marked for deletion")
        XCTAssertEqual(DeletionWording.markedForDeletion(1), "1 photo marked for deletion")
        XCTAssertEqual(DeletionWording.markedForDeletion(7), "7 photos marked for deletion")
    }

    func testReviewWordingMatchesTheAgreedCopy() {
        XCTAssertEqual(DeletionWording.reviewCompact(1), "Review · 1")
        XCTAssertEqual(DeletionWording.reviewAndDelete(3), "Review & delete · 3")
        XCTAssertEqual(DeletionWording.nothingDeletedYet, "Nothing deleted yet.")
    }

    func testWordingNeverCallsTheListAQueueInTheUserCopy() {
        let copy = [
            DeletionWording.markedForDeletion(2),
            DeletionWording.reviewAndDelete(2),
            DeletionWording.reviewCompact(2),
            DeletionWording.nothingDeletedYet,
        ].joined(separator: " ").lowercased()
        XCTAssertFalse(copy.contains("queue"))
    }
}
