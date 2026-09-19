import Foundation

/// The result of matching a persisted session against the live library.
public struct ReconciledSession: Equatable, Sendable {
    public var session: PersistedSession
    /// Identifiers that were in the deletion queue but no longer exist in the
    /// library. They vanished outside Swiper, so they are **not** counted as
    /// deletions and are **not** reported as successes.
    public var externallyRemovedIDs: [String]

    public init(session: PersistedSession, externallyRemovedIDs: [String]) {
        self.session = session
        self.externallyRemovedIDs = externallyRemovedIDs
    }
}

/// Reconciles persisted identifiers against the current library so sessions
/// survive assets being removed or changed outside Swiper.
public enum AssetReconciler {
    public static func reconcile(_ session: PersistedSession, order: LibraryOrder) -> ReconciledSession {
        let available = order.idSet

        let queueIDs = session.queueIDs.filter { available.contains($0) }
        let externallyRemoved = session.queueIDs.filter { !available.contains($0) }
        let decidedIDs = session.decidedIDs.filter { available.contains($0) }
        let keptIDs = session.keptIDs.filter { available.contains($0) }
        let undoEntries = session.undoEntries.filter { available.contains($0.assetID) }

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
            // anything already decided.
            if let index = order.nearestIndex(toDate: session.currentAssetDate, direction: session.direction) {
                let candidate = firstUndecided(
                    in: order,
                    from: index,
                    direction: session.direction,
                    decided: Set(decidedIDs)
                )
                resolvedCurrentID = candidate?.id
                resolvedCurrentDate = candidate?.creationDate
            } else {
                resolvedCurrentID = nil
                resolvedCurrentDate = nil
            }
        }

        let reconciled = PersistedSession(
            currentAssetID: resolvedCurrentID,
            currentAssetDate: resolvedCurrentDate,
            direction: session.direction,
            mode: session.mode,
            decidedIDs: decidedIDs,
            keptIDs: keptIDs,
            queueIDs: queueIDs,
            undoEntries: undoEntries,
            tumbler: tumbler,
            updatedAt: session.updatedAt,
            isFinished: session.isFinished || (resolvedCurrentID == nil && Set(decidedIDs).isSuperset(of: available))
        )
        return ReconciledSession(session: reconciled, externallyRemovedIDs: externallyRemoved)
    }

    private static func firstUndecided(
        in order: LibraryOrder,
        from index: Int,
        direction: TraversalDirection,
        decided: Set<String>
    ) -> AssetDescriptor? {
        let step = direction == .older ? -1 : 1
        var cursor = index
        while order.assets.indices.contains(cursor) {
            let asset = order.assets[cursor]
            if !decided.contains(asset.id) { return asset }
            cursor += step
        }
        cursor = index - step
        while order.assets.indices.contains(cursor) {
            let asset = order.assets[cursor]
            if !decided.contains(asset.id) { return asset }
            cursor -= step
        }
        return nil
    }
}
