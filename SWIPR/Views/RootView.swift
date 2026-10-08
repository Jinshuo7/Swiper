import SWIPRKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var systemColorScheme

    /// Screenshot/test seam. The app is currently pinned to dark while the
    /// viewer work lands, so a UI test can ask the Home and filter screens to
    /// render in the other appearance without changing the shipped default.
    /// The later appearance ticket replaces this with the System / Light / Dark
    /// setting.
    private var forcedColorScheme: ColorScheme? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestingForceLight") { return .light }
        if arguments.contains("-uiTestingForceDark") { return .dark }
        return nil
    }

    private var effectiveColorScheme: ColorScheme { forcedColorScheme ?? systemColorScheme }

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
            } else if let limited = model.limitedMarksNotice, model.persistenceNotice == limited {
                // Marks kept while Photos access is Limited. Explain, and offer
                // the system picker right where the user notices the gap.
                PersistenceBanner(
                    systemImage: "info.circle",
                    title: model.hiddenMarkCount == 1
                        ? "One marked photo is hidden"
                        : "Some marked photos are hidden",
                    message: limited,
                    primaryTitle: "Select more photos",
                    primaryAction: { model.manageLimitedLibrary() },
                    secondaryTitle: "Not now",
                    secondaryAction: { model.dismissPersistenceNotice() }
                )
                .accessibilityIdentifier("persistence.limitedMarks")
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
