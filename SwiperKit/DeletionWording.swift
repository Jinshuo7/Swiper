import Foundation

/// The user-facing wording for marked-for-deletion state.
///
/// The product deliberately never calls the deletion list a "queue" in the UI:
/// a leftover mark is reversible and nothing has been deleted. Keeping the
/// strings here means home, the viewer and review always agree, and tests can
/// assert the agreed wording instead of one screen's copy.
public enum DeletionWording {
    /// e.g. `"3 photos marked for deletion"`.
    public static func markedForDeletion(_ count: Int) -> String {
        "\(count) \(count == 1 ? "photo" : "photos") marked for deletion"
    }

    /// e.g. `"Review & delete · 3"`.
    public static func reviewAndDelete(_ count: Int) -> String {
        "Review & delete · \(count)"
    }

    /// e.g. `"Review · 3"`.
    public static func reviewCompact(_ count: Int) -> String {
        "Review · \(count)"
    }

    /// The reassurance shown wherever marks are visible.
    public static let nothingDeletedYet = "Nothing deleted yet."
}
