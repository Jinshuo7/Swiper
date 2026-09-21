import Foundation

/// The pure decision engine for one cleanup session.
///
/// It owns ordering, the deletion queue, the undo history and traversal state,
/// but it never talks to PhotoKit. `apply(_:)` returns ``SessionEffect`` values
/// that the host app performs against the real library. This separation is what
/// makes ordering, resume, queue/restore/undo and Tumbler behaviour unit
/// testable without touching a user's photos.
public struct SessionEngine: Equatable, Sendable {
    public private(set) var order: LibraryOrder
    public private(set) var direction: TraversalDirection
    public private(set) var mode: SessionMode
    public private(set) var cursorID: String?
    public private(set) var queue: DeletionQueue
    public private(set) var undoStack: UndoStack
    public private(set) var decidedIDs: Set<String>
    public private(set) var keptIDs: Set<String>
    public private(set) var tumbler: TumblerPlan?
    public private(set) var isFinished: Bool

    public init(
        order: LibraryOrder,
        direction: TraversalDirection = .older,
        mode: SessionMode = .sequential,
        cursorID: String? = nil,
        queue: DeletionQueue = .empty,
        undoStack: UndoStack = .empty,
        decidedIDs: Set<String> = [],
        keptIDs: Set<String> = [],
        tumbler: TumblerPlan? = nil,
        tumblerSeed: UInt64? = nil,
        isFinished: Bool = false
    ) {
        self.order = order
        self.direction = direction
        self.mode = mode
        self.cursorID = cursorID
        self.queue = queue
        self.undoStack = undoStack
        self.decidedIDs = decidedIDs
        self.keptIDs = keptIDs
        self.isFinished = isFinished
        if mode == .tumbler {
            self.tumbler = tumbler ?? TumblerPlan(assetIDs: order.ids, seed: tumblerSeed ?? SessionEngine.makeSeed())
        } else {
            self.tumbler = tumbler
        }
    }

