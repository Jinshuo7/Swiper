import SwiperKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
            persistenceLayer
            if model.isShowingTutorial {
                TutorialView(preset: model.preferences.preset) {
                    model.dismissTutorial()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.route)
        .task { await model.bootstrap() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refreshAuthorization() }
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

    /// Anything the user must know about saved state, placed above the current
    /// screen so a failed write can never look like a successful one.
    @ViewBuilder
    private var persistenceLayer: some View {
        VStack(spacing: 0) {
            if let pending = model.pendingDecision {
                PersistenceBanner(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't save your last decision",
                    message: pending.message,
                    primaryTitle: "Retry",
                    primaryAction: { Task { await model.retryPendingDecision() } },
                    secondaryTitle: "Discard",
                    secondaryAction: { model.discardPendingDecision() }
                )
                .accessibilityIdentifier("saveFailure.banner")
            } else if model.isPersistenceReadOnly, let notice = model.persistenceNotice {
                PersistenceBanner(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Saved progress can't be read",
                    message: notice,
                    primaryTitle: "Start fresh",
                    primaryAction: { Task { await model.recoverFromUnreadableState() } }
                )
                .accessibilityIdentifier("persistence.readOnly")
            } else if let notice = model.persistenceNotice {
                PersistenceBanner(
                    systemImage: "info.circle",
                    title: "Swiper",
                    message: notice,
                    primaryTitle: "OK",
                    primaryAction: { model.dismissPersistenceNotice() }
                )
                .accessibilityIdentifier("persistence.notice")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
