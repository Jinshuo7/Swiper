import Photos
import SwiperKit
import UIKit

/// Owns the whole app state machine: permissions, the library snapshot, the
/// durable deletion list, the current session, statistics and preferences.
///
/// The model performs the ``SessionEffect`` values the pure engine emits; the
/// engine never touches PhotoKit itself.
///
/// Durability contract: a decision is applied to a *copy* of the session, that
/// copy is saved, and only a successful save is acknowledged by publishing it
/// and advancing. A failed save leaves the previous state untouched and parks
/// the decision for an explicit retry, so the UI can never imply that unsaved
/// work was accepted.
///
/// Every state mutation runs on one serial chain, so two quick gestures cannot
/// interleave and produce a save that does not match the visible session.
@MainActor
final class AppModel: ObservableObject {
    enum Route: Equatable {
        case loading
        case permission
        case entry
        case viewer
        case review
        case result
        case statistics
        case settings
        case startHere
    }

    /// A decision that was computed but could not be saved. It is retried
    /// verbatim: every library side effect was already performed during
    /// staging, so retrying only re-attempts persistence.
    struct PendingDecision: Equatable {
        var engine: SessionEngine
        var message: String
    }

    @Published var route: Route = .loading
    @Published private(set) var authorization: LibraryAuthorization = .notDetermined
    @Published private(set) var order: LibraryOrder = .empty
    @Published private(set) var engine: SessionEngine?
    @Published private(set) var preferences: ControlPreferences
    @Published private(set) var statistics: SessionStatistics
    @Published private(set) var resumableSession: PersistedSession?
    /// The durable deletion list. It is written with every decision, and a
    /// session started from home is seeded from it.
    @Published private(set) var marks: DeletionQueue = .empty
    @Published private(set) var lastDeletion: DeletionOutcome = .empty
    @Published private(set) var isBusy = false
    /// True while a decision is being staged and saved, so input is serialised.
    @Published private(set) var isDecisionInFlight = false
    /// Set when the last state write failed.
    @Published private(set) var pendingDecision: PendingDecision?
    /// A durable, user-visible explanation of a persistence problem.
    @Published private(set) var persistenceNotice: String?
    /// True while stored data this build cannot read is in the way, so nothing
    /// may be written over it.
    @Published private(set) var isPersistenceReadOnly = false
    /// Where "Back" from deletion review should return to.
    @Published private(set) var reviewOrigin: Route = .entry
    @Published var errorMessage: String?
    /// True while the one-time sorting explanation is on screen.
    @Published private(set) var isShowingTutorial = false

    let library: SwiperPhotoLibrary
    private let store: SessionStoring
    /// Tutorial completion lives in user defaults rather than the session store:
    /// it is a one-off piece of teaching, not saved work. Tests inject their own
    /// defaults so a run never inherits another run's answer.
    private let defaults: UserDefaults
    private enum DefaultsKey {
        static let hasSeenSwipeTutorial = "hasSeenSwipeTutorial"
    }

    /// The state as loaded, kept as the durable baseline between decisions.
    private var storedState = PersistedState()
    private var didBootstrap = false
    private var serialTail: Task<Void, Never>?
    /// Set for the rest of the launch once the tutorial was dismissed, so a
    /// launch argument that pins the flag off cannot make it reappear.
    private var didFinishTutorial = false

    init(library: SwiperPhotoLibrary, store: SessionStoring, defaults: UserDefaults = .standard) {
        self.library = library
        self.store = store
        self.defaults = defaults
        self.preferences = store.loadPreferences()
        self.statistics = store.loadStatistics()
        self.library.changeHandler = { [weak self] in
            Task { @MainActor in
                await self?.reloadLibrary()
            }
        }
    }

    var currentAsset: AssetDescriptor? { engine?.current }
    var markedIDs: [String] { engine?.queue.ids ?? marks.ids }
    var queueCount: Int { markedIDs.count }
    var hasPhotos: Bool { !order.isEmpty }

