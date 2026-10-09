import Photos
import SWIPRKit
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
        case settings
        case filters
        case choosePhoto
    }

    /// A decision that was computed but could not be saved. It is retried
    /// verbatim: every library side effect was already performed during
    /// staging, so retrying only re-attempts persistence.
    struct PendingDecision: Equatable {
        var engine: SessionEngine
        var message: String
    }

    /// A start request that would discard an unfinished session. It is held until
    /// the user chooses **Start new**; choosing **Keep current** drops it without
    /// touching any saved work.
    struct PendingReplacement: Equatable {
        var mode: SessionMode
        var cursorID: String?
        var direction: TraversalDirection?
    }

    @Published var route: Route = .loading
    @Published private(set) var authorization: LibraryAuthorization = .notDetermined
    @Published private(set) var order: LibraryOrder = .empty
    @Published private(set) var engine: SessionEngine?
    @Published private(set) var preferences: ControlPreferences
    @Published private(set) var statistics: SessionStatistics
    @Published private(set) var resumableSession: PersistedSession?
    /// The start request waiting for the replace-session confirmation, or `nil`
    /// when no unfinished session would be discarded.
    @Published private(set) var pendingReplacement: PendingReplacement?
    /// The media categories chosen for the next session. Editing starts from a
    /// Home preset, so a previous session's exclusions are never silently
    /// reused; Continue sorting restores its own saved filters instead.
    @Published private(set) var filter: MediaFilter = .everything
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

    let library: SWIPRPhotoLibrary
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

    init(library: SWIPRPhotoLibrary, store: SessionStoring, defaults: UserDefaults = .standard) {
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

    /// The pool a new session would walk right now: the live library confined to
    /// the current filter. Captured once when the session starts, so later
    /// library changes cannot move the goalposts.
    var filteredOrder: LibraryOrder { filter.apply(to: order) }
    var filteredCount: Int { filteredOrder.count }
    /// Plain-language summary of the current filter and how many assets match.
    var filterSummary: String { filter.summary(matchingCount: filteredCount) }

    /// Decision input is refused while a save is in flight or a failed save is
    /// waiting to be retried.
    var isDecisionInputBlocked: Bool { isDecisionInFlight || pendingDecision != nil }

    /// Whether a saved session is waiting to be continued. Starting a new one now
    /// would replace its position and session Undo, so it is gated behind an
    /// explicit confirmation instead of happening silently.
    var hasUnfinishedSession: Bool { resumableSession != nil }

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
            persistenceNotice = "SWIPR could not read your saved progress (\(reason)). Nothing has been overwritten."
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

        if !reconciled.externallyRemovedIDs.isEmpty {
            // Photos vanished outside SWIPR — deleted on another device, or by
            // the system. Silently dropping them would leave the user wondering
            // where a mark went, which is exactly the ambiguity to avoid when
            // they come back to the app after an interruption.
            let count = reconciled.externallyRemovedIDs.count
            persistenceNotice = count == 1
                ? "One marked photo is no longer in your library, so it was removed from the list."
                : "\(count) marked photos are no longer in your library, so they were removed from the list."
            if !isPersistenceReadOnly {
                await persistQuietly(storedState)
            }
        }

        if engine?.isFinished == true && route == .viewer {
            reviewOrigin = .viewer
            route = .review
        }
    }

    // MARK: - Entry points

    /// Starts at the newest asset and walks older. The direction is pinned,
    /// never taken from the preference, so the button always does what its
    /// label says.
    func startNewest() {
        requestSession(mode: .sequential, cursorID: nil, direction: .older)
    }

    /// Starts at the oldest asset and walks newer, mirroring ``startNewest()``.
    func startOldest() {
        requestSession(mode: .sequential, cursorID: nil, direction: .newer)
    }

    func startTumbler() {
        requestSession(mode: .tumbler, cursorID: nil)
    }

    func startFrom(assetID: String) {
        // A marked photo is waiting in Review, not for a decision, so it never
        // starts a session and never reaches the replacement confirmation.
        guard !marks.contains(assetID) else {
            errorMessage = "That photo is marked for deletion, so it is skipped while sorting. Open Review to restore it."
            return
        }
        requestSession(mode: .sequential, cursorID: assetID)
    }

    /// Routes a start through the replacement confirmation when an unfinished
    /// session would be discarded, and starts immediately when there is none.
    ///
    /// Requesting writes nothing: the saved session is only replaced once the
    /// user chooses **Start new**, so **Keep current** leaves it untouched.
    private func requestSession(
        mode: SessionMode,
        cursorID: String?,
        direction: TraversalDirection? = nil
    ) {
        guard hasUnfinishedSession else {
            enqueue { await self.startSession(mode: mode, cursorID: cursorID, direction: direction) }
            return
        }
        pendingReplacement = PendingReplacement(mode: mode, cursorID: cursorID, direction: direction)
    }

    /// Confirms the waiting replacement. The position and session Undo are
    /// replaced while the durable deletion list is untouched, so marked items
    /// stay marked and are skipped by the new traversal.
    func confirmReplacement() {
        guard let request = pendingReplacement else { return }
        pendingReplacement = nil
        enqueue {
            await self.startSession(
                mode: request.mode,
                cursorID: request.cursorID,
                direction: request.direction
            )
        }
    }

    /// Keeps the unfinished session exactly as it was and dismisses the
    /// confirmation. Nothing changed while the confirmation was visible.
    func keepCurrentSession() {
        pendingReplacement = nil
    }

    /// Opens the editable filters for one Home media choice. The preset is
    /// applied fresh, so exclusions from an earlier attempt never leak in.
    func showFilters(_ preset: MediaFilter) {
        filter = preset
        route = .filters
    }

    func toggleFilterCategory(_ category: MediaCategory) {
        var updated = filter
        updated.toggle(category)
        filter = updated
    }

    func onlyFilterCategory(_ category: MediaCategory) {
        var updated = filter
        updated.selectOnly(category)
        filter = updated
    }

    func clearFilter() { filter = .empty }

    /// Leaves the filters for the starting-point grid, preserving the selection
    /// so coming back from the grid shows exactly what was chosen.
    func continueToChoosePhoto() {
        guard !filteredOrder.isEmpty else { return }
        route = .choosePhoto
    }

    private func startSession(
        mode: SessionMode,
        cursorID: String?,
        direction: TraversalDirection? = nil
    ) async {
        let sessionOrder = filteredOrder
        guard !sessionOrder.isEmpty else {
            errorMessage = hasPhotos
                ? "Nothing matches these filters. Change what's included and try again."
                : "There are no photos or Live Photos to review."
            return
        }

        // The deletion list outlives sorting sessions: a new session resets
        // traversal and Undo, never marks.
        let sessionMarks = marks

        isDecisionInFlight = true
        defer { isDecisionInFlight = false }

        statistics.beginSession()
        store.saveStatistics(statistics)

        // The session captures the filtered stable identifiers now. New library
        // arrivals then wait for a new session, and vanished members reconcile
        // on the next reload.
        var newEngine = SessionEngine(
            order: sessionOrder,
            direction: direction ?? preferences.defaultDirection,
            mode: mode,
            cursorID: cursorID,
            queue: sessionMarks,
            tumblerSeed: mode == .tumbler ? SessionEngine.makeSeed() : nil,
            poolIDs: Set(sessionOrder.ids),
            filterCategories: filter.categories
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
        // Continue sorting restores the session's own saved filters and captured
        // pool, never whatever the Home filters happen to show now.
        if let categories = persisted.filterCategories {
            filter = MediaFilter(categories: categories)
        }
        let restored = SessionEngine.restored(from: persisted, order: order, marks: storedState.marks)
        engine = restored
        route = restored.isFinished ? .review : .viewer
    }

    // MARK: - Decisions

    func apply(_ action: SessionAction) {
        enqueue { await self.stage(action) }
    }

    func undo() { apply(.undo) }

    /// Applies the decision to a copy of the session, saves it, and only then
    /// acknowledges it.
    ///
    /// A decision performs no library work of its own: marking a photo for
    /// deletion changes only the session and the deletion list. Deleting happens
    /// later, in ``confirmDeletion()``, and only after the user confirms it.
    private func stage(_ action: SessionAction) async {
        guard pendingDecision == nil, let engine else { return }

        isDecisionInFlight = true
        defer { isDecisionInFlight = false }

        var staged = engine
        staged.apply(action)
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
    /// retry cannot repeat a queued-deletion effect.
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

    /// Stores `preferences` and applies the one of them a running session is
    /// built from.
    ///
    /// Only **Default direction** re-points the walk: it is the direction the
    /// next session starts in, and a session already under way is turned to it
    /// at once, so the choice takes effect immediately. The other preferences —
    /// where the dock sits, whether it is drawn, which end Undo takes, whether
    /// haptics are given — say nothing about the traversal, so writing one must
    /// leave the running session alone. Re-pinning from the saved default would
    /// silently reverse a walk the user began with an explicit "Newest first" or
    /// "Oldest first", and save that reversal.
    func updatePreferences(_ preferences: ControlPreferences) {
        let directionChanged = preferences.defaultDirection != self.preferences.defaultDirection
        self.preferences = preferences
        store.savePreferences(preferences)
        guard directionChanged, var engine else { return }
        engine.setDirection(preferences.defaultDirection)
        self.engine = engine
        storedState.session = engine.persisted()
        Task { await self.persistQuietly(self.storedState) }
    }

    /// Moves the dock to `position`, where it is dragged to or stepped to from
    /// Settings.
    ///
    /// A position the dock already occupies is not a move: nothing is written at
    /// all, so a drag that ends where it started cannot disturb the saved
    /// session.
    func moveDock(to position: ControlPosition) {
        guard position != preferences.position else { return }
        var preferences = self.preferences
        preferences.position = position
        updatePreferences(preferences)
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
                persistenceNotice = "SWIPR deleted the confirmed photos but could not save the updated list. \(describe(error))"
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
            errorMessage = "SWIPR could not delete those photos: \(error.localizedDescription)"
        }
    }

    func dismissResult() {
        continueAfterResult()
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
