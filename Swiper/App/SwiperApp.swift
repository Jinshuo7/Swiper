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

        // The session-start write is attempt 1, so attempt 2 is the first user
        // decision: the run sees a real failure followed by a real retry.
        if arguments.contains("-uiTestingFailFirstDecisionSave") {
            let store = InMemorySessionStore()
            store.failSaveAttempt = 2
            return store
        }

        // Restart tests need state that survives relaunching the app.
        guard arguments.contains("-uiTestingPersistentStore") else {
            return InMemorySessionStore()
        }
        return FileSessionStore(directory: directory)
    }
}
