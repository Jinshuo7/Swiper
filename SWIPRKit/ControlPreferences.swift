import CoreGraphics
import Foundation

/// Where the three control buttons sit: one of exactly three fixed places,
/// chosen by the user and remembered.
///
/// Free placement along an edge is gone (`docs/adr/0007-three-fixed-control-
/// positions.md`). The three stops make the destinations knowable before a move
/// starts and remove the accidental moves a continuous position produced.
public enum ControlPosition: String, Codable, CaseIterable, Identifiable, Sendable {
    /// A row centred on the screen width, near the bottom edge.
    case bottom
    /// A column down the left edge, centred in the lower half.
    case leading
    /// A column down the right edge, centred in the lower half.
    case trailing

    public var id: String { rawValue }

    public var isVertical: Bool { self != .bottom }

    /// Spoken name, used by the cluster's accessibility value.
    public var title: String {
        switch self {
        case .bottom: return "bottom"
        case .leading: return "left edge"
        case .trailing: return "right edge"
        }
    }

    /// The next stop when stepping without a drag, for the accessibility action.
    public var next: ControlPosition {
        switch self {
        case .bottom: return .leading
        case .leading: return .trailing
        case .trailing: return .bottom
        }
    }
}

/// Which outer end of the cluster the Undo button occupies.
///
/// Undo is the least frequent decision and the only reversible one, so it does
/// not sit between Trash and Keep; it sits at an end, and the user picks which
/// end so it falls under the thumb they actually use (`docs/adr/0011`).
public enum UndoSide: String, Codable, CaseIterable, Identifiable, Sendable {
    /// The start of the cluster: the left of a bottom row, the top of a column.
    case leading
    /// The end of the cluster: the right of a bottom row, the bottom of a column.
    case trailing

    public var id: String { rawValue }

    /// Spoken name, read relative to the Delete/Keep pair in the current layout
    /// rather than as a screen side, so the same wording is true of the bottom
    /// row and of a side column (docs/SPEC.md §5.6).
    public var title: String { self == .leading ? "Before actions" : "After actions" }
}

/// The user's persisted interaction preferences.
public struct ControlPreferences: Codable, Equatable, Sendable {
    /// Which of the three fixed places the cluster sits in.
    public var position: ControlPosition
    /// Whether the three buttons and their dock are drawn at all. Swipe gestures
    /// are always available either way (`docs/adr/0009-swipe-always-buttons-
    /// optional.md`).
    public var showButtons: Bool
    /// Which outer end of the cluster Undo occupies.
    public var undoSide: UndoSide
    /// Whether the optional haptic responses are given at all. Off silences
    /// every one of them (docs/SPEC.md §5.5).
    public var haptics: Bool
    /// Direction a new session starts in. The user can change this and it is
    /// remembered.
    public var defaultDirection: TraversalDirection

    public init(
        position: ControlPosition = .bottom,
        showButtons: Bool = true,
        undoSide: UndoSide = .leading,
        haptics: Bool = true,
        defaultDirection: TraversalDirection = .older
    ) {
        self.position = position
        self.showButtons = showButtons
        self.undoSide = undoSide
        self.haptics = haptics
        self.defaultDirection = defaultDirection
    }

    public static let `default` = ControlPreferences()

    private enum CodingKeys: String, CodingKey {
        case position
        case showButtons
        case undoSide
        case haptics
        case defaultDirection
        // Written by older builds that stored the three-way dock under `rail`.
        // Read so a stored choice is not thrown away; nothing writes it.
        case rail
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultDirection = try container.decodeIfPresent(TraversalDirection.self, forKey: .defaultDirection) ?? .older
        showButtons = try container.decodeIfPresent(Bool.self, forKey: .showButtons) ?? true
        undoSide = try container.decodeIfPresent(UndoSide.self, forKey: .undoSide) ?? .leading
        // Every payload written before the Haptics setting existed gets the
        // documented default, on.
        haptics = try container.decodeIfPresent(Bool.self, forKey: .haptics) ?? true

