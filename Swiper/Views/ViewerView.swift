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
                    AssetCanvas(asset: asset, targetSize: geometry.size, dragOffset: dragOffset)
                        .id(asset.id)
                        .gesture(swipeGesture, including: preset.usesSwipeGestures ? .all : .none)
                        .onTapGesture {
                            if preset == .deleteOnly { model.apply(.keep) }
                        }
                        .accessibilityIdentifier("viewer.photo")
                } else if model.engine?.isFinished == true {
                    finishedOverlay
                } else {
                    missingState
                }
            }
            .overlay(alignment: .top) { topBar }
            .overlay(alignment: bottomAlignment) { controlCluster }
            .overlay(alignment: .bottom) { swipeHint }
        }
        .task(id: currentID) { updatePrefetch() }
        .onDisappear { clearPrefetch() }
    }

    private var currentID: String? { model.engine?.current?.id }

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
                TopBarButton(systemImage: "arrow.uturn.backward", label: "Undo") {
                    model.apply(.undo)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var controlCluster: some View {
        ControlCluster()
            .padding(.bottom, 28)
            .padding(placement == .center ? 0 : 20)
    }

    private var swipeHint: some View {
        Group {
            if preset.usesSwipeGestures && model.engine?.current != nil {
                Text("◀ Queue deletion     Keep ▶     Tap ♡ to favorite")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.bottom, 8)
            }
        }
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
                    model.goToReview()
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
                    .scaledToFill()
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea()
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
        view.contentMode = .scaleAspectFill
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
