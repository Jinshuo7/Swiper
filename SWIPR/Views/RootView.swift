import SWIPRKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var systemColorScheme

    /// Screenshot/test seam. The app follows the iPhone's appearance by
    /// default, so a UI test can ask the Home and filter screens to render in a
    /// chosen appearance. The later appearance ticket adds the System / Light /
    /// Dark setting.
    private var forcedColorScheme: ColorScheme? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestingForceLight") { return .light }
        if arguments.contains("-uiTestingForceDark") { return .dark }
        return nil
    }

    private var effectiveColorScheme: ColorScheme { forcedColorScheme ?? systemColorScheme }

    /// The status bar follows the screen that is actually on top: the porcelain
    /// Home and filters use the appearance they render in — the iPhone's by
    /// default, and only the screenshot seam overrides it — while every other
    /// screen keeps its dark viewer chrome, whose status bar stays light.
    private var statusBarScheme: ColorScheme? {
        switch model.route {
        case .entry, .filters:
            return forcedColorScheme
        default:
            return .dark
        }
    }

    var body: some View {
        ZStack {
            background
            content
            persistenceLayer
            if model.isShowingTutorial {
                TutorialView {
                    model.dismissTutorial()
                }
                .transition(.opacity)
            }
        }
        .environment(\.colorScheme, effectiveColorScheme)
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
        .preferredColorScheme(statusBarScheme)
    }

    /// The porcelain Home and filter screens sit on a cream/near-black ground;
    /// every other screen keeps the dark viewer chrome it was built for.
    private var background: some View {
        Group {
            switch model.route {
            case .entry, .filters:
                PorcelainPalette.forScheme(effectiveColorScheme).background.ignoresSafeArea()
            default:
                Color.black.ignoresSafeArea()
            }
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
        case .settings:
            SettingsView()
        case .filters:
            FilterView()
        case .choosePhoto:
            ChoosePhotoView()
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
                    title: "SWIPR",
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