        if let stored = try? container.decode(ControlPosition.self, forKey: .position) {
            position = stored
        } else if container.contains(.rail) {
            // Older payloads stored the same three-way choice under `rail`, with
            // a continuous `position` number that no longer exists. The rail is
            // already the fixed stop, so the number is simply dropped. An
            // unrecognised rail still throws, so a corrupt file is never guessed
            // at.
            position = try container.decode(ControlPosition.self, forKey: .rail)
        } else {
            position = .bottom
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(position, forKey: .position)
        try container.encode(showButtons, forKey: .showButtons)
        try container.encode(undoSide, forKey: .undoSide)
        try container.encode(haptics, forKey: .haptics)
        try container.encode(defaultDirection, forKey: .defaultDirection)
    }
}

/// One optional haptic response the viewer can give, and what each interaction
/// gets.
///
/// The contract is the spec's (docs/SPEC.md §§4.4, 5.5): nothing on pickup, one
/// light response the first time a destination is captured, nothing while that
/// destination stays captured, one soft response when a release lands on a
/// destination, and nothing for a release that lands nowhere or a cancelled
/// touch. A swipe past the commit threshold and a press on a control each get
/// one light response. The stored **Haptics** preference is the single gate:
/// with it off, every one of them is ``none``.
public enum HapticFeedback: Equatable, Sendable {
    case none
    case light
    case soft

    /// One moment the viewer could respond to.
    public enum Event: Equatable, Sendable {
        /// The finger came down on the dock.
        case pickup
        /// A destination became captured where the finger had none.
        case capture
        /// The finger moved while its destination stayed captured.
        case captureHeld
        /// A release landed on a destination.
        case landing
        /// A release landed nowhere, or the touch was cancelled.
        case invalidRelease
        /// A swipe crossed the commit threshold.
        case thresholdCrossing
        /// A control on the dock was pressed.
        case controlPress
    }

    /// The response `event` calls for, or ``none`` when the user's Haptics
    /// preference is off.
    public static func response(to event: Event, enabled: Bool) -> HapticFeedback {
        guard enabled else { return .none }
        switch event {
        case .pickup, .captureHeld, .invalidRelease: return .none
        case .capture, .thresholdCrossing, .controlPress: return .light
        case .landing: return .soft
        }
    }
}

/// Pure geometry for the decision dock: how big each layout is, where it sits
/// at each of the three fixed positions, and the frame each destination marker
/// draws.
///
/// The dock has no grip: it is dragged by its whole surface, which is exactly
/// the controls plus the padding and gaps around them. Two layouts share the
/// three positions — at the bottom a labelled Delete/Keep pair in a tray with a
/// separate smaller Undo, at a side three separate icon controls — and in both the
/// labelled **Delete/Keep pair is the anchor**: Undo hangs off it, so changing
/// which end Undo takes never moves Delete and Keep (docs/SPEC.md §5.6). Kept in
/// the framework rather than only inside the SwiftUI view so the geometry the spec
/// pins down is directly testable on macOS.
public enum ControlClusterLayout {
    /// One side-layout icon control, and the height of one bottom pill.
    public static let controlSize: CGFloat = 56
    /// A side layout's controls stand apart: this gap between two of them is the
    /// functional non-action gap, part of the dock's handle and nothing more.
    public static let controlSpacing: CGFloat = 14
    /// A bottom pill's width on a standard phone. A narrower screen fits the
    /// whole dock by narrowing the pills, never by moving the pair:
    /// ``fittedPillWidth(in:)`` is the width that actually ships.
    public static let pillWidth: CGFloat = 104
    /// The narrowest a pill ever gets. Every iOS 17 layout is at least 320 pt
    /// wide, where the pills still come out at 85 pt — this floor only stops a
    /// foldable-sized width from producing an unreadable sliver.
    public static let minimumPillWidth: CGFloat = 76
    /// The least clear space the bottom dock keeps against each screen edge. It is
    /// smaller than ``edgeMargin`` because the pair is centred rather than inset,
    /// and it is only what decides when the pills have to give up width.
    public static let bottomEdgeMargin: CGFloat = 8
    /// The gap between the two labelled pills, inside the bottom tray.
    public static let pillSpacing: CGFloat = 10
    /// How much tray surrounds the bottom pair.
    public static let trayInset: CGFloat = 6
    /// The bottom layout's separate Undo control is drawn smaller than an
    /// action, while keeping a full 44 pt tap target.
    public static let undoControlSize: CGFloat = 44
    /// The gap separating the separate Undo control from the labelled pair.
    public static let undoGap: CGFloat = 12
    /// How far the cluster stays from the safe-area edge.
    public static let edgeMargin: CGFloat = 20
    /// Columns are centred at this fraction of the safe-area height.
    public static let columnHeightFraction: CGFloat = 0.75

    // Motion values, here so a test can assert the bounce ceiling the spec sets.
    public static let landingBounce: Double = 0.12
    public static let landingDuration: Double = 0.32
    public static let reduceMotionDuration: Double = 0.16