    /// Decision input is refused while a save is in flight or a failed save is
    /// waiting to be retried.
    var isDecisionInputBlocked: Bool { isDecisionInFlight || pendingDecision != nil }

    // MARK: - Serialisation

    /// Appends `work` to the single mutation chain and returns the task that
    /// runs it.
    ///
    /// The chain link is installed *synchronously*, before returning. That
    /// matters: two gestures delivered in the same run-loop turn must not both
    /// see an empty tail, or they would run concurrently and the later save
    /// could overwrite the earlier one.
    private func chain(_ work: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        let previous = serialTail
        let task = Task { @MainActor in
            await previous?.value
            await work()
        }
        serialTail = task
        return task
    }

    /// Queues a mutation started from a synchronous UI action.
    private func enqueue(_ work: @escaping @MainActor () async -> Void) {
        _ = chain(work)
    }

    /// Runs `work` after every previously queued mutation has finished and waits
    /// for it, for callers that are already asynchronous.
    private func serialized(_ work: @escaping @MainActor () async -> Void) async {
        await chain(work).value
    }

    /// Test seam: waits until every mutation queued so far has settled.
    func settle() async {
        await serialTail?.value
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        await loadPersistedState()
        await refreshAuthorization()
    }

    /// Reads stored state and reports anything this build cannot read instead
    /// of silently starting empty.
    private func loadPersistedState() async {
        switch store.loadState() {
        case .absent:
            storedState = PersistedState()
        case .loaded(let state):
            storedState = state
        case .migrated(let state):
            storedState = state
            // Finish the migration, but replace the old bytes only once the
            // atomic write has succeeded.
            do {
                try await store.saveState(state)
                persistenceNotice = "Your saved progress was upgraded to the latest format."
            } catch {
                persistenceNotice = describe(error)
            }
        case .unreadable(let reason):
            isPersistenceReadOnly = true
            persistenceNotice = "Swiper could not read your saved progress (\(reason)). Nothing has been overwritten."
        case .unsupportedVersion(let found, let supported):
            isPersistenceReadOnly = true
            persistenceNotice = SessionStoreError
                .stateIsFromNewerVersion(found: found, supported: supported)
                .localizedDescription
        }
        marks = DeletionQueue(orderedIDs: storedState.marks)
    }

    /// Preserves unreadable stored data under a new name and starts fresh.
    func recoverFromUnreadableState() async {
        do {
            let destination = try store.quarantineUnreadableState()
            isPersistenceReadOnly = false
            storedState = PersistedState()
            marks = .empty
            resumableSession = nil
            engine = nil
            if let destination {
                persistenceNotice = "Your old file was kept as \(destination.lastPathComponent), then set aside."
            } else {
                persistenceNotice = nil
            }
        } catch {
            persistenceNotice = describe(error)
        }
    }

    func dismissPersistenceNotice() { persistenceNotice = nil }

    // MARK: - Teaching

    var hasSeenTutorial: Bool { defaults.bool(forKey: DefaultsKey.hasSeenSwipeTutorial) }

    /// Shows the sorting explanation the first time a photo is presented.
    func presentTutorialIfNeeded() {
        guard !didFinishTutorial, !hasSeenTutorial, !isShowingTutorial else { return }
        isShowingTutorial = true
    }

    /// Dismissing is permanent until the user asks for it again from Settings.
    func dismissTutorial() {
        didFinishTutorial = true
        isShowingTutorial = false
        defaults.set(true, forKey: DefaultsKey.hasSeenSwipeTutorial)
    }

    /// Settings → How to use replays the explanation without changing any work.
    func replayTutorial() {
        isShowingTutorial = true
    }

    func refreshAuthorization() async {
        authorization = library.currentAuthorization()
        guard authorization.canBrowse else {
            route = .permission
            return
        }
        await reloadLibrary()
        if route == .loading || route == .permission {
            route = .entry
        }
    }

