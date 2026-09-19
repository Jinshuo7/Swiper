import Foundation

/// Confirmed deletion totals: current session plus lifetime.
///
/// Only **successful, confirmed** deletions are ever recorded. Merely queued or
/// failed assets are excluded by construction — callers only call
/// ``record(_:)`` with a resolved ``DeletionOutcome``.
public struct SessionStatistics: Codable, Equatable, Sendable {
    /// Assets confirmed deleted in the current session.
    public private(set) var currentSessionDeletedCount: Int
    /// Estimated bytes reclaimed in the current session.
    public private(set) var currentSessionReclaimedBytes: Int64
    /// Assets confirmed deleted across all sessions.
    public private(set) var lifetimeDeletedCount: Int
    /// Estimated bytes reclaimed across all sessions.
    public private(set) var lifetimeReclaimedBytes: Int64
    /// Cleanup sessions explicitly completed by the user.
    public private(set) var lifetimeCompletedSessions: Int

    public init(
        currentSessionDeletedCount: Int = 0,
        currentSessionReclaimedBytes: Int64 = 0,
        lifetimeDeletedCount: Int = 0,
        lifetimeReclaimedBytes: Int64 = 0,
        lifetimeCompletedSessions: Int = 0
    ) {
        self.currentSessionDeletedCount = currentSessionDeletedCount
        self.currentSessionReclaimedBytes = currentSessionReclaimedBytes
        self.lifetimeDeletedCount = lifetimeDeletedCount
        self.lifetimeReclaimedBytes = lifetimeReclaimedBytes
        self.lifetimeCompletedSessions = lifetimeCompletedSessions
    }

    public static let empty = SessionStatistics()

    public var hasCurrentSessionActivity: Bool { currentSessionDeletedCount > 0 }

    /// Starts a fresh current-session tally without touching lifetime totals.
    public mutating func beginSession() {
        currentSessionDeletedCount = 0
        currentSessionReclaimedBytes = 0
    }

    /// Records a resolved, successful deletion. Counts only what really went
    /// away; a no-op outcome never changes anything.
    public mutating func record(_ outcome: DeletionOutcome) {
        guard outcome.deletedCount > 0 || outcome.deletedBytes > 0 else { return }
        currentSessionDeletedCount += outcome.deletedCount
        currentSessionReclaimedBytes += outcome.deletedBytes
        lifetimeDeletedCount += outcome.deletedCount
        lifetimeReclaimedBytes += outcome.deletedBytes
    }

    public mutating func completeSession() {
        lifetimeCompletedSessions += 1
    }
}

/// The confirmed result of a deletion commit.
public struct DeletionOutcome: Equatable, Sendable {
    public let requestedIDs: [String]
    public let deletedIDs: [String]
    public let failedIDs: [String]
    public let deletedBytes: Int64

    public init(requestedIDs: [String], deletedIDs: [String], failedIDs: [String], deletedBytes: Int64) {
        self.requestedIDs = requestedIDs
        self.deletedIDs = deletedIDs
        self.failedIDs = failedIDs
        self.deletedBytes = deletedBytes
    }

    public var deletedCount: Int { deletedIDs.count }
    public var failedCount: Int { failedIDs.count }

    public static let empty = DeletionOutcome(requestedIDs: [], deletedIDs: [], failedIDs: [], deletedBytes: 0)
}

/// Turns "what we asked to delete" plus "what still exists afterwards" into a
/// confirmed outcome. This is how Swiper avoids crediting stats for assets that
/// a system dialog, a permission change, or a concurrent library edit kept.
public enum DeletionResolver {
    public static func outcome(
        requestedIDs: [String],
        submittedIDs: Set<String>,
        descriptors: [String: AssetDescriptor],
        stillPresentIDs: Set<String>
    ) -> DeletionOutcome {
        var deleted: [String] = []
        var failed: [String] = []
        var bytes: Int64 = 0
        for id in requestedIDs {
            if !submittedIDs.contains(id) || stillPresentIDs.contains(id) {
                failed.append(id)
            } else {
                deleted.append(id)
                if let descriptor = descriptors[id] {
                    bytes += descriptor.estimatedBytes
                }
            }
        }
        return DeletionOutcome(
            requestedIDs: requestedIDs,
            deletedIDs: deleted,
            failedIDs: failed,
            deletedBytes: bytes
        )
    }
}