    public static func makeSeed() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1_000) ^ UInt64.random(in: 0..<UInt64.max)
    }

    // MARK: - Derived state

    public var current: AssetDescriptor? {
        guard let cursorID else { return nil }
        return order.asset(byID: cursorID)
    }

    public var currentIsFavorite: Bool { current?.isFavorite ?? false }

    public var queueIDs: [String] { queue.ids }

    public var remainingCount: Int {
        order.assets.reduce(into: 0) { partial, asset in
            if !isUnavailable(asset.id) { partial += 1 }
        }
    }

    /// An asset is unavailable for traversal when it has already been decided in
    /// this session, or when it is marked for deletion. Marks outlive sorting
    /// sessions, so a photo the user already marked must never be presented
    /// again just because a new session started.
    public func isUnavailable(_ id: String) -> Bool {
        decidedIDs.contains(id) || queue.contains(id)
    }

    public var isEmpty: Bool { order.isEmpty }

    public func upcomingIDs(limit: Int) -> [String] {
        guard limit > 0 else { return [] }
        if mode == .tumbler, let tumbler {
            return tumbler.peek(
                limit: limit,
                availableIDs: order.idSet,
                excluding: unavailableIDs
            )
        }

        let step = direction == .older ? -1 : 1
        guard let cursorID, let index = order.index(of: cursorID) else {
            let indices: [Int]
            if direction == .older {
                indices = Array(order.assets.indices.reversed())
            } else {
                indices = Array(order.assets.indices)
            }
            return indices.lazy
                .map { order.assets[$0] }
                .filter { !isUnavailable($0.id) }
                .prefix(limit)
                .map(\.id)
        }
        var ids: [String] = []
        for candidateStep in [step, -step] {
            var candidateIndex = index + candidateStep
            while ids.count < limit, order.assets.indices.contains(candidateIndex) {
                let id = order.assets[candidateIndex].id
                if !isUnavailable(id) { ids.append(id) }
                candidateIndex += candidateStep
            }
        }
        return ids
    }

    // MARK: - Decisions

    /// Applies a decision and returns the effects the host must perform.
    @discardableResult
    public mutating func apply(_ action: SessionAction) -> [SessionEffect] {
        if action == .undo { return undo() }
        guard let asset = current else { return [.noOp] }
        switch action {
        case .queueDeletion:
            queue.add(asset.id)
            decidedIDs.insert(asset.id)
            keptIDs.remove(asset.id)
            let advanceEffect = advance()
            undoStack.push(UndoEntry(
                assetID: asset.id,
                effect: .queuedDeletion,
                displacedAssetID: mode == .tumbler ? cursorID : nil
            ))
            return [.queuedDeletion(id: asset.id), advanceEffect]
        case .keep:
            decidedIDs.insert(asset.id)
            keptIDs.insert(asset.id)
            let advanceEffect = advance()
            undoStack.push(UndoEntry(
                assetID: asset.id,
                effect: .kept,
                displacedAssetID: mode == .tumbler ? cursorID : nil
            ))
            return [advanceEffect]
        case .favorite:
            let previous = asset.isFavorite
            decidedIDs.insert(asset.id)
            keptIDs.insert(asset.id)
            let advanceEffect = advance()
            undoStack.push(UndoEntry(
                assetID: asset.id,
                effect: .favorited(previousValue: previous),
                displacedAssetID: mode == .tumbler ? cursorID : nil
            ))
            return [.setFavorite(id: asset.id, isFavorite: true), advanceEffect]
        case .undo:
            return [.noOp]
        }
    }

    /// Reverses the most recent decision and returns to that asset.
    @discardableResult
    public mutating func undo() -> [SessionEffect] {
        guard let entry = undoStack.pop() else { return [.noOp] }
        var effects: [SessionEffect] = []
        switch entry.effect {
        case .queuedDeletion:
            queue.remove(entry.assetID)
            effects.append(.unqueuedDeletion(id: entry.assetID))
        case .favorited(let previous):
            effects.append(.setFavorite(id: entry.assetID, isFavorite: previous))
        case .kept:
            break
        }
        decidedIDs.remove(entry.assetID)
        keptIDs.remove(entry.assetID)
        if mode == .tumbler, let displacedAssetID = entry.displacedAssetID {
            tumbler?.requeue(displacedAssetID)
            tumbler?.requeue(entry.assetID)
        }
        if order.contains(id: entry.assetID) {
            cursorID = entry.assetID
            isFinished = false
        }
        effects.append(.undoApplied(assetID: entry.assetID))
        return effects
    }

    // MARK: - Traversal

    /// Places the cursor for a fresh session and returns the first effect.
    @discardableResult
    public mutating func start() -> SessionEffect {
        cursorID = nil
        isFinished = false
        return advance()
    }

    @discardableResult
    public mutating func advance() -> SessionEffect {
        guard let next = nextCandidateID() else {
            cursorID = nil
            isFinished = true
            return .sessionFinished
        }
        cursorID = next
        isFinished = false
        return .advanced
    }

    /// Jumps directly to a specific asset (used by "Start Here"). A marked
    /// asset is refused: it is waiting in deletion review, not for a decision.
    @discardableResult
    public mutating func jump(to id: String) -> SessionEffect {
        guard order.contains(id: id), !queue.contains(id) else { return .noOp }
        cursorID = id
        isFinished = false
        return .advanced
    }

    public mutating func setDirection(_ newDirection: TraversalDirection) {
        direction = newDirection
    }

    private mutating func nextCandidateID() -> String? {
        if mode == .tumbler, var plan = tumbler {
            while let candidate = plan.next() {
                tumbler = plan
                guard order.contains(id: candidate) else { continue }
                if isUnavailable(candidate) { continue }
                return candidate
            }
            tumbler = plan
            return nil
        }

        if let cursorID, let index = order.index(of: cursorID) {
            let step = direction == .older ? -1 : 1
            if let id = search(from: index, step: step) { return id }
            if let id = search(from: index, step: -step) {
                direction = direction.reversed
                return id
            }
            return nil
        }

        return firstUndecided(preferNewest: direction == .older)
    }

    private func search(from index: Int, step: Int) -> String? {
        var cursor = index + step
        while order.assets.indices.contains(cursor) {
            let id = order.assets[cursor].id
            if !isUnavailable(id) { return id }
            cursor += step
        }
        return nil
    }

    private var unavailableIDs: Set<String> {
        decidedIDs.union(queue.orderedIDs)
    }

    private func firstUndecided(preferNewest: Bool) -> String? {
        let count = order.assets.count
        guard count > 0 else { return nil }
        if preferNewest {
            for index in stride(from: count - 1, through: 0, by: -1) {
                let id = order.assets[index].id
                if !isUnavailable(id) { return id }
            }
        } else {
            for index in 0..<count {
                let id = order.assets[index].id
                if !isUnavailable(id) { return id }
            }
        }
        return nil
    }

    // MARK: - Deletion review

    /// Takes assets out of the deletion queue. Restored assets become kept and
    /// are never deleted.
    @discardableResult
    public mutating func restore(ids: [String]) -> [SessionEffect] {
        var effects: [SessionEffect] = []
        var restored = Set<String>()
        for id in ids where queue.contains(id) {
            queue.remove(id)
            restored.insert(id)
            if order.contains(id: id) {
                // A restored photo is decided for this session, so traversal
                // does not walk straight back onto it, and a later session may
                // present it again.
                keptIDs.insert(id)
                decidedIDs.insert(id)
            }
            effects.append(.unqueuedDeletion(id: id))
        }
        undoStack.removeEntries(forAssetIDs: Array(restored))
        return effects
    }

    /// Called after a confirmed successful deletion so the engine stops
    /// tracking the removed assets, while keeping lifetime statistics intact.
    public mutating func commitDeletion(outcome: DeletionOutcome) {
        let deleted = Set(outcome.deletedIDs)
        for id in deleted {
            queue.remove(id)
            decidedIDs.remove(id)
            keptIDs.remove(id)
        }
        undoStack.removeEntries(forAssetIDs: outcome.deletedIDs)
        if let cursorID, deleted.contains(cursorID) {
            self.cursorID = nil
        }
    }

    // MARK: - Persistence

    public func persisted(updatedAt: Date = Date()) -> PersistedSession {
        PersistedSession(
            currentAssetID: cursorID,
            currentAssetDate: current?.creationDate,
            direction: direction,
            mode: mode,
            decidedIDs: Array(decidedIDs),
            keptIDs: Array(keptIDs),
            undoEntries: undoStack.entries,
            tumbler: tumbler,
            updatedAt: updatedAt,
            isFinished: isFinished
        )
    }

    /// Rebuilds a session from persisted traversal state plus the durable
    /// deletion list, which outlives any single session.
    public static func restored(
        from persisted: PersistedSession,
        order: LibraryOrder,
        marks: [String] = []
    ) -> SessionEngine {
        SessionEngine(
            order: order,
            direction: persisted.direction,
            mode: persisted.mode,
            cursorID: persisted.currentAssetID,
            queue: DeletionQueue(orderedIDs: marks),
            undoStack: UndoStack(entries: persisted.undoEntries),
            decidedIDs: Set(persisted.decidedIDs),
            keptIDs: Set(persisted.keptIDs),
            tumbler: persisted.tumbler,
            isFinished: persisted.isFinished
        )
    }
}
