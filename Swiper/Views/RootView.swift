import SwiperKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .animation(.easeInOut(duration: 0.2), value: model.route)
        .task { await model.bootstrap() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refreshAuthorization() }
            } else {
                model.flushSessionWrites()
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.route {
        case .loading:
            ProgressView().tint(.white)
        case .permission:
            PermissionView()
        case .entry:
            EntryView()
        case .viewer:
            ViewerView()
        case .review:
            DeletionReviewView()
        case .result:
            SessionResultView(outcome: model.lastDeletion)
        case .statistics:
            StatisticsView()
        case .settings:
            SettingsView()
        case .startHere:
            StartHereGridView()
        }
    }
}
