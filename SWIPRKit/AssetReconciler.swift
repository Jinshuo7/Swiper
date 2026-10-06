import Foundation

/// The result of matching persisted state against the live library.
public struct ReconciledSession: Equatable, Sendable {
    public var session: PersistedSession
    /// The deletion list with vanished assets removed. A mark whose asset no
    /// longer exists is dropped: it cannot be deleted again, and SWIPR must not
    /// claim credit for a removal it did not confirm.
    public var marks: [String]
    /// Identifiers that were marked or decided but no longer exist in the
    /// library. They vanished outside SWIPR, so they are **not** counted as
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
/// the deletion list survive assets being removed or changed outside SWIPR.
public enum AssetReconciler {
    /// - Parameter libraryAccessIsLimited: When Photos access is Limited the
    ///   library snapshot is a subset the user chose, not the whole library. An
    ///   unseen identifier is then hidden, not gone, so nothing is dropped and
    ///   nothing is credited as externally removed; widening access restores it.
    public static func reconcile(
        _ state: PersistedState,
        order: LibraryOrder,
        libraryAccessIsLimited: Bool = false
    ) -> ReconciledState {
        guard let session = state.session else {
            guard !libraryAccessIsLimited else {
                return ReconciledState(state: state, externallyRemovedIDs: [])
            }
            let available = order.idSet
            let marks = state.marks.filter { available.contains($0) }
            let removed = state.marks.filter { !available.contains($0) }
            var updated = state
            updated.marks = marks
            return ReconciledState(state: updated, externallyRemovedIDs: removed)
        }

        let reconciled = reconcile(
            session,
            order: order,
            marks: state.marks,
            libraryAccessIsLimited: libraryAccessIsLimited
        )
        var updated = state
        updated.marks = reconciled.marks
        updated.session = reconciled.session
        return ReconciledState(state: updated, externallyRemovedIDs: reconciled.externallyRemovedIDs)
    }

    public static func reconcile(
        _ session: PersistedSession,
        order: LibraryOrder,
        marks: [String] = [],
        libraryAccessIsLimited: Bool = false
    ) -> ReconciledSession {
        let available = order.idSet

        // The captured pool drops only identifiers that left the library. New
        // arrivals are never added, so a session's membership stays fixed. A
        // Limited snapshot cannot tell "left" from "hidden", so it keeps the
        // whole pool (and every membership list below) intact.
        let poolIDs = libraryAccessIsLimited
            ? session.poolIDs
            : session.poolIDs.map { $0.filter { available.contains($0) } }
        // Traversal is confined to the pool when one was captured; a legacy
        // session without a pool keeps walking the full library order. The
        // visible order is always the library snapshot, so hiding a member
        // removes it from traversal without deleting it from the session.
        let workingOrder: LibraryOrder
        if let poolIDs {
            let pool = Set(poolIDs)
            workingOrder = LibraryOrder(order.assets.filter { pool.contains($0.id) })
        } else {
            workingOrder = order
        }

        let queueIDs = libraryAccessIsLimited ? marks : marks.filter { available.contains($0) }
        let decidedIDs = libraryAccessIsLimited
            ? session.decidedIDs
            : session.decidedIDs.filter { available.contains($0) }
        let keptIDs = libraryAccessIsLimited
            ? session.keptIDs
            : session.keptIDs.filter { available.contains($0) }
        let undoEntries = libraryAccessIsLimited
            ? session.undoEntries
            : session.undoEntries.filter { available.contains($0.assetID) }

        let externallyRemoved: [String]
        if libraryAccessIsLimited {
            externallyRemoved = []
        } else {
            let vanishedCandidates = marks + session.decidedIDs
            var seen = Set<String>()
            externallyRemoved = vanishedCandidates.filter { id in
                guard !available.contains(id) else { return false }
                return seen.insert(id).inserted
            }
        }

        var tumbler = session.tumbler
        if !libraryAccessIsLimited, var plan = tumbler {
            plan.reconcile(withAvailableIDs: available)
            tumbler = plan
        }

        var resolvedCurrentID = session.currentAssetID
        var resolvedCurrentDate = session.currentAssetDate
        if let currentID = resolvedCurrentID, workingOrder.contains(id: currentID) {
            resolvedCurrentDate = workingOrder.asset(byID: currentID)?.creationDate ?? resolvedCurrentDate
        } else {
            // The persisted current asset is gone. Fall back to the nearest
            // still-present asset in the user's preferred direction, skipping
            // anything already decided or marked.
            let excluded = Set(decidedIDs).union(queueIDs)
            if let index = workingOrder.nearestIndex(toDate: session.currentAssetDate, direction: session.direction) {
                let candidate = firstUndecided(
                    in: workingOrder,
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

        // A Limited snapshot can be exhausted while the captured pool still
        // holds hidden undecided members. Finishing there would be permanent:
        // widening access would restore the ids but route straight to Review,
        // never showing the undecided photos again.
        let unavailable = Set(decidedIDs).union(queueIDs)
        let hiddenUndecided = libraryAccessIsLimited && (poolIDs?.contains { id in
            !workingOrder.idSet.contains(id) && !unavailable.contains(id)
        } ?? true)
        let nothingLeftToShow = resolvedCurrentID == nil
            && unavailable.isSuperset(of: workingOrder.idSet)
        let isFinished = (session.isFinished || nothingLeftToShow) && !hiddenUndecided

        let reconciled = PersistedSession(
            currentAssetID: resolvedCurrentID,
            currentAssetDate: resolvedCurrentDate,
            direction: session.direction,
            mode: session.mode,
            decidedIDs: decidedIDs,
            keptIDs: keptIDs,
            undoEntries: undoEntries,
            tumbler: tumbler,
            filterCategories: session.filterCategories,
            poolIDs: poolIDs,
            updatedAt: session.updatedAt,
            isFinished: isFinished
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
