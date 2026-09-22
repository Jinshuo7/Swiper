import Photos
import PhotosUI
import SWIPRKit
import SwiftUI
import UIKit

struct ViewerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGSize = .zero
    @State private var cachedIDs: [String] = []
    @State private var haptics = UIImpactFeedbackGenerator(style: .light)

    /// Where the move gesture is: idle, lifted and held, or following the finger.
    ///
    /// This is a `@GestureState` on purpose. A gesture state resets itself when
    /// the gesture ends *or is cancelled*, so a drag that is interrupted can
    /// never leave the cluster stuck in the air with its buttons refusing to
    /// work.
    @GestureState private var clusterMove = ClusterMove.idle
    @State private var didSendLiftHaptic = false
    /// Set for a moment after a drop, so the control that was under the finger
    /// cannot deliver its action as the touch ends.
    @State private var isSettlingAfterMove = false
    @State private var moveHaptics = UIImpactFeedbackGenerator(style: .medium)

    private enum ClusterMove: Equatable {
        case idle
        case lifting
        case dragging(CGSize)

        var isActive: Bool { self != .idle }

        var translation: CGSize {
            if case .dragging(let translation) = self { return translation }
            return .zero
        }
    }

    private var isMovingControls: Bool { clusterMove.isActive || isSettlingAfterMove }

    /// The cluster fades a little after a few quiet seconds, and comes back on
    /// the next touch. It never hides: the buttons are the non-gesture way to
    /// decide, so they have to stay findable.
    @State private var isClusterIdle = false
    /// Bumped by anything the user does, to restart the idle countdown.
    @State private var activityToken = 0

    /// How far the photo has to travel horizontally before releasing decides.
    private let commitThreshold: CGFloat = 90

    /// The controls, the tray behind them that is held to move the cluster, and
    /// the margin the tray keeps from the screen edges.
    private let controlSize: CGFloat = 56
    private let controlSpacing: CGFloat = 14
    private let trayInset: CGFloat = 16
    private let clusterMargin: CGFloat = 20
    /// The cluster never reaches into the top strip, whatever edge it is docked
    /// to, so Close, the Live Photo badge and Review stay reachable.
    private let topStripClearance: CGFloat = 54

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
                            if preset.tapToKeep { model.apply(.keep) }
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
            .overlay(alignment: .topLeading) { controlCluster(in: geometry.size) }
            .task(id: activityToken) { await fadeClusterWhenIdle() }
        }
        .task(id: currentID) {
            updatePrefetch()
            model.presentTutorialIfNeeded()
            activityToken += 1
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

    /// Width reserved for a side-docked cluster, so the photo is fitted *beside*
    /// it rather than running underneath the controls. A control sitting on a
    /// busy photo is the "half-buried" feel this design exists to remove.
    private var railLaneWidth: CGFloat { model.preferences.rail.isVertical ? 88 : 0 }

    /// How far the photo shifts to stay centred in the area the cluster leaves
    /// free.
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
    /// separate tap targets, so nobody has to swipe. The three controls remain
    /// the alternative for anyone who cannot or does not want to gesture.
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
                                title: "Delete",
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

    /// Informational chrome only: what this asset is, the way out, the favorite
    /// and the way into review. None of it moves when the rail moves, because it
    /// is anchored independently at the top.
    private var topBar: some View {
        ZStack {
            // Centred, so it sits in the middle whatever the two ends are doing.
            if model.currentAsset?.isLivePhoto == true {
                livePhotoBadge
            }

            HStack(spacing: 10) {
                closeControl
                Spacer(minLength: 0)
                favoriteControl
                reviewControl
            }
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

    /// Leaving is always the same corner, the way a Back button is on every
    /// other screen. Drawn smaller than the decision controls, but with a full
    /// tap region so it is still easy to hit.
    private var closeControl: some View {
        CircleControl(
            systemImage: "xmark",
            label: "Close",
            identifier: "viewer.close",
            visualSize: 34,
            hitSize: 44
        ) {
            model.closeViewer()
        }
    }

    /// The heart keeps a place in the top strip, where it costs the decision
    /// controls nothing. It is not in the bottom cluster because it is used far
    /// less often than delete, undo and keep.
    private var favoriteControl: some View {
        CircleControl(systemImage: "heart", label: "Favorite", identifier: "viewer.favorite") {
            model.apply(.favorite)
        }
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

    // MARK: - The movable control cluster

    /// How long the three controls are end to end, and how big the tray behind
    /// them is. The tray is what is held to move the cluster, so it is part of
    /// every measurement: nothing may push it off the screen.
    private var clusterLength: CGFloat { controlSize * 3 + controlSpacing * 2 }

    private var buttonsSize: CGSize {
        model.preferences.rail.isVertical
            ? CGSize(width: controlSize, height: clusterLength)
            : CGSize(width: clusterLength, height: controlSize)
    }

    private var clusterSize: CGSize {
        CGSize(
            width: buttonsSize.width + trayInset * 2,
            height: buttonsSize.height + trayInset * 2
        )
    }

    /// Where the cluster's centre sits for the current dock and position, before
    /// any in-progress drag. Everything is clamped inside the safe area and
    /// below the top strip, so no drop can leave a control unreachable.
    private func clusterCentre(in size: CGSize) -> CGPoint {
        let half = model.preferences.rail.isVertical ? clusterSize.height / 2 : clusterSize.width / 2
        let position = ControlPreferences.clamped(model.preferences.position)

        switch model.preferences.rail {
        case .bottom:
            let travel = max(0, size.width - clusterSize.width - clusterMargin * 2)
            return CGPoint(
                x: clusterMargin + half + travel * position,
                y: size.height - clusterMargin - clusterSize.height / 2
            )
        case .leading, .trailing:
            let top = topStripClearance + clusterMargin
            let travel = max(0, size.height - top - clusterMargin - clusterSize.height)
            return CGPoint(
                x: model.preferences.rail == .leading
                    ? clusterMargin + clusterSize.width / 2
                    : size.width - clusterMargin - clusterSize.width / 2,
                y: top + half + travel * position
            )
        }
    }

    /// The cluster, at its remembered place, following the finger while it is
    /// being moved.
    ///
    /// The tray is the handle. A plain `Button` claims the touches that land on
    /// it, so a hold on one of the three controls cannot move the cluster; the
    /// tray around and between them can, and drawing it makes the thing that
    /// moves obvious instead of leaving the grab area invisible.
    private func controlCluster(in size: CGSize) -> some View {
        let centre = clusterCentre(in: size)
        let trayRadius = controlSize / 2 + trayInset
        return ZStack {
            // The tray carries the move gesture itself, rather than the container
            // around the buttons. It sits behind the controls, so it cannot
            // interfere with their taps, and the ring and gaps between them are
            // its own hit area.
            RoundedRectangle(cornerRadius: trayRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: trayRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: trayRadius, style: .continuous))
                .gesture(moveControlsGesture(in: size))
            if model.preferences.rail.isVertical {
                VStack(spacing: controlSpacing) { clusterControls }
            } else {
                HStack(spacing: controlSpacing) { clusterControls }
            }
        }
        .frame(width: clusterSize.width, height: clusterSize.height)
        .opacity(isClusterIdle && !isMovingControls ? 0.55 : 1)
        .scaleEffect(isMovingControls ? 1.06 : 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isClusterIdle)
        // The accessibility element has to be the cluster itself. Applying these
        // after `.position` would report the whole screen instead, because
        // `.position` fills its parent.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("viewer.cluster")
        .accessibilityLabel("Photo controls")
        .accessibilityValue(
            isMovingControls
                ? "Moving, docked \(model.preferences.rail.title)"
                : "Docked \(model.preferences.rail.title)"
        )
        // A drag is not available to everyone, so the dock can also be stepped
        // through without one.
        .accessibilityAction(named: "Move to the next edge") { cycleControlEdge() }
        // Offset from the top-leading corner rather than `.position`: `.position`
        // wraps the view in a full-screen container, which both mis-reports the
        // cluster's frame and stopped its gesture from ever being recognised.
        .offset(
            x: centre.x + clusterMove.translation.width - clusterSize.width / 2,
            y: centre.y + clusterMove.translation.height - clusterSize.height / 2
        )
    }

    @ViewBuilder
    private var clusterControls: some View {
        CircleControl(systemImage: "trash", label: "Delete", tint: .red) {
            clusterAction { model.apply(.queueDeletion) }
        }
        CircleControl(systemImage: "arrow.uturn.backward", label: "Undo") {
            clusterAction { model.apply(.undo) }
        }
        CircleControl(systemImage: "checkmark", label: "Keep", tint: .green) {
            clusterAction { model.apply(.keep) }
        }
    }

    /// A control press counts as activity, so a tap after the cluster has faded
    /// both does its job and brings the cluster back to full strength. It is
    /// refused while the cluster is being moved: a move must never decide.
    private func clusterAction(_ action: () -> Void) {
        guard !isMovingControls else { return }
        activityToken += 1
        haptics.impactOccurred()
        action()
    }

    private func fadeClusterWhenIdle() async {
        isClusterIdle = false
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        guard !Task.isCancelled else { return }
        isClusterIdle = true
    }

    /// Hold the cluster's tray, then drag: it lifts, follows the finger, and
    /// docks to the nearest of the bottom, left and right edges when released. A
    /// plain drag never moves it, so swiping can never shove the buttons around.
    private func moveControlsGesture(in size: CGSize) -> some Gesture {
        LongPressGesture(minimumDuration: 0.45)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($clusterMove) { value, state, _ in
                switch value {
                case .first(true):
                    state = .lifting
                case .second(true, let drag):
                    state = .dragging(drag?.translation ?? .zero)
                default:
                    state = .idle
                }
            }
            .onChanged { value in
                guard case .first(true) = value, !didSendLiftHaptic else { return }
                didSendLiftHaptic = true
                activityToken += 1
                moveHaptics.impactOccurred()
            }
            .onEnded { value in
                guard case .second(true, let drag) = value else { return }
                finishMovingControls(in: size, translation: drag?.translation ?? .zero)
            }
    }

    private func finishMovingControls(in size: CGSize, translation: CGSize) {
        let centre = clusterCentre(in: size)
        let dropped = CGPoint(
            x: centre.x + translation.width,
            y: centre.y + translation.height
        )
        let (rail, position) = dock(for: dropped, in: size)

        var preferences = model.preferences
        preferences.rail = rail
        preferences.position = position
        model.updatePreferences(preferences)

        didSendLiftHaptic = false
        activityToken += 1
        // Settle for a moment before the buttons can decide again. A control
        // under the finger can deliver its action as the touch ends, and moving
        // the cluster must never keep, delete or favorite a photo.
        isSettlingAfterMove = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            isSettlingAfterMove = false
        }
    }

    /// The edge a dropped cluster lands on: whichever of the three edges its
    /// centre is nearest, so the lower left corner ties between the bottom and
    /// the left edge and either is a fair answer.
    private func dock(for centre: CGPoint, in size: CGSize) -> (ControlRail, Double) {
        let distances: [(rail: ControlRail, distance: CGFloat)] = [
            (.leading, centre.x),
            (.trailing, size.width - centre.x),
            (.bottom, size.height - centre.y),
        ]
        let rail = distances.min { $0.distance < $1.distance }?.rail ?? .bottom
        let half = rail.isVertical ? clusterSize.height / 2 : clusterSize.width / 2

        switch rail {
        case .bottom:
            let travel = max(1, size.width - clusterSize.width - clusterMargin * 2)
            let raw = (centre.x - clusterMargin - half) / travel
            return (.bottom, ControlPreferences.clamped(raw))
        case .leading, .trailing:
            let top = topStripClearance + clusterMargin
            let travel = max(1, size.height - top - clusterMargin - clusterSize.height)
            let raw = (centre.y - top - half) / travel
            return (rail, ControlPreferences.clamped(raw))
        }
    }

    /// Steps the dock round the three edges, for anyone who cannot drag.
    private func cycleControlEdge() {
        var preferences = model.preferences
        switch preferences.rail {
        case .bottom: preferences.rail = .leading
        case .leading: preferences.rail = .trailing
        case .trailing: preferences.rail = .bottom
        }
        if !preferences.rail.isVertical { preferences.position = 0.5 }
        model.updatePreferences(preferences)
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
