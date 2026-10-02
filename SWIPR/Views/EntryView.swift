import SWIPRKit
import SwiftUI

/// The first screen: one obvious action, and nothing else competing with it.
///
/// The wordmark, a single circular action and a `Resume` link when a session is
/// waiting. The tutorial teaches the gestures, so there is no footer here; the
/// deletion-review chip only appears while photos are marked.
struct EntryView: View {
    @EnvironmentObject private var model: AppModel

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
            VStack(spacing: 26) {
                Text("SWIPR")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("entry.wordmark")

                startAction

                if model.hasPhotos, model.resumableSession != nil {
                    Button {
                        model.resumeSession()
                    } label: {
                        Text("Resume")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityIdentifier("entry.resume")
                }

                if !model.hasPhotos {
                    Text("No photos to sort.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .accessibilityIdentifier("entry.empty")
                }

                if model.hasPhotos, model.authorization.isLimited {
                    Button {
                        model.manageLimitedLibrary()
                    } label: {
                        Text("Select more photos")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityIdentifier("entry.selectMorePhotos")
                }
            }
            Spacer(minLength: 16)
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
        .foregroundStyle(.white)
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
                .background(.ultraThinMaterial, in: Capsule())
                .foregroundStyle(.white)
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
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
                    .background(enabled ? Color.white : Color.white.opacity(0.12), in: Circle())
                    .foregroundStyle(enabled ? Color.black : Color.white.opacity(0.4))
                    .overlay(Circle().stroke(Color.white.opacity(enabled ? 0 : 0.15), lineWidth: 1))
                    .contentShape(Circle())
            }
            .disabled(!enabled)
            .accessibilityLabel("Start here")
            .accessibilityIdentifier("entry.start")

            Text("Start here")
                .font(.body)
                .foregroundStyle(enabled ? .white : .white.opacity(0.4))
                .accessibilityHidden(true)
        }
    }
}
