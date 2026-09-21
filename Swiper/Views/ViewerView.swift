import Photos
import PhotosUI
import SwiperKit
import SwiftUI
import UIKit

struct ViewerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGSize = .zero
    @State private var cachedIDs: [String] = []
    @State private var haptics = UIImpactFeedbackGenerator(style: .light)

    /// How far the photo has to travel horizontally before releasing decides.
    private let commitThreshold: CGFloat = 90

    private var preset: ControlPreset { model.preferences.preset }

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
                        .offset(x: photoLaneOffset)
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
            // Pinned to the screen. Without this the ZStack sizes itself to the
            // photo, so the chrome would drift with each asset's aspect ratio and
            // a tall photo could push the controls out of reach.
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay { dragFeedback }
            .overlay(alignment: .top) { topBar }
            .overlay(alignment: railAlignment) { controlRail }
        }
        .task(id: currentID) {
            updatePrefetch()
            model.presentTutorialIfNeeded()
        }
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
        let full = CGSize(
            width: geometry.size.width + geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing,
            height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
        )
        return CGSize(width: max(1, full.width - railLaneWidth), height: full.height)
    }

    /// Width reserved for a vertical rail, so the photo is fitted *beside* it
    /// rather than running underneath the controls. A control sitting on a busy
    /// photo is the "half-buried" feel this design exists to remove.
    private var railLaneWidth: CGFloat { model.preferences.rail.isVertical ? 88 : 0 }

    /// How far the photo shifts to stay centred in the area the rail leaves free.
    private var photoLaneOffset: CGFloat {
        switch model.preferences.rail {
        case .bottom: return 0
        case .leading: return railLaneWidth / 2
        case .trailing: return -railLaneWidth / 2
        }
    }

    private func fittedSize(for asset: AssetDescriptor, in geometry: GeometryProxy) -> CGSize {
        PhotoLayout.fittedSize(
            forPixelSize: CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
            in: canvasSize(in: geometry)
        )
    }

    /// Where the rail is anchored. Only the rail's own edge and anchor decide
    /// this, so nothing about the current photo or the number of marks can move
    /// a control.
    private var railAlignment: Alignment {
        switch (model.preferences.rail, model.preferences.anchor) {
        case (.bottom, .start): return .bottomLeading
        case (.bottom, .center): return .bottom
        case (.bottom, .end): return .bottomTrailing
        case (.leading, .start): return .topLeading
        case (.leading, .center): return .leading
        case (.leading, .end): return .bottomLeading
        case (.trailing, .start): return .topTrailing
        case (.trailing, .center): return .trailing
        case (.trailing, .end): return .bottomTrailing
        }
    }

    // MARK: - Gestures

    /// How far the current drag has travelled toward committing, 0…1. Only
    /// horizontal movement counts, so a vertical drag never arms a decision.
    private var dragProgress: CGFloat {
        guard isHorizontalDrag else { return 0 }
        return min(1, abs(dragOffset.width) / commitThreshold)
    }

    private var isHorizontalDrag: Bool { abs(dragOffset.width) > abs(dragOffset.height) }

    private var isPastThreshold: Bool {
        isHorizontalDrag && abs(dragOffset.width) >= commitThreshold
    }

    /// Which way the drag currently leans, or `nil` when it is not horizontal.
    private var dragDirection: SessionAction? {
        guard isHorizontalDrag, abs(dragOffset.width) > 4 else { return nil }
        return dragOffset.width < 0 ? .queueDeletion : .keep
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let wasPastThreshold = isPastThreshold
                dragOffset = value.translation
                let nowPastThreshold = isPastThreshold
                if nowPastThreshold && !wasPastThreshold {
                    haptics.impactOccurred()
                }
            }
            .onEnded { value in
                let translation = value.translation
                let isHorizontal = abs(translation.width) > abs(translation.height)
                let committed: SessionAction?
                if isHorizontal, abs(translation.width) >= commitThreshold {
                    committed = translation.width < 0 ? .queueDeletion : .keep
                } else {
                    // A short, vertical or cancelled drag decides nothing.
                    committed = nil
                }

                if reduceMotion {
                    dragOffset = .zero
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        dragOffset = .zero
                    }
                }
                if let committed {
                    haptics.prepare()
                    model.apply(committed)
                }
            }
    }

    // MARK: - Drag feedback

    /// Feedback only: the corner wells are revealed by the drag and are not
    /// separate tap targets, so nobody has to swipe. Button presets remain the
    /// alternative for anyone who cannot or does not want to gesture.
    @ViewBuilder
    private var dragFeedback: some View {
        if let direction = dragDirection {
            let progress = dragProgress
            let armed = isPastThreshold

            ZStack {
                // Confined to the edge the drag is heading for and never very
                // strong: the photo stays readable, and the wells — not the wash
                // — carry the meaning.
                LinearGradient(
                    stops: [
                        .init(color: outcomeTint(direction).opacity(0.20 * progress), location: 0),
                        .init(color: .clear, location: 0.38),
                    ],
                    startPoint: direction == .queueDeletion ? .leading : .trailing,
                    endPoint: direction == .queueDeletion ? .trailing : .leading
                )
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    HStack {
                        if direction == .queueDeletion {
                            outcomeWell(
                                systemImage: "trash.fill",
                                title: "Mark for deletion",
                                tint: outcomeTint(direction),
                                armed: armed,
                                progress: progress
                            )
                        }
                        Spacer(minLength: 0)
                        if direction == .keep {
                            outcomeWell(
                                systemImage: "checkmark",
                                title: "Keep",
                                tint: outcomeTint(direction),
                                armed: armed,
                                progress: progress
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 104)
                }
            }
            // Feedback must never swallow the drag it is describing.
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func outcomeTint(_ direction: SessionAction) -> Color {
        direction == .queueDeletion ? .red : .green
    }

    private func outcomeWell(
        systemImage: String,
        title: String,
        tint: Color,
        armed: Bool,
        progress: CGFloat
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3.weight(.bold))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(WellBackground(tint: tint, armed: armed))
        .scaleEffect(reduceMotion ? 1 : (armed ? 1.06 : 0.94 + 0.06 * progress))
        .opacity(0.3 + 0.7 * progress)
    }

    // MARK: - Chrome

    /// Informational chrome only: what this asset is, and the way into review.
    /// Neither can displace the rail, because the rail is anchored independently
    /// of the top strip.
    private var topBar: some View {
        HStack(spacing: 10) {
            if model.currentAsset?.isLivePhoto == true {
                livePhotoBadge
            }
            Spacer()
            reviewControl
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    /// Says plainly that this asset has motion, so nobody has to guess why a
    /// press-and-hold behaves differently. Symbol *and* the word "LIVE", so the
    /// meaning never rests on the symbol alone.
    private var livePhotoBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "livephoto")
                .font(.caption2.weight(.bold))
            Text("LIVE")
                .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .foregroundStyle(.white)
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
        // One element, not a container plus inherited children, so a UI test
        // query for the identifier matches exactly once.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live Photo")
        .accessibilityHint("Press and hold the photo to play its motion")
        .accessibilityIdentifier("viewer.liveBadge")
    }

    /// A compact, always-reachable way into deletion review. It states the
    /// agreed wording — photos are *marked*, nothing has been deleted.
    @ViewBuilder
    private var reviewControl: some View {
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

    /// The one place the controls live. They never move: not between photos of
    /// different shapes, not when a mark appears, not between presets — only
    /// when the user chooses a different rail.
    ///
    /// Order is fixed and runs from the least to the most thumb-accessible:
    /// Close first, then Favorite and Undo, then the decision pair with Keep
    /// last, so on a side rail Close sits at the top and Keep at the bottom.
    private var controlRail: some View {
        Group {
            if model.preferences.rail.isVertical {
                VStack(spacing: 14) { railControls }
            } else {
                HStack(spacing: 14) { railControls }
            }
        }
        .disabled(model.isDecisionInputBlocked)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private var railControls: some View {
        if model.preferences.order == .keepFirst {
            keepControl
            deleteControl
            undoControl
            favoriteControl
            closeControl
        } else {
            closeControl
            favoriteControl
            undoControl
            deleteControl
            keepControl
        }
    }

    private var closeControl: some View {
        CircleControl(systemImage: "xmark", label: "Close") {
            model.closeViewer()
        }
    }

    private var favoriteControl: some View {
        CircleControl(systemImage: "heart", label: "Favorite") {
            model.apply(.favorite)
        }
    }

    private var undoControl: some View {
        CircleControl(systemImage: "arrow.uturn.backward", label: "Undo") {
            model.apply(.undo)
        }
    }

    @ViewBuilder
    private var deleteControl: some View {
        if preset.showsDeleteButton {
            CircleControl(systemImage: "trash", label: "Delete", tint: .red) {
                model.apply(.queueDeletion)
            }
        }
    }

    @ViewBuilder
    private var keepControl: some View {
        if preset.showsKeepButton {
            CircleControl(systemImage: "checkmark", label: "Keep", tint: .green) {
                model.apply(.keep)
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
