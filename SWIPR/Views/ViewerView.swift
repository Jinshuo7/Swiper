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

    /// Where the grip drag is: how far the finger has moved from the grip.
    ///
    /// This is a `@GestureState` on purpose. A gesture state resets itself when
    /// the gesture ends *or is cancelled*, so an interrupted drag can never
    /// leave a puck stranded or the cluster half-moved.
    @GestureState private var gripMove = GripMove.idle
    /// The slot the puck is over, or nil when it is over none.
    @State private var highlightedSlot: ControlPosition?
    /// One lift haptic per drag.
    @State private var didLift = false

    private let liftHaptics = UIImpactFeedbackGenerator(style: .light)
    private let slotHaptics = UIImpactFeedbackGenerator(style: .light)
    private let landingHaptics = UIImpactFeedbackGenerator(style: .rigid)

    private struct GripMove: Equatable {
        var translation: CGSize = .zero
        /// The puck appears once the drag has passed a few points, matching the
        /// drag-image rule.
        static let liftThreshold: CGFloat = 3
        var isActive: Bool { hypot(translation.width, translation.height) > Self.liftThreshold }
        static let idle = GripMove()
    }

    /// The cluster fades a little after a few quiet seconds, and comes back on
    /// the next touch. It never hides while buttons are shown: the buttons are
    /// the non-gesture way to decide, so they have to stay findable.
    @State private var isClusterIdle = false
    /// Bumped by anything the user does, to restart the idle countdown.
    @State private var activityToken = 0

    /// How far the photo has to travel horizontally before releasing decides.
    private let commitThreshold: CGFloat = 90

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
                        .gesture(swipeGesture)
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
            .overlay { controlSlots(in: geometry.size) }
            .overlay { puck(in: geometry.size) }
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
        CGSize(
            width: max(1, geometry.size.width + geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing),
            height: max(1, geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom)
        )
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

    /// Informational chrome only: what this asset is, the way out, and the way
    /// into review. None of it moves when the cluster moves, because it is
    /// anchored independently at the top.
    private var topBar: some View {
        ZStack {
            // Centred, so it sits in the middle whatever the two ends are doing.
            if model.currentAsset?.isLivePhoto == true {
                livePhotoBadge
            }

            HStack(spacing: 10) {
                closeControl
                Spacer(minLength: 0)
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

    // MARK: - The control cluster

    /// The cluster, at its remembered position. It no longer follows a drag: the
    /// grip lifts a separate puck and only the landing moves the cluster, so a
    /// move is never mistaken for a decision and the buttons never travel under
    /// a wandering finger.
    @ViewBuilder
    private func controlCluster(in size: CGSize) -> some View {
        if model.preferences.showButtons {
            clusterBody(in: size)
        }
    }

    private func clusterBody(in size: CGSize) -> some View {
        let position = model.preferences.position
        let cluster = ControlClusterLayout.clusterSize(for: position)
        let centre = ControlClusterLayout.centre(for: position, in: size)
        let radius = ControlClusterLayout.controlSize / 2 + ControlClusterLayout.trayInset
        let controls = ControlClusterLayout.order(for: model.preferences.undoSide)

        return ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            if position.isVertical {
                VStack(spacing: ControlClusterLayout.controlSpacing) {
                    ForEach(controls) { clusterControl($0, in: size) }
                }
            } else {
                HStack(spacing: ControlClusterLayout.controlSpacing) {
                    ForEach(controls) { clusterControl($0, in: size) }
                }
            }
        }
        .frame(width: cluster.width, height: cluster.height)
        .opacity(isClusterIdle && !gripMove.isActive ? 0.7 : 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isClusterIdle)
        // The accessibility element has to be the cluster itself. Applying these
        // after `.position` would report the whole screen instead, because
        // `.position` fills its parent.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("viewer.cluster")
        .accessibilityLabel("Photo controls")
        .accessibilityValue(gripMove.isActive ? "Moving controls" : "Docked \(position.title)")
        // A drag is not available to everyone, so the position can also be
        // stepped through without one.
        .accessibilityAction(named: "Move to the next position") { cycleControlPosition() }
        // Offset from the top-leading corner rather than `.position`: `.position`
        // wraps the view in a full-screen container, which both mis-reports the
        // cluster's frame and stopped its gesture from ever being recognised.
        .offset(x: centre.x - cluster.width / 2, y: centre.y - cluster.height / 2)
    }

    /// The three-dot handle. Dragging it is the only way to move the cluster, so
    /// a swipe on the photo can never shove the buttons around.
    private func grip(in size: CGSize) -> some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white.opacity(0.75))
            .frame(width: ControlClusterLayout.gripHitSize, height: ControlClusterLayout.gripHitSize)
            .contentShape(Rectangle())
            .gesture(moveGesture(in: size))
            .accessibilityLabel("Move controls")
            .accessibilityIdentifier("viewer.grip")
    }

    @ViewBuilder
    private func clusterControl(_ control: ControlClusterLayout.ClusterControl, in size: CGSize) -> some View {
        switch control {
        case .grip: grip(in: size)
        case .trash: trashControl
        case .keep: keepControl
        case .undo: undoControl
        }
    }

    private var trashControl: some View {
        CircleControl(systemImage: "trash", label: "Delete", tint: .red) {
            clusterAction { model.apply(.queueDeletion) }
        }
    }

    private var keepControl: some View {
        CircleControl(systemImage: "checkmark", label: "Keep", tint: .green) {
            clusterAction { model.apply(.keep) }
        }
    }

    private var undoControl: some View {
        CircleControl(systemImage: "arrow.uturn.backward", label: "Undo") {
            clusterAction { model.apply(.undo) }
        }
    }

    /// A control press counts as activity, so a tap after the cluster has faded
    /// both does its job and brings the cluster back to full strength. It is
    /// refused while the grip is being dragged: a move must never decide.
    private func clusterAction(_ action: () -> Void) {
        guard !gripMove.isActive else { return }
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

    /// The three phantom slots, shown only while the puck is in the air. The
    /// nearest one to the puck is highlighted; releasing over it lands there.
    @ViewBuilder
    private func controlSlots(in size: CGSize) -> some View {
        if model.preferences.showButtons && gripMove.isActive {
            ZStack {
                ForEach(ControlPosition.allCases) { position in
                    let cluster = ControlClusterLayout.clusterSize(for: position)
                    let centre = ControlClusterLayout.centre(for: position, in: size)
                    let radius = ControlClusterLayout.controlSize / 2 + ControlClusterLayout.trayInset
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color.white.opacity(highlightedSlot == position ? 0.12 : 0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .stroke(
                                    Color.white.opacity(highlightedSlot == position ? 0.95 : 0.28),
                                    lineWidth: highlightedSlot == position ? 3 : 1
                                )
                        )
                        .frame(width: cluster.width, height: cluster.height)
                        .position(centre)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// The translucent circle the grip becomes while it is dragged. It tracks
    /// the finger one-to-one and carries no animation of its own.
    @ViewBuilder
    private func puck(in size: CGSize) -> some View {
        if model.preferences.showButtons && gripMove.isActive {
            let origin = ControlClusterLayout.gripCentre(
                for: model.preferences.position,
                in: size,
                undoSide: model.preferences.undoSide
            )
            let centre = CGPoint(
                x: origin.x + gripMove.translation.width,
                y: origin.y + gripMove.translation.height
            )
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: ControlClusterLayout.controlSize, height: ControlClusterLayout.controlSize)
            .position(centre)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// Drag the grip: a puck lifts and follows the finger, the three slots
    /// appear, and releasing over one moves the cluster there. Releasing over no
    /// slot, or cancelling, changes nothing.
    private func moveGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($gripMove) { value, state, _ in
                state = GripMove(translation: value.translation)
            }
            .onChanged { value in
                let move = GripMove(translation: value.translation)
                guard move.isActive else { return }
                if !didLift {
                    didLift = true
                    activityToken += 1
                    liftHaptics.impactOccurred()
                }
                let target = targetSlot(for: move, in: size)
                if target != highlightedSlot {
                    highlightedSlot = target
                    if target != nil { slotHaptics.impactOccurred() }
                }
            }
            .onEnded { value in
                let move = GripMove(translation: value.translation)
                let target = targetSlot(for: move, in: size)
                highlightedSlot = nil
                didLift = false
                guard let target else { return }
                if target != model.preferences.position {
                    var preferences = model.preferences
                    preferences.position = target
                    withAnimation(landingAnimation) {
                        model.updatePreferences(preferences)
                    }
                }
                activityToken += 1
                landingHaptics.impactOccurred()
            }
    }

    /// The slot a puck currently over would land in, or nil when it is over
    /// none.
    private func targetSlot(for move: GripMove, in size: CGSize) -> ControlPosition? {
        let origin = ControlClusterLayout.gripCentre(
            for: model.preferences.position,
            in: size,
            undoSide: model.preferences.undoSide
        )
        let point = CGPoint(
            x: origin.x + move.translation.width,
            y: origin.y + move.translation.height
        )
        return ControlClusterLayout.slot(at: point, in: size)
    }

    /// The landing is the only animated part of a move; the tracked puck is
    /// always exactly under the finger. Reduce Motion tightens it.
    private var landingAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: ControlClusterLayout.reduceMotionDuration)
            : .spring(duration: ControlClusterLayout.landingDuration, bounce: ControlClusterLayout.landingBounce)
    }

    /// Steps the position round the three stops, for anyone who cannot drag.
    private func cycleControlPosition() {
        var preferences = model.preferences
        preferences.position = preferences.position.next
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
