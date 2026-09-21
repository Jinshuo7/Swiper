import Photos
import PhotosUI
import SwiperKit
import SwiftUI

struct ViewerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var dragOffset: CGSize = .zero
    @State private var cachedIDs: [String] = []

    private var preset: ControlPreset { model.preferences.preset }
    private var placement: ControlPlacement { model.preferences.placement }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if let asset = model.engine?.current {
                    AssetCanvas(asset: asset, targetSize: canvasSize(in: geometry), dragOffset: dragOffset)
                        .frame(
                            width: fittedSize(for: asset, in: geometry).width,
                            height: fittedSize(for: asset, in: geometry).height
                        )
                        .id(asset.id)
                        .gesture(swipeGesture, including: preset.usesSwipeGestures ? .all : .none)
                        .onTapGesture {
                            if preset == .deleteOnly { model.apply(.keep) }
                        }
                        .allowsHitTesting(!model.isDecisionInputBlocked)
                        .accessibilityIdentifier("viewer.photo")
                        .accessibilityLabel(accessibilityDescription(for: asset))
                } else if model.engine?.isFinished == true {
                    finishedOverlay
                } else {
                    missingState
                }
            }
            .overlay(alignment: .top) { topBar }
            .overlay(alignment: bottomAlignment) { controlCluster }
            .overlay(alignment: .bottom) { reviewBar }
        }
        .task(id: currentID) { updatePrefetch() }
        .onDisappear { clearPrefetch() }
    }

    private var currentID: String? { model.engine?.current?.id }

    /// A spoken description of the current asset. VoiceOver users hear what the
    /// photo is and whether it is already marked, instead of an unlabelled
    /// image.
    private func accessibilityDescription(for asset: AssetDescriptor) -> String {
        var parts = [asset.isLivePhoto ? "Live Photo" : "Photo"]
        if let date = asset.creationDate {
            parts.append(date.formatted(date: .abbreviated, time: .shortened))
        }
        if model.marks.contains(asset.id) {
            parts.append("marked for deletion")
        }
        return parts.joined(separator: ", ")
    }

    /// The full screen, including the safe-area bars the photo may extend under.
    /// The overlays stay inside `geometry` (the safe area) so controls are
    /// always reachable.
    private func canvasSize(in geometry: GeometryProxy) -> CGSize {
        CGSize(
            width: geometry.size.width + geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing,
            height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
        )
    }

    private func fittedSize(for asset: AssetDescriptor, in geometry: GeometryProxy) -> CGSize {
        PhotoLayout.fittedSize(
            forPixelSize: CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
            in: canvasSize(in: geometry)
        )
    }

    private var bottomAlignment: Alignment {
        switch placement {
        case .left: return .bottomLeading
        case .center: return .bottom
        case .right: return .bottomTrailing
        }
    }

    // MARK: - Gestures

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let translation = value.translation
                let threshold: CGFloat = 80
                if abs(translation.width) > abs(translation.height) {
                    if translation.width < -threshold {
                        model.apply(.queueDeletion)
                    } else if translation.width > threshold {
                        model.apply(.keep)
                    }
                }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    dragOffset = .zero
                }
            }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack(spacing: 10) {
            TopBarButton(systemImage: "xmark", label: "Close") {
                model.route = .entry
            }
            Spacer()
            if preset != .extended {
                TopBarButton(systemImage: "heart", label: "Favorite") {
                    model.apply(.favorite)
                }
                .disabled(model.isDecisionInputBlocked)
                TopBarButton(systemImage: "arrow.uturn.backward", label: "Undo") {
                    model.apply(.undo)
                }
                .disabled(model.isDecisionInputBlocked)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var controlCluster: some View {
        ControlCluster()
            .disabled(model.isDecisionInputBlocked)
            .padding(.bottom, model.queueCount > 0 ? 54 : 20)
            .padding(placement == .center ? 0 : 20)
    }

    /// A compact, always-reachable way into deletion review. It states the
    /// agreed wording — photos are *marked*, nothing is deleted yet — and sits
    /// at the bottom edge, inside the safe area, so it never covers the photo
    /// centre.
    private var reviewBar: some View {
        Group {
            if model.queueCount > 0 {
                Button {
                    model.goToReview(from: .viewer)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text(DeletionWording.reviewCompact(model.queueCount))
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.white)
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
                .accessibilityLabel(DeletionWording.markedForDeletion(model.queueCount))
                .accessibilityValue(DeletionWording.nothingDeletedYet)
                .accessibilityIdentifier("viewer.review")
            }
        }
        .padding(.bottom, 10)
    }

    private var finishedOverlay: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.white)
            Text("You've reviewed everything")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if model.queueCount > 0 {
                Button {
                    model.goToReview(from: .viewer)
                } label: {
                    Label("Review \(model.queueCount) for deletion", systemImage: "trash")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)
                .accessibilityIdentifier("viewer.reviewFinished")
            }

            if model.queueCount == 0 {
                Button {
                    model.finishSession()
                } label: {
                    Text("Finish")
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal, 40)
                .accessibilityIdentifier("viewer.finish")
            }
        }
        .padding()
    }

    private var missingState: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.6))
            Text("No photo to show")
                .foregroundStyle(.white.opacity(0.7))
            Button("Back") { model.route = .entry }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal, 60)
        }
    }

    // MARK: - Prefetch

    private func updatePrefetch() {
        guard let engine = model.engine, engine.current != nil else {
            clearPrefetch()
            return
        }
        let nextIDs = engine.upcomingIDs(limit: 2)
        if nextIDs != cachedIDs {
            if !cachedIDs.isEmpty {
                model.library.stopCaching(ids: cachedIDs, targetSize: CGSize(width: 1_200, height: 1_200))
            }
            if !nextIDs.isEmpty {
                model.library.startCaching(ids: nextIDs, targetSize: CGSize(width: 1_200, height: 1_200))
            }
            cachedIDs = nextIDs
        }
    }

    private func clearPrefetch() {
        guard !cachedIDs.isEmpty else { return }
        model.library.stopCaching(ids: cachedIDs, targetSize: CGSize(width: 1_200, height: 1_200))
        cachedIDs = []
    }
}

