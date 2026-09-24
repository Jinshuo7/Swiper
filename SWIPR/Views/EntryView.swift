import SWIPRKit
import SwiftUI

/// The first screen: one obvious action, and nothing else competing with it.
///
/// The wordmark, a single circular action and a `Resume` link when a session is
/// waiting. The tutorial teaches the gestures, so there is no footer here; the
/// deletion-review chip only appears while photos are marked.
struct EntryView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var logoSettled = false

    var body: some View {
        // Exactly one screen tall at normal sizes. When the largest
        // accessibility text needs more room the same content scrolls instead of
        // pushing the one action off the screen.
        GeometryReader { geometry in
            ScrollView {
                content.frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 16)
            VStack(spacing: 22) {
                VStack(spacing: 14) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(Color.swiprAccent.gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .rotationEffect(.degrees(logoSettled ? 0 : -7))
                        .scaleEffect(logoSettled ? 1 : 0.92)
                        .accessibilityHidden(true)

                    Text("SWIPR")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .tracking(2.5)
                        .foregroundStyle(Color.swiprForeground)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("entry.wordmark")

                    Text("A calmer camera roll.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.swiprSecondary)
                }
                .offset(y: logoSettled ? 0 : 7)

                startAction

                if model.hasPhotos, model.resumableSession != nil {
                    Button {
                        model.resumeSession()
                    } label: {
                        Text("Resume")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.swiprForeground)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityIdentifier("entry.resume")
                }

                if !model.hasPhotos {
                    Text("No photos to sort.")
                        .font(.body)
                        .foregroundStyle(Color.swiprSecondary)
                        .accessibilityIdentifier("entry.empty")
                }

                if model.hasPhotos, model.authorization.isLimited {
                    Button {
                        model.manageLimitedLibrary()
                    } label: {
                        Text("Select more photos")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.swiprSecondary)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityIdentifier("entry.selectMorePhotos")
                }
            }
            Spacer(minLength: 16)
        }
        .onAppear {
            guard !reduceMotion else {
                logoSettled = true
                return
            }
            withAnimation(.spring(duration: 0.55, bounce: 0.16)) {
                logoSettled = true
            }
        }
    }

    /// The gear and the review chip frame the wordmark. They are a row of their
    /// own so a wide count can never sit on the wordmark, and the wordmark below
    /// stays centred on the screen whatever the two ends are doing.
    private var header: some View {
        HStack {
            Button {
                model.route = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("entry.settings")

            Spacer(minLength: 0)

            reviewChip
        }
        .foregroundStyle(Color.swiprForeground)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var reviewChip: some View {
        if model.queueCount > 0 {
            Button {
                model.goToReview(from: .entry)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("Review · \(model.queueCount)")
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.swiprSurface, in: Capsule())
                .foregroundStyle(Color.swiprForeground)
                .overlay(Capsule().stroke(Color.swiprBorder, lineWidth: 1))
            }
            .accessibilityLabel(DeletionWording.markedForDeletion(model.queueCount))
            .accessibilityValue(DeletionWording.nothingDeletedYet)
            .accessibilityIdentifier("entry.review")
        } else {
            Color.clear.frame(width: 44, height: 44)
        }
    }

    /// The one prominent action. With no photos it keeps its shape and label but
    /// goes neutral and disabled, so the empty state is honest rather than
    /// offering something that cannot work.
    private var startAction: some View {
        let enabled = model.hasPhotos
        return VStack(spacing: 12) {
            Button {
                model.showChoosePhoto()
            } label: {
                Image(systemName: "photo.stack")
                    .font(.system(size: 27, weight: .semibold))
                    .frame(width: 68, height: 68)
                    .background(enabled ? Color.swiprAccent : Color.swiprElevated, in: Circle())
                    .foregroundStyle(enabled ? Color.white : Color.swiprTertiary)
                    .overlay(Circle().stroke(Color.swiprBorder.opacity(enabled ? 0 : 1), lineWidth: 1))
                    .contentShape(Circle())
            }
            .disabled(!enabled)
            .accessibilityLabel("Start here")
            .accessibilityIdentifier("entry.start")

            Text("Start here")
                .font(.body)
                .foregroundStyle(enabled ? Color.swiprForeground : Color.swiprTertiary)
                .accessibilityHidden(true)
        }
    }
}