    /// How wide one bottom pill is in a safe area of `size`.
    ///
    /// The design width is ``pillWidth``, and the pills only give it up when the
    /// *whole* dock — the tray's other half plus the separate Undo beyond it —
    /// would otherwise run off the screen. The pair stays centred whatever
    /// happens, so Delete and Keep keep the anchor (docs/SPEC.md §5.1, §9.2).
    public static func fittedPillWidth(in size: CGSize) -> CGFloat {
        let outsideTheTray = undoGap + undoControlSize
        let availableTrayHalf = size.width / 2 - bottomEdgeMargin - outsideTheTray
        let fitted = (availableTrayHalf * 2 - pillSpacing - trayInset * 2) / 2
        return min(pillWidth, max(minimumPillWidth, fitted))
    }

    /// The bottom tray in a safe area of `size`: the labelled Delete/Keep pair and
    /// the padding around it.
    public static func traySize(in size: CGSize) -> CGSize {
        CGSize(
            width: fittedPillWidth(in: size) * 2 + pillSpacing + trayInset * 2,
            height: controlSize + trayInset * 2
        )
    }

    /// The whole dock's size at a position in a safe area of `size`: a labelled
    /// pair plus its separate Undo control at the bottom, three separate icon
    /// controls at a side.
    public static func clusterSize(for position: ControlPosition, in size: CGSize) -> CGSize {
        let tray = traySize(in: size)
        return position.isVertical
            ? CGSize(width: controlSize, height: controlSize * 3 + controlSpacing * 2)
            : CGSize(width: undoControlSize + undoGap + tray.width, height: tray.height)
    }

    /// The anchor the dock's labelled Delete/Keep pair occupies in a safe area of
    /// `size`: the bottom pair centred on the width, a side pair centred at 75 %
    /// of the height 20 pt inside its edge.
    ///
    /// The pair is the anchor in both layouts, and the separate Undo control hangs
    /// off it. Changing which end Undo takes therefore never moves Delete and
    /// Keep: `slotRect(for:in:undoSide:)` is what moves, by the one control and
    /// gap Undo adds above or beside the pair (docs/SPEC.md §5.1 and §5.6).
    public static func centre(for position: ControlPosition, in size: CGSize) -> CGPoint {
        let cluster = clusterSize(for: position, in: size)
        switch position {
        case .bottom:
            return CGPoint(x: size.width / 2, y: size.height - edgeMargin - cluster.height / 2)
        case .leading:
            return CGPoint(x: edgeMargin + cluster.width / 2, y: size.height * columnHeightFraction)
        case .trailing:
            return CGPoint(x: size.width - edgeMargin - cluster.width / 2, y: size.height * columnHeightFraction)
        }
    }

    /// The cluster's controls in their left-to-right (or top-to-bottom) order.
    ///
    /// Trash and Keep are always adjacent and in that order, so the swipe wells'
    /// mapping — delete left, keep right — is repeated by the buttons. Undo sits
    /// at an outer end, and the user chooses which end.
    public enum ClusterControl: String, CaseIterable, Identifiable, Sendable {
        case trash
        case keep
        case undo

        public var id: String { rawValue }
    }

    public static func order(for undoSide: UndoSide) -> [ClusterControl] {
        switch undoSide {
        case .leading: return [.undo, .trash, .keep]
        case .trailing: return [.trash, .keep, .undo]
        }
    }

    /// The frame the dock occupies at a destination: the same shape the
    /// destination marker draws while the dock is being moved, so the marker
    /// shows exactly where the dock will land.
    ///
    /// At the bottom the pair keeps its anchor and the frame grows to the side
    /// Undo took, so the dock is never centred *with* Undo — the pair is. A side
    /// column grows the same way, by the one control and gap Undo adds above the
    /// pair, so the pair stays at 75 % of the height whichever end Undo takes.
    public static func slotRect(
        for position: ControlPosition,
        in size: CGSize,
        undoSide: UndoSide = .leading
    ) -> CGRect {
        let cluster = clusterSize(for: position, in: size)
        let anchor = centre(for: position, in: size)
        let origin: CGPoint
        if position.isVertical {
            // The column holds all three controls, Undo included. Its origin is
            // measured from the pair's own span so that the pair — and never the
            // column as a whole — is what stays on the anchor.
            let pairTop = order(for: undoSide).first == .undo ? controlSize + controlSpacing : 0
            let pairSpan = controlSize * 2 + controlSpacing
            origin = CGPoint(
                x: anchor.x - cluster.width / 2,
                y: anchor.y - pairTop - pairSpan / 2
            )
        } else {
            let pairHalf = traySize(in: size).width / 2
            let leading = undoSide == .leading
            origin = CGPoint(
                x: leading ? anchor.x - pairHalf - undoGap - undoControlSize : anchor.x - pairHalf,
                y: anchor.y - cluster.height / 2
            )
        }
        return CGRect(origin: origin, size: cluster)
    }
}