/// Loads and displays one asset, cancelling the previous request when the
/// current asset changes.
private struct AssetCanvas: View {
    @EnvironmentObject private var model: AppModel
    let asset: AssetDescriptor
    let targetSize: CGSize
    let dragOffset: CGSize

    @State private var image: UIImage?
    @State private var livePhoto: PHLivePhoto?

    var body: some View {
        Group {
            if asset.isLivePhoto, let livePhoto {
                LivePhotoView(livePhoto: livePhoto)
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .offset(dragOffset)
        .task(id: asset.id) {
            image = nil
            livePhoto = nil
            if asset.isLivePhoto {
                livePhoto = await model.library.livePhoto(for: asset.id, targetSize: targetSize)
            }
            if livePhoto == nil {
                image = await model.library.displayImage(for: asset.id, targetSize: targetSize)
            }
        }
    }
}

/// A `PHLivePhotoView` so Live Photos keep their motion and play on long press.
struct LivePhotoView: UIViewRepresentable {
    let livePhoto: PHLivePhoto

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.livePhoto = livePhoto
        return view
    }

    func updateUIView(_ view: PHLivePhotoView, context: Context) {
        if view.livePhoto !== livePhoto {
            view.livePhoto = livePhoto
        }
    }
}

/// The floating control cluster, varying by preset and placement.
private struct ControlCluster: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let preset = model.preferences.preset
        HStack(spacing: 18) {
            if preset.showsDeleteButton {
                CircleControl(systemImage: "trash", label: "Delete", tint: .red) {
                    model.apply(.queueDeletion)
                }
            }
            if preset.showsKeepButton {
                CircleControl(systemImage: "checkmark", label: "Keep", tint: .green) {
                    model.apply(.keep)
                }
            }
            if preset.showsFavoriteButton {
                CircleControl(systemImage: "heart", label: "Favorite", tint: .pink) {
                    model.apply(.favorite)
                }
            }
            if preset.showsUndoButton {
                CircleControl(systemImage: "arrow.uturn.backward", label: "Undo") {
                    model.apply(.undo)
                }
            }
        }
    }
}
