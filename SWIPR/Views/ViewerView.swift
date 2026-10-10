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
    @State private var lightHaptics = UIImpactFeedbackGenerator(style: .light)

    /// Where the dock move is: whether this touch became a move, which
    /// destination it captured, and where the finger is.
    ///
    /// It is not a `@GestureState`, because the release still needs the captured
    /// destination after the touch-up that ends the gesture.
    @State private var dockMove = DockMove.idle
    /// True for the whole of a touch on the dock and false again the moment that
    /// touch ends *or is cancelled*, so an interrupted move can never leave the
    /// token stranded. This is the reset path a normal end cannot provide.
    @GestureState private var dockTouching = false
    /// Set when the current touch passes the tap-cancel threshold, and cleared on
    /// the next main-queue turn after that touch has ended. It outlives the
    /// gesture by one turn because the control under the finger fires its own
    /// action on the very same touch-up: a move must never decide.
    @State private var dockMoved = false

    /// The two responses the optional haptics can give; which interaction gets
    /// which is ``HapticFeedback``'s, and the stored Haptics preference is the
    /// one gate over all of them.
    private let softHaptics = UIImpactFeedbackGenerator(style: .soft)

    /// Gives the response `event` calls for, or nothing when the user turned
    /// Haptics off. Every optional response in the viewer goes through here, so
    /// the preference cannot be honoured in one place and missed in another.
    private func giveHaptic(_ event: HapticFeedback.Event) {
        switch HapticFeedback.response(to: event, enabled: model.preferences.haptics) {
        case .none: break
        case .light: lightHaptics.impactOccurred()
        case .soft: softHaptics.impactOccurred()
        }
    }

    /// The live state of one dock move. The compact token appears the moment
    /// `isMoving` turns true, which is exactly when the pending tap is cancelled
    /// for good.
    private struct DockMove: Equatable {
        var isMoving = false
        /// The destination the finger has captured, or nil when it is between
        /// them, where a release would restore the source.
        var captured: ControlPosition?
        /// The finger's position in the dock's own coordinate space.
        var pointer: CGPoint = .zero
        static let idle = DockMove()
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
            .overlay { destinationMarkers(in: geometry.size) }
            .overlay(alignment: .topLeading) {
                dockLayer(in: geometry.size, origin: geometry.frame(in: .global).origin)
            }
            .task(id: activityToken) { await fadeClusterWhenIdle() }
            // A cancelled gesture never reaches the drag's `onEnded`, so this is
            // where the token goes back to being the dock. A normal end has
            // already landed it and left this with nothing to do.
            .onChange(of: dockTouching) { _, touching in
                guard !touching else {
                    // The finger has just come down on the dock.
                    giveHaptic(.pickup)
                    return
                }
                finishDockTouch()
            }
        }
        .task(id: currentID) {
            updatePrefetch()
            model.presentTutorialIfNeeded()
            applyFrozenSwipeIfRequested()
            activityToken += 1
        }
        .onDisappear { clearPrefetch() }
    }

    private var currentID: String? { model.engine?.current?.id }

    /// A spoken description of the current asset. VoiceOver users hear what the
    /// photo is and whether it is already marked, instead of an unlabelled
    /// image.
    private func accessibilityDescription(for asset: AssetDescriptor) -> String {
        var parts = [MediaKindPresentation(kind: asset.kind).accessibilityLabel]
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
                    giveHaptic(.thresholdCrossing)
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
                    // The threshold crossing above already gave the response, so
                    // this only readies the engine for the next one.
                    if model.preferences.haptics { lightHaptics.prepare() }
                    model.apply(committed)
                }
            }
    }

    /// UI-test seam: freezes the swipe part-way so the mid-drag feedback can be
    /// screenshotted without a held finger. Only the explicit
    /// `-uiTestingFreezeSwipe left|right` argument triggers it, so the shipping
    /// app never reaches it.
    private func applyFrozenSwipeIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-uiTestingFreezeSwipe"),
              arguments.indices.contains(flag + 1) else { return }
        switch arguments[flag + 1] {
        case "left": dragOffset = CGSize(width: -commitThreshold * 0.6, height: 0)
        case "right": dragOffset = CGSize(width: commitThreshold * 0.6, height: 0)
        default: break
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

                VStack(spacing: 0) {
                    HStack {
                        if direction == .queueDeletion {
                            outcomeWell(
                                systemImage: "trash.fill",
                                title: "Delete",
                                tint: outcomeTint(direction),
                                armed: armed,
                                progress: progress,
                                identifier: "viewer.dragFeedback.delete"
                            )
                        }
                        Spacer(minLength: 0)
                        if direction == .keep {
                            outcomeWell(
                                systemImage: "checkmark",
                                title: "Keep",
                                tint: outcomeTint(direction),
                                armed: armed,
                                progress: progress,
                                identifier: "viewer.dragFeedback.keep"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    // Upper third, clear of the whole top bar — even the tallest
                    // AX5 Live/Video badge — so a thumb on the photo can never
                    // cover the outcome it is choosing.
                    .padding(.top, 80)
                    Spacer(minLength: 0)
                }
            }
            // Feedback must never swallow the drag it is describing. It stays in
            // the accessibility tree so a UI test can measure where it lands.
            .allowsHitTesting(false)
        }
    }

    private func outcomeTint(_ direction: SessionAction) -> Color {
        direction == .queueDeletion ? DockEdgeTint.delete : DockEdgeTint.keep
    }

    private func outcomeWell(
        systemImage: String,
        title: String,
        tint: Color,
        armed: Bool,
        progress: CGFloat,
        identifier: String
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Chrome

    /// Informational chrome only: what this asset is, the way out, and the way
    /// into review. None of it moves when the cluster moves, because it is
    /// anchored independently at the top.
    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            closeControl
            Spacer(minLength: 0)
            // The media kind and the way into Review share the top bar row, so
            // the badge's centre line is Close's centre line, not a second row
            // beneath Review.
            mediaKindBadge
            reviewControl
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    /// A small neutral glass capsule naming what is on screen: Live or Video.
    /// A plain photo carries no badge — there is nothing to distinguish — while
    /// the symbol *and* the word carry the meaning for the kinds that do. It
    /// sits in the top bar row, centred with Close.
    @ViewBuilder
    private var mediaKindBadge: some View {
        if let asset = model.currentAsset, asset.kind != .photo {
            let presentation = MediaKindPresentation(kind: asset.kind)
            HStack(spacing: 4) {
                Image(systemName: presentation.symbol)
                    .font(.caption2.weight(.bold))
                Text(presentation.title)
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
            .accessibilityLabel(presentation.accessibilityLabel)
            .accessibilityIdentifier("viewer.mediaBadge")
        }
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

    /// A round 44 pt trash control, the same glass circle as Close, that is
    /// always reachable once anything is marked. The count sits in a small red
    /// badge; the spoken label carries the same count, and the button never
    /// says "Review".
    @ViewBuilder
    private var reviewControl: some View {
        if model.queueCount > 0 {
            CircleControl(
                systemImage: "trash",
                label: DeletionWording.markedForDeletion(model.queueCount),
                identifier: "viewer.review",
                visualSize: 34,
                hitSize: 44,
                badgeCount: model.queueCount
            ) {
                model.goToReview(from: .viewer)
            }
            .accessibilityValue(DeletionWording.nothingDeletedYet)
        }
    }

    // MARK: - The decision dock

    /// The dock at its remembered position. Its whole surface is draggable — a
    /// drag may begin on any control or in any gap — so the legacy grip is gone.
    /// While a touch is moving the dock the controls are replaced by one compact
    /// neutral token, and a valid release lands the controls there.
    @ViewBuilder
    private func dockLayer(in size: CGSize, origin: CGPoint) -> some View {
        if model.preferences.showButtons {
            let position = model.preferences.position
            let undoSide = model.preferences.undoSide
            let rect = ControlClusterLayout.slotRect(for: position, in: size, undoSide: undoSide)

            ZStack {
                if dockMove.isMoving {
                    dockToken(in: size, centre: CGPoint(x: rect.midX, y: rect.midY))
                } else {
                    dockControls(position: position, undoSide: undoSide, in: size)
                }
            }
            .frame(width: rect.width, height: rect.height)
            // The whole frame, gaps included, is the drag surface: `contentShape`
            // is what puts the space between two controls under the finger as
            // well. Its corners are only slightly rounded, so every point inside
            // the dock's frame — including the tray's padding and the gap either
            // side of the separate Undo control — belongs to the handle.
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(isClusterIdle && !dockMove.isMoving ? 0.7 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isClusterIdle)
            // Recorded before `.offset` so a gesture that begins in a gap is
            // recognised too. Simultaneous with the controls' own taps, so a
            // normal tap still performs its action with no movement delay.
            .simultaneousGesture(dockGesture(in: size, origin: origin))
            // The accessibility element has to be the dock itself. Applying these
            // after `.position` would report the whole screen instead, because
            // `.position` fills its parent.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("viewer.cluster")
            .accessibilityLabel("Photo controls")
            .accessibilityValue(dockMove.isMoving ? "Moving controls" : "Docked \(position.title)")
            // A drag is not available to everyone, so the position can also be
            // stepped through without one.
            .accessibilityAction(named: "Move to the next position") { cycleControlPosition() }
            // Offset from the top-leading corner rather than `.position`:
            // `.position` wraps the view in a full-screen container, which both
            // mis-reports the dock's frame and stopped its gesture from ever
            // being recognised.
            .offset(x: rect.minX, y: rect.minY)
        }
    }

    /// The two layouts of the neutral dock.
    ///
    /// At the bottom the labelled Delete/Keep pair is centred with the separate
    /// smaller Undo control outside it; at a side three separate icon controls
    /// stand apart with a non-action gap between them. In both, Undo takes an
    /// outer end — the left of the row, the top of the column — so "Before
    /// actions" means the same thing whichever layout is on screen, and Delete
    /// and Keep never move relative to each other.
    @ViewBuilder
    private func dockControls(position: ControlPosition, undoSide: UndoSide, in size: CGSize) -> some View {
        if position.isVertical {
            VStack(spacing: ControlClusterLayout.controlSpacing) {
                ForEach(ControlClusterLayout.order(for: undoSide)) { control in
                    decisionControl(control)
                }
            }
        } else {
            HStack(spacing: ControlClusterLayout.undoGap) {
                if undoLeads(undoSide) { undoControl }
                bottomTray(in: size)
                if !undoLeads(undoSide) { undoControl }
            }
        }
    }

    /// Whether Undo takes the leading end of the layout axis, which is what
    /// "Before actions" means: the left of the bottom row, the top of a column.
    /// It is read off the one order the two layouts share, so the mapping cannot
    /// drift between them.
    private func undoLeads(_ undoSide: UndoSide) -> Bool {
        ControlClusterLayout.order(for: undoSide).first == .undo
    }

    /// The bottom tray: the two labelled pills together, so the pair reads as
    /// one centred unit with its own quiet edge, drawn at the one frame the
    /// geometry gives the pair. On a narrow screen the pills narrow with it — the
    /// pair keeps its anchor and the whole dock stays on screen.
    private func bottomTray(in size: CGSize) -> some View {
        let tray = ControlClusterLayout.traySize(in: size)
        return HStack(spacing: ControlClusterLayout.pillSpacing) {
            DecisionPill(
                systemImage: "trash",
                title: "Delete",
                edgeTint: DockEdgeTint.delete,
                identifier: "control.delete"
            ) {
                clusterAction { model.apply(.queueDeletion) }
            }
            DecisionPill(
                systemImage: "checkmark",
                title: "Keep",
                edgeTint: DockEdgeTint.keep,
                identifier: "control.keep"
            ) {
                clusterAction { model.apply(.keep) }
            }
        }
        .padding(ControlClusterLayout.trayInset)
        .frame(width: tray.width, height: tray.height)
        .background(
            DockControlBackground(
                shape: RoundedRectangle(
                    cornerRadius: tray.height / 2,
                    style: .continuous
                ),
                edgeTint: nil
            )
        )
    }

    /// The separate, smaller Undo of the bottom layout. Undo is the only
    /// reversible decision and the least frequent one, so it stays a step apart
    /// from the pair and never between Delete and Keep.
    private var undoControl: some View {
        CircleControl(
            systemImage: "arrow.uturn.backward",
            label: "Undo",
            visualSize: ControlClusterLayout.undoControlSize,
            hitSize: ControlClusterLayout.undoControlSize
        ) {
            clusterAction { model.apply(.undo) }
        }
    }

    /// The compact neutral token the dock becomes while it is being moved. It
    /// follows the finger but is drawn clear of it, so the finger never covers
    /// what it is aiming at, and it stays whole inside the safe area.
    private func dockToken(in size: CGSize, centre: CGPoint) -> some View {
        let tokenSize = ControlClusterLayout.controlSize
        let half = tokenSize / 2
        let x = min(max(dockMove.pointer.x, half), max(half, size.width - half))
        let y = min(max(dockMove.pointer.y - tokenSize, half), max(half, size.height - half))

        return ZStack {
            Circle().fill(.ultraThinMaterial)
            Circle().stroke(Color.white.opacity(0.45), lineWidth: 1)
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: tokenSize, height: tokenSize)
        .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
        .offset(x: x - centre.x, y: y - centre.y)
        .accessibilityElement()
        .accessibilityLabel("Moving controls")
        .accessibilityIdentifier("viewer.dockToken")
    }

    /// The three subtle markers that expose the only destinations, shown only
    /// while the dock is being moved. Each is drawn in the dock's own shape at
    /// the dock's own size, so what the marker covers is exactly what the dock
    /// will cover. The captured one strengthens through opacity and stroke
    /// weight — never through saturated colour — and they are feedback, not
    /// controls, so they take no touches.
    @ViewBuilder
    private func destinationMarkers(in size: CGSize) -> some View {
        if model.preferences.showButtons && dockMove.isMoving {
            ZStack {
                ForEach(ControlPosition.allCases) { position in
                    let rect = ControlClusterLayout.slotRect(
                        for: position,
                        in: size,
                        undoSide: model.preferences.undoSide
                    )
                    let captured = dockMove.captured == position
                    // The marker is the dock's own shape at the dock's own size,
                    // so what it covers is exactly what the dock will cover.
                    RoundedRectangle(cornerRadius: min(rect.width, rect.height) / 2, style: .continuous)
                        .fill(Color.white.opacity(captured ? 0.10 : 0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: min(rect.width, rect.height) / 2, style: .continuous)
                                .stroke(
                                    Color.white.opacity(captured ? 0.95 : 0.30),
                                    lineWidth: captured ? 2.5 : 1
                                )
                        )
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func decisionControl(_ control: ControlClusterLayout.ClusterControl) -> some View {
        switch control {
        case .trash:
            CircleControl(systemImage: "trash", label: "Delete", edgeTint: DockEdgeTint.delete) {
                clusterAction { model.apply(.queueDeletion) }
            }
        case .keep:
            CircleControl(systemImage: "checkmark", label: "Keep", edgeTint: DockEdgeTint.keep) {
                clusterAction { model.apply(.keep) }
            }
        case .undo:
            CircleControl(systemImage: "arrow.uturn.backward", label: "Undo") {
                clusterAction { model.apply(.undo) }
            }
        }
    }

    /// A control press counts as activity, so a tap after the dock has faded both
    /// does its job and brings it back to full strength. It is refused for the
    /// whole of a touch that moved the dock: a move must never decide.
    private func clusterAction(_ action: () -> Void) {
        guard !dockMoved else { return }
        activityToken += 1
        giveHaptic(.controlPress)
        action()
    }

    private func fadeClusterWhenIdle() async {
        isClusterIdle = false
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        guard !Task.isCancelled else { return }
        isClusterIdle = true
    }

    /// One gesture owns the whole dock. Moving roughly nine points cancels the
    /// pending tap for good: the dock becomes the token, the three markers
    /// appear, and the captured destination follows the finger with hysteresis so
    /// a dock held near a boundary cannot flicker. A release over the captured
    /// marker lands there; a release over none, or a cancelled gesture, restores
    /// the source.
    ///
    /// `value.location` is read in the window's space, not the dock's, because
    /// the dock changes shape and place while this gesture is running and a
    /// point must not change meaning halfway through.
    private func dockGesture(in size: CGSize, origin: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($dockTouching) { _, state, _ in state = true }
            .onChanged { value in
                let point = canvasPoint(value.location, origin: origin)
                if !dockMoved {
                    let start = canvasPoint(value.startLocation, origin: origin)
                    guard DockGeometry.cancelsTap(from: start, to: point) else { return }
                    dockMoved = true
                    activityToken += 1
                    withAnimation(dockMorphAnimation) { dockMove.isMoving = true }
                }
                dockMove.pointer = point
                let wasCaptured = dockMove.captured
                let captured = DockGeometry.capture(at: point, in: size, currentlyCaptured: wasCaptured)
                dockMove.captured = captured
                if captured == wasCaptured {
                    // A destination that stays captured is named too, so "no
                    // repeats while captured" is the mapping's rule rather than
                    // a guard that could drift from it.
                    giveHaptic(.captureHeld)
                } else if captured != nil {
                    // One light response on entering capture. Moving off a
                    // destination for the space between them says nothing.
                    giveHaptic(.capture)
                }
            }
            .onEnded { value in
                guard dockMoved else { return }
                let point = canvasPoint(value.location, origin: origin)
                land(DockGeometry.destination(forReleaseAt: point, in: size, captured: dockMove.captured))
            }
    }

    /// The dock's own coordinate space: the safe area the three destinations are
    /// measured in. `DragGesture` reports the window's coordinates.
    private func canvasPoint(_ global: CGPoint, origin: CGPoint) -> CGPoint {
        CGPoint(x: global.x - origin.x, y: global.y - origin.y)
    }

    /// Lands the dock on `destination`, or restores the source when the release
    /// captured none. The whole dock is one view, so every control comes back
    /// together: there is nothing to stagger and nothing to wait for.
    private func land(_ destination: ControlPosition?) {
        guard let destination else {
            // An invalid release says nothing and changes nothing.
            giveHaptic(.invalidRelease)
            withAnimation(landingAnimation) { dockMove = .idle }
            activityToken += 1
            return
        }
        giveHaptic(.landing)
        withAnimation(landingAnimation) {
            // `moveDock` refuses a destination the dock already occupies, so a
            // drop back on the source writes nothing and leaves the session's
            // direction alone.
            model.moveDock(to: destination)
            dockMove = .idle
        }
        activityToken += 1
    }

    /// Ends this touch's record. Both jobs are done on the next main-queue turn,
    /// because SwiftUI may deliver this change either side of the drag's own
    /// `onEnded`: the landing has to see the gesture's own record of what it
    /// captured, and the control under the finger fires its own action on the
    /// same touch-up, which a gesture that moved the dock must never let through.
    private func finishDockTouch() {
        DispatchQueue.main.async {
            if dockMove.isMoving {
                // The gesture was cancelled: the dock returns to the source.
                withAnimation(landingAnimation) { dockMove = .idle }
            }
            dockMoved = false
        }
    }

    /// The landing is the only animated part of a move; the token is always
    /// exactly where the finger put it. Reduce Motion tightens the spring rather
    /// than swapping it for a different curve.
    private var landingAnimation: Animation {
        reduceMotion
            ? .spring(duration: ControlClusterLayout.reduceMotionDuration, bounce: 0)
            : .spring(duration: ControlClusterLayout.landingDuration, bounce: ControlClusterLayout.landingBounce)
    }

    /// The dock becoming the token, and the token becoming the dock again.
    private var dockMorphAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.22, bounce: 0.08)
    }

    /// Steps the position round the three stops, for anyone who cannot drag.
    private func cycleControlPosition() {
        model.moveDock(to: model.preferences.position.next)
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

/// How one media kind is named on the viewer badge and to assistive
/// technology. Keeping it in one place means the visible word, the symbol and
/// the spoken label can never drift apart.
private struct MediaKindPresentation {
    let symbol: String
    let title: String
    let accessibilityLabel: String

    init(kind: MediaKind) {
        switch kind {
        case .photo:
            symbol = "photo"
            title = "Photo"
            accessibilityLabel = "Photo"
        case .livePhoto:
            symbol = "livephoto"
            title = "Live"
            accessibilityLabel = "Live Photo"
        case .video:
            symbol = "video"
            title = "Video"
            accessibilityLabel = "Video"
        }
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
