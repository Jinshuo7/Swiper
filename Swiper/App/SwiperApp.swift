import SwiperKit
import SwiftUI

@main
struct SwiperApp: App {
    @StateObject private var model: AppModel

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let useFakeLibrary = arguments.contains("-uiTestingFakeLibrary")
        let library: SwiperPhotoLibrary
        let store: SessionStoring
        if useFakeLibrary {
            let fakeLibrary = FakePhotoLibrary.demo()
            if arguments.contains("-uiTestingFailDeletion") {
                // The system confirmation is cancelled: every requested asset is
                // submitted but stays in the library.
                fakeLibrary.faults.failedDeleteIDs = Set(FakePhotoLibrary.demoDescriptors().map(\.id))
            }
            library = fakeLibrary
            store = SwiperApp.makeUITestingStore(arguments: arguments)
        } else {
            library = PhotoKitLibrary()
            store = FileSessionStore()
        }
        _model = StateObject(wrappedValue: AppModel(library: library, store: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }

    /// Store wiring for UI tests. Every option here is only reachable together
    /// with `-uiTestingFakeLibrary`, so a test run can never touch a real
    /// library.
    private static func makeUITestingStore(arguments: [String]) -> SessionStoring {
        if arguments.contains("-uiTestingUnreadableState") {
            return InMemorySessionStore(content: .unreadable)
        }
        if arguments.contains("-uiTestingFutureVersionState") {
            return InMemorySessionStore(content: .unsupportedVersion(found: PersistedState.currentSchemaVersion + 1))
        }

        let directory = FileSessionStore.defaultDirectory
            .appendingPathComponent("UITesting", isDirectory: true)
        if arguments.contains("-uiTestingResetStore") {
            try? FileManager.default.removeItem(at: directory)
        }

        // Restart tests need state that survives relaunching the app.
        guard arguments.contains("-uiTestingPersistentStore") else {
            let store = InMemorySessionStore()
            store.failsWrites = arguments.contains("-uiTestingFailSaves")
            return store
        }

        let store = FileSessionStore(directory: directory)
        if arguments.contains("-uiTestingFailSaves") {
            return FailingSessionStore(wrapping: store)
        }
        return store
    }
}

/// Wraps a real store and refuses every write, so the visible save-failure path
/// can be exercised for real.
private final class FailingSessionStore: SessionStoring {
    private let wrapped: SessionStoring

    init(wrapping wrapped: SessionStoring) {
        self.wrapped = wrapped
    }

    func loadState() -> SessionLoadResult { wrapped.loadState() }

    func saveState(_ state: PersistedState) async throws {
        throw SessionStoreError.writeFailed("Swiper is simulating a full disk.")
    }

    func clearState() async throws {
        throw SessionStoreError.writeFailed("Swiper is simulating a full disk.")
    }

    func quarantineUnreadableState() throws -> URL? { try wrapped.quarantineUnreadableState() }
    func loadStatistics() -> SessionStatistics { wrapped.loadStatistics() }
    func saveStatistics(_ statistics: SessionStatistics) { wrapped.saveStatistics(statistics) }
    func loadPreferences() -> ControlPreferences { wrapped.loadPreferences() }
    func savePreferences(_ preferences: ControlPreferences) { wrapped.savePreferences(preferences) }
}
