import Foundation

/// The result of matching persisted state against the live library.
public struct ReconciledSession: Equatable, Sendable {
    public var session: PersistedSession
    /// The deletion list with vanished assets removed. A mark whose asset no
    /// longer exists is dropped: it cannot be deleted again, and Swiper must not
    /// claim credit for a removal it did not confirm.
    public var marks: [String]
    /// Identifiers that were marked or decided but no longer exist in the
    /// library. They vanished outside Swiper, so they are **not** counted as
    /// deletions and are **not** reported as successes.
    public var externallyRemovedIDs: [String]

    public init(session: PersistedSession, marks: [String], externallyRemovedIDs: [String]) {
        self.session = session
        self.marks = marks
        self.externallyRemovedIDs = externallyRemovedIDs
    }
}

/// Whole-application state reconciliated against the live library.
public struct ReconciledState: Equatable, Sendable {
    public var state: PersistedState
    public var externallyRemovedIDs: [String]

    public init(state: PersistedState, externallyRemovedIDs: [String]) {
        self.state = state
        self.externallyRemovedIDs = externallyRemovedIDs
    }
}

/// Reconciles persisted identifiers against the current library so sessions and
/// the deletion list survive assets being removed or changed outside Swiper.
public enum AssetReconciler {
    public static func reconcile(_ state: PersistedState, order: LibraryOrder) -> ReconciledState {
        guard let session = state.session else {
            let available = order.idSet
            let marks = state.marks.filter { available.contains($0) }
            let removed = state.marks.filter { !available.contains($0) }
            var updated = state
            updated.marks = marks
            return ReconciledState(state: updated, externallyRemovedIDs: removed)
        }

        let reconciled = reconcile(session, order: order, marks: state.marks)
        var updated = state
        updated.marks = reconciled.marks
        updated.session = reconciled.session
        return ReconciledState(state: updated, externallyRemovedIDs: reconciled.externallyRemovedIDs)
    }

    public static func reconcile(
        _ session: PersistedSession,
        order: LibraryOrder,
        marks: [String] = []
    ) -> ReconciledSession {
        let available = order.idSet

        let queueIDs = marks.filter { available.contains($0) }
        let decidedIDs = session.decidedIDs.filter { available.contains($0) }
        let keptIDs = session.keptIDs.filter { available.contains($0) }
        let undoEntries = session.undoEntries.filter { available.contains($0.assetID) }

        let vanishedCandidates = marks + session.decidedIDs
        var seen = Set<String>()
        let externallyRemoved = vanishedCandidates.filter { id in
            guard !available.contains(id) else { return false }
            return seen.insert(id).inserted
        }

        var tumbler = session.tumbler
        if var plan = tumbler {
            plan.reconcile(withAvailableIDs: available)
            tumbler = plan
        }

        var resolvedCurrentID = session.currentAssetID
        var resolvedCurrentDate = session.currentAssetDate
        if let currentID = resolvedCurrentID, available.contains(currentID) {
            resolvedCurrentDate = order.asset(byID: currentID)?.creationDate ?? resolvedCurrentDate
        } else {
            // The persisted current asset is gone. Fall back to the nearest
            // still-present asset in the user's preferred direction, skipping
            // anything already decided or marked.
            let excluded = Set(decidedIDs).union(queueIDs)
            if let index = order.nearestIndex(toDate: session.currentAssetDate, direction: session.direction) {
                let candidate = firstUndecided(
                    in: order,
                    from: index,
                    direction: session.direction,
                    excluded: excluded
                )
                resolvedCurrentID = candidate?.id
                resolvedCurrentDate = candidate?.creationDate
            } else {
                resolvedCurrentID = nil
                resolvedCurrentDate = nil
            }
        }

        let nothingLeftToShow = resolvedCurrentID == nil
            && Set(decidedIDs).union(queueIDs).isSuperset(of: available)

        let reconciled = PersistedSession(
            currentAssetID: resolvedCurrentID,
            currentAssetDate: resolvedCurrentDate,
            direction: session.direction,
            mode: session.mode,
            decidedIDs: decidedIDs,
            keptIDs: keptIDs,
            undoEntries: undoEntries,
            tumbler: tumbler,
            updatedAt: session.updatedAt,
            isFinished: session.isFinished || nothingLeftToShow
        )
        return ReconciledSession(
            session: reconciled,
            marks: queueIDs,
            externallyRemovedIDs: externallyRemoved
        )
    }

    private static func firstUndecided(
        in order: LibraryOrder,
        from index: Int,
        direction: TraversalDirection,
        excluded: Set<String>
    ) -> AssetDescriptor? {
        let step = direction == .older ? -1 : 1
        var cursor = index
        while order.assets.indices.contains(cursor) {
            let asset = order.assets[cursor]
            if !excluded.contains(asset.id) { return asset }
            cursor += step
        }
        cursor = index - step
        while order.assets.indices.contains(cursor) {
            let asset = order.assets[cursor]
            if !excluded.contains(asset.id) { return asset }
            cursor -= step
        }
        return nil
    }
}