    func requestAccess() async {
        isBusy = true
        authorization = await library.requestAuthorization()
        isBusy = false
        if authorization.canBrowse {
            await reloadLibrary()
            route = .entry
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func manageLimitedLibrary() {
        guard let controller = UIApplication.topViewController() else { return }
        library.presentLimitedLibraryPicker(from: controller)
    }

    /// Refreshes the metadata snapshot and reconciles stored state against it.
    func reloadLibrary() async {
        let descriptors = await library.fetchAllDescriptors()
        order = LibraryOrder(descriptors)

        let reconciled = AssetReconciler.reconcile(storedState, order: order)
        storedState = reconciled.state

        if let session = storedState.session, session.isResumable {
            let restored = SessionEngine.restored(from: session, order: order, marks: storedState.marks)
            engine = restored
            marks = restored.queue
            resumableSession = session
        } else {
            engine = nil
            marks = DeletionQueue(orderedIDs: storedState.marks)
            resumableSession = nil
        }

        if !reconciled.externallyRemovedIDs.isEmpty, !isPersistenceReadOnly {
            await persistQuietly(storedState)
        }

        if engine?.isFinished == true && route == .viewer {
            reviewOrigin = .viewer
            route = .review
        }
    }

    // MARK: - Entry points

    func startRecent() {
        enqueue { await self.startSession(mode: .sequential, cursorID: nil, direction: .older) }
    }

    func startTumbler() {
        enqueue { await self.startSession(mode: .tumbler, cursorID: nil) }
    }

    func startHere(assetID: String) {
        enqueue {
            guard !self.marks.contains(assetID) else {
                self.errorMessage = "That photo is marked for deletion, so it is skipped while sorting. Open Review to restore it."
                return
            }
            await self.startSession(mode: .sequential, cursorID: assetID)
        }
    }

    func showStartHere() { route = .startHere }

    private func startSession(
        mode: SessionMode,
        cursorID: String?,
        direction: TraversalDirection? = nil
    ) async {
        guard hasPhotos else {
            errorMessage = "There are no photos or Live Photos to review."
            return
        }

        // The deletion list outlives sorting sessions: a new session resets
        // traversal and Undo, never marks.
        let sessionMarks = marks

        isDecisionInFlight = true
        defer { isDecisionInFlight = false }

        statistics.beginSession()
        store.saveStatistics(statistics)

        var newEngine = SessionEngine(
            order: order,
            direction: direction ?? preferences.defaultDirection,
            mode: mode,
            cursorID: cursorID,
            queue: sessionMarks,
            tumblerSeed: mode == .tumbler ? SessionEngine.makeSeed() : nil
        )
        if cursorID == nil || mode == .tumbler {
            newEngine.start()
        }

        let state = PersistedState(marks: newEngine.queue.ids, session: newEngine.persisted())
        do {
            try await store.saveState(state)
        } catch {
            errorMessage = describe(error)
            return
        }

        storedState = state
        engine = newEngine
        marks = newEngine.queue
        resumableSession = state.session
        route = .viewer
    }

    func resumeSession() {
        guard let persisted = resumableSession ?? storedState.session else { return }
        let restored = SessionEngine.restored(from: persisted, order: order, marks: storedState.marks)
        engine = restored
        route = restored.isFinished ? .review : .viewer
    }

    // MARK: - Decisions

    func apply(_ action: SessionAction) {
        enqueue { await self.stage(action) }
    }

    func undo() { apply(.undo) }

    /// Applies the decision to a copy of the session, performs every library
    /// effect it needs, saves, and only then acknowledges it.
    ///
    /// Library effects always happen *before* the save. That ordering is what
    /// makes a retry safe: by the time a decision can be parked, its PhotoKit
    /// side effect is already done, so retrying only re-attempts the write and
    /// can never repeat a favorite change.
    private func stage(_ action: SessionAction) async {
        guard pendingDecision == nil, let engine else { return }

        isDecisionInFlight = true
        defer { isDecisionInFlight = false }

        var staged = engine
        var libraryEffects: [SessionEffect] = []

        if action == .favorite {
            guard let assetID = staged.current?.id else { return }
            libraryEffects.append(.setFavorite(id: assetID, isFavorite: true))
        }

        for effect in staged.apply(action) {
            guard case .setFavorite = effect, action != .favorite else { continue }
            libraryEffects.append(effect)
        }

        guard await performLibraryEffects(libraryEffects) else { return }
        await acknowledge(staged)
    }

    /// Saves the staged session and publishes it, or parks it for retry. There
    /// is nothing left to perform afterwards: every library effect already
    /// happened before this point.
    private func acknowledge(_ staged: SessionEngine) async {
        let state = PersistedState(marks: staged.queue.ids, session: staged.persisted())
        do {
            try await store.saveState(state)
        } catch {
            pendingDecision = PendingDecision(engine: staged, message: describe(error))
            return
        }
        storedState = state
        engine = staged
        marks = staged.queue
        resumableSession = state.session
        pendingDecision = nil
        persistenceNotice = nil
    }

    /// Retries the parked decision. Only persistence is re-attempted, so a
    /// retry can never repeat a favorite change or a queued-deletion effect.
    func retryPendingDecision() async {
        await serialized {
            guard let pending = self.pendingDecision else { return }
            self.isDecisionInFlight = true
            await self.acknowledge(pending.engine)
            self.isDecisionInFlight = false
        }
    }

    /// Drops a decision that could never be saved. The stored state is
    /// untouched, so this only forgets an acknowledgement the user never
    /// received.
    func discardPendingDecision() {
        pendingDecision = nil
        persistenceNotice = "That decision was not saved, so it was left out. Nothing else changed."
        route = .entry
    }

    func goToReview(from origin: Route) {
        reviewOrigin = origin
        route = .review
    }

    /// Leaves deletion review for wherever it was opened from, falling back to
    /// home when there is nothing to sort any more.
    func leaveReview() {
        switch reviewOrigin {
        case .viewer, .result:
            route = engine == nil ? .entry : reviewOrigin
        default:
            route = .entry
        }
    }

    /// Leaving the viewer is only navigation: every decision was already saved
    /// before it was acknowledged, so nothing is discarded by going home.
    func closeViewer() {
        route = .entry
    }

    /// Where the user goes after a deletion commit. Returns to the sorting
    /// position when a session is still active, to review when the session is
    /// exhausted but marks remain, and home when there is nothing left.
    func continueAfterResult() {
        guard let engine else {
            route = .entry
            return
        }
        if engine.isFinished {
            reviewOrigin = .result
            route = markedIDs.isEmpty ? .entry : .review
        } else {
            route = .viewer
        }
    }

    /// How the result screen should label its only button.
    var resultContinuationTitle: String {
        guard let engine else { return "Done" }
        if engine.isFinished { return markedIDs.isEmpty ? "Done" : "Review marked photos" }
        return "Continue sorting"
    }

    func finishSession() {
        enqueue {
            self.statistics.completeSession()
            self.store.saveStatistics(self.statistics)
            self.engine = nil
            self.resumableSession = nil
            self.storedState = PersistedState(marks: self.storedState.marks, session: nil)
            self.marks = DeletionQueue(orderedIDs: self.storedState.marks)
            await self.persistQuietly(self.storedState)
            self.route = .entry
        }
    }

    func restore(ids: [String]) {
        enqueue {
            guard self.pendingDecision == nil else { return }
            self.isDecisionInFlight = true
            defer { self.isDecisionInFlight = false }

            if var staged = self.engine {
                // Restoring unmarks and keeps the photo for this session. It has
                // no library effect, so it only has to be saved.
                staged.restore(ids: ids)
                await self.acknowledge(staged)
                return
            }

            // No active sorting session: review is reachable from home, so
            // restoring only has to unmark and save.
            var updated = self.marks
            for id in ids { updated.remove(id) }
            let state = PersistedState(marks: updated.ids, session: nil)
            do {
                try await self.store.saveState(state)
            } catch {
                self.persistenceNotice = self.describe(error)
                return
            }
            self.storedState = state
            self.marks = updated
        }
    }

    func updatePreferences(_ preferences: ControlPreferences) {
        self.preferences = preferences
        store.savePreferences(preferences)
        if var engine {
            engine.setDirection(preferences.defaultDirection)
            self.engine = engine
            storedState.session = engine.persisted()
            Task { await self.persistQuietly(self.storedState) }
        }
    }

    // MARK: - Deletion

    func confirmDeletion() async {
        await serialized { await self.performConfirmedDeletion() }
    }

    private func performConfirmedDeletion() async {
        let requested = markedIDs
        guard !requested.isEmpty else { return }
        isBusy = true
        defer { isBusy = false }

        let descriptors = await library.descriptors(forIDs: requested)
        do {
            let submitted = try await library.deleteAssets(ids: requested)
            let stillPresent = await library.existingAssetIDs(among: requested)
            let outcome = DeletionResolver.outcome(
                requestedIDs: requested,
                submittedIDs: Set(submitted),
                descriptors: descriptors,
                stillPresentIDs: stillPresent
            )

            let refreshedOrder = LibraryOrder(await library.fetchAllDescriptors())
            order = refreshedOrder

            // Unsuccessful assets stay marked; only confirmed deletions leave
            // the list, so a retry can never re-request or re-count them.
            var updatedMarks = DeletionQueue(orderedIDs: requested)
            for id in outcome.deletedIDs { updatedMarks.remove(id) }

            var updatedEngine = engine
            updatedEngine?.commitDeletion(outcome: outcome)
            let session = updatedEngine?.persisted() ?? storedState.session

            let reconciled = AssetReconciler.reconcile(
                PersistedState(marks: updatedMarks.ids, session: session),
                order: refreshedOrder
            )
            let state = reconciled.state

            statistics.record(outcome)
            store.saveStatistics(statistics)

            do {
                try await store.saveState(state)
            } catch {
                // The library already changed. Never report a success the user
                // cannot trust: say exactly what could not be saved.
                persistenceNotice = "Swiper deleted the confirmed photos but could not save the updated list. \(describe(error))"
            }

            storedState = state
            if let session = state.session, session.isResumable {
                let restored = SessionEngine.restored(from: session, order: refreshedOrder, marks: state.marks)
                self.engine = restored
                marks = restored.queue
                resumableSession = session
            } else {
                self.engine = nil
                marks = DeletionQueue(orderedIDs: state.marks)
                resumableSession = nil
            }

            lastDeletion = outcome
            route = .result
        } catch {
            errorMessage = "Swiper could not delete those photos: \(error.localizedDescription)"
        }
    }

    func dismissResult() {
        continueAfterResult()
    }

    // MARK: - Effect handling

    /// Performs the PhotoKit half of a decision, in order, before anything is
    /// recorded. Returns `false` when the library refused, in which case the
    /// decision is abandoned and the session is left as it was.
    @discardableResult
    private func performLibraryEffects(_ effects: [SessionEffect]) async -> Bool {
        for effect in effects {
            guard case .setFavorite(let id, let isFavorite) = effect else { continue }
            do {
                try await library.setFavorite(isFavorite, forID: id)
            } catch {
                errorMessage = "Couldn't update the favorite: \(error.localizedDescription)"
                return false
            }
        }
        return true
    }

    // MARK: - Persistence helpers

    private func persistQuietly(_ state: PersistedState) async {
        guard !isPersistenceReadOnly else { return }
        do {
            try await store.saveState(state)
        } catch {
            persistenceNotice = describe(error)
        }
    }

    private func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
