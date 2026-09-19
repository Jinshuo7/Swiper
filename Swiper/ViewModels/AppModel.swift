import Photos
import SwiperKit
import UIKit

/// Owns the whole app state machine: permissions, the library snapshot, the
/// current session, statistics and preferences.
///
/// The model performs the ``SessionEffect`` values the pure engine emits; the
/// engine never touches PhotoKit itself.
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

    @Published var route: Route = .loading
    @Published private(set) var authorization: LibraryAuthorization = .notDetermined
    @Published private(set) var order: LibraryOrder = .empty
    @Published private(set) var engine: SessionEngine?
    @Published private(set) var preferences: ControlPreferences
    @Published private(set) var statistics: SessionStatistics
    @Published private(set) var resumableSession: PersistedSession?
    @Published private(set) var lastDeletion: DeletionOutcome = .empty
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    let library: SwiperPhotoLibrary
    private let store: SessionStoring
    private var didBootstrap = false
    /// Serialises favorite changes so a favorite immediately followed by an
    /// undo cannot apply out of order.
    private var favoriteTask: Task<Void, Never>?

    init(library: SwiperPhotoLibrary, store: SessionStoring) {
        self.library = library
        self.store = store
        self.preferences = store.loadPreferences()
        self.statistics = store.loadStatistics()
        self.library.changeHandler = { [weak self] in
            Task { @MainActor in
                await self?.reloadLibrary()
            }
        }
    }

    var currentAsset: AssetDescriptor? { engine?.current }
    var queueCount: Int { engine?.queue.count ?? 0 }
    var hasPhotos: Bool { !order.isEmpty }

    // MARK: - Lifecycle

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        await refreshAuthorization()
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

    /// Refreshes the metadata snapshot and reconciles any unfinished session.
    func reloadLibrary() async {
        let descriptors = await library.fetchAllDescriptors()
        order = LibraryOrder(descriptors)
        if let engine {
            let session = reconcile(engine.persisted(), restoreEngine: true)
            if session.isFinished && route == .viewer {
                route = .review
            }
        } else {
            reconcilePersistedSession()
        }
    }

    private func reconcilePersistedSession() {
        guard let persisted = store.loadSession(), persisted.isResumable else {
            resumableSession = nil
            return
        }
        _ = reconcile(persisted, restoreEngine: false)
    }

    @discardableResult
    private func reconcile(_ persisted: PersistedSession, restoreEngine: Bool) -> PersistedSession {
        let session = AssetReconciler.reconcile(persisted, order: order).session
        if restoreEngine {
            engine = SessionEngine.restored(from: session, order: order)
        }
        if session.isResumable {
            store.saveSession(session)
            resumableSession = session
        } else {
            store.clearSession()
            resumableSession = nil
        }
        return session
    }

    // MARK: - Entry points

    func startRecent() { startSession(mode: .sequential, cursorID: nil, direction: .older) }

    func startTumbler() { startSession(mode: .tumbler, cursorID: nil) }

    func startHere(assetID: String) {
        startSession(mode: .sequential, cursorID: assetID)
    }

    func showStartHere() { route = .startHere }

    private func startSession(
        mode: SessionMode,
        cursorID: String?,
        direction: TraversalDirection? = nil
    ) {
        guard hasPhotos else {
            errorMessage = "There are no photos or Live Photos to review."
            return
        }
        store.clearSession()
        resumableSession = nil
        statistics.beginSession()
        store.saveStatistics(statistics)

        var engine = SessionEngine(
            order: order,
            direction: direction ?? preferences.defaultDirection,
            mode: mode,
            cursorID: cursorID,
            tumblerSeed: mode == .tumbler ? SessionEngine.makeSeed() : nil
        )
        if cursorID == nil || mode == .tumbler {
            engine.start()
        }
        self.engine = engine
        persistSession()
        route = .viewer
    }

    func resumeSession() {
        guard let persisted = resumableSession else { return }
        let engine = SessionEngine.restored(from: persisted, order: order)
        self.engine = engine
        route = engine.isFinished ? .review : .viewer
    }

    // MARK: - Decisions

    func apply(_ action: SessionAction) {
        if action == .favorite {
            applyFavorite()
            return
        }
        guard favoriteTask == nil else { return }
        guard var engine else { return }
        let effects = engine.apply(action)
        self.engine = engine
        perform(effects)
        persistSession()
    }

    func undo() { apply(.undo) }

    func goToReview() { route = .review }

    func finishSession() {
        statistics.completeSession()
        store.saveStatistics(statistics)
        engine = nil
        resumableSession = nil
        store.clearSession()
        route = .entry
    }

    func restore(ids: [String]) {
        guard var engine else { return }
        engine.restore(ids: ids)
        self.engine = engine
        persistSession()
    }

    func updatePreferences(_ preferences: ControlPreferences) {
        self.preferences = preferences
        store.savePreferences(preferences)
        if var engine {
            engine.setDirection(preferences.defaultDirection)
            self.engine = engine
            persistSession()
        }
    }

    // MARK: - Deletion

    func confirmDeletion() async {
        guard let engine, !engine.queue.isEmpty else { return }
        isBusy = true
        defer { isBusy = false }

        let requested = engine.queue.ids
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

            var updated = engine
            updated.commitDeletion(outcome: outcome)
            order = LibraryOrder(await library.fetchAllDescriptors())
            let session = reconcile(updated.persisted(), restoreEngine: true)

            if session.isFinished && session.queueIDs.isEmpty {
                statistics.completeSession()
                self.engine = nil
                store.clearSession()
                resumableSession = nil
            }

            statistics.record(outcome)
            store.saveStatistics(statistics)
            lastDeletion = outcome
            route = .result
        } catch {
            errorMessage = "Swiper could not delete those photos: \(error.localizedDescription)"
        }
    }

    func dismissResult() {
        route = .entry
    }

    // MARK: - Effect handling

    private func applyFavorite() {
        guard favoriteTask == nil, let assetID = engine?.current?.id else { return }
        favoriteTask = Task {
            do {
                try await library.setFavorite(true, forID: assetID)
                guard var engine, engine.current?.id == assetID else {
                    favoriteTask = nil
                    return
                }
                let effects = engine.apply(.favorite).filter {
                    if case .setFavorite = $0 { return false }
                    return true
                }
                self.engine = engine
                perform(effects)
                persistSession()
            } catch {
                errorMessage = "Couldn't update the favorite: \(error.localizedDescription)"
            }
            favoriteTask = nil
        }
    }

    private func perform(_ effects: [SessionEffect]) {
        for effect in effects {
            switch effect {
            case .setFavorite(let id, let isFavorite):
                favoriteTask = Task {
                    do {
                        try await library.setFavorite(isFavorite, forID: id)
                    } catch {
                        self.errorMessage = "Couldn't update the favorite: \(error.localizedDescription)"
                    }
                    self.favoriteTask = nil
                }
            case .queuedDeletion, .unqueuedDeletion, .advanced, .undoApplied, .sessionFinished, .noOp:
                break
            }
        }
    }

    private func persistSession() {
        guard let engine else { return }
        let persisted = engine.persisted()
        store.saveSession(persisted)
        resumableSession = persisted.isResumable ? persisted : nil
    }

    func flushSessionWrites() {
        store.flushSessionWrites()
    }
}
