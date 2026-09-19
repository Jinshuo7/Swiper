import SwiperKit
import SwiftUI

@main
struct SwiperApp: App {
    @StateObject private var model: AppModel

    init() {
        let useFakeLibrary = ProcessInfo.processInfo.arguments.contains("-uiTestingFakeLibrary")
        let library: SwiperPhotoLibrary
        let store: SessionStoring
        if useFakeLibrary {
            library = FakePhotoLibrary.demo()
            store = InMemorySessionStore()
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
}
