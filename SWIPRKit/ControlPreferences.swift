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

    /// Spoken name, phrased for the bottom row the setting is usually read in.
    public var title: String { self == .leading ? "Left" : "Right" }
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
    /// Direction a new session starts in. The user can change this and it is
    /// remembered.
    public var defaultDirection: TraversalDirection

    public init(
        position: ControlPosition = .bottom,
        showButtons: Bool = true,
        undoSide: UndoSide = .leading,
        defaultDirection: TraversalDirection = .older
    ) {
        self.position = position
        self.showButtons = showButtons
        self.undoSide = undoSide
        self.defaultDirection = defaultDirection
    }

    public static let `default` = ControlPreferences()

    private enum CodingKeys: String, CodingKey {
        case position
        case showButtons
        case undoSide
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
        try container.encode(defaultDirection, forKey: .defaultDirection)
    }
}

/// Pure geometry for the decision dock: how big each layout is, where it sits
/// at each of the three fixed positions, and the frame each destination marker
/// draws.
///
/// The dock has no grip: it is dragged by its whole surface, which is exactly
/// the controls plus the padding and gaps around them. Two layouts share the
/// three positions — at the bottom a labelled Delete/Keep pair in a tray with a
/// separate smaller Undo, at a side three separate icon controls with Undo as one
/// of them. The bottom pair keeps its own anchor whichever end Undo takes; a side
/// column is anchored as a whole, so Undo takes its top or bottom and the pair
/// sits above or below it (docs/SPEC.md §5.6). Kept in the framework rather than
/// only inside the SwiftUI view so the geometry the spec pins down is directly
/// testable on macOS.
public enum ControlClusterLayout {
    /// One side-layout icon control, and the height of one bottom pill.
    public static let controlSize: CGFloat = 56
    /// A side layout's controls stand apart: this gap between two of them is the
    /// functional non-action gap, part of the dock's handle and nothing more.
    public static let controlSpacing: CGFloat = 14
    /// A bottom pill's width. It is fixed so the dock never resizes with its
    /// label: the label scales inside the pill instead (docs/SPEC.md §5).
    public static let pillWidth: CGFloat = 104
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

    /// The bottom tray: the labelled Delete/Keep pair and the padding around it.
    public static var traySize: CGSize {
        CGSize(
            width: pillWidth * 2 + pillSpacing + trayInset * 2,
            height: controlSize + trayInset * 2
        )
    }

    /// The whole dock's size at a position: a labelled pair plus its separate
    /// Undo control at the bottom, three separate icon controls at a side.
    public static func clusterSize(for position: ControlPosition) -> CGSize {
        position.isVertical
            ? CGSize(width: controlSize, height: controlSize * 3 + controlSpacing * 2)
            : CGSize(width: undoControlSize + undoGap + traySize.width, height: traySize.height)
    }

    /// The anchor the dock occupies in a safe area of `size`.
    ///
    /// At the bottom the anchor is the labelled Delete/Keep pair's own centre:
    /// the separate Undo control hangs off one end of it, so changing which end
    /// Undo takes never moves Delete and Keep. At a side the anchor is the whole
    /// column's centre, and Undo is one of its three controls: it takes the top
    /// or the bottom of the column — above or below the pair, which is how the
    /// spec describes the two Undo ends — so the pair moves with the column
    /// rather than around Undo. Delete and Keep never move relative to each other
    /// in either layout (docs/SPEC.md §5.1 and §5.6).
    public static func centre(for position: ControlPosition, in size: CGSize) -> CGPoint {
        let cluster = clusterSize(for: position)
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
    /// column is the same rect whichever end Undo takes, because it holds all
    /// three of its controls.
    public static func slotRect(
        for position: ControlPosition,
        in size: CGSize,
        undoSide: UndoSide = .leading
    ) -> CGRect {
        let cluster = clusterSize(for: position)
        let anchor = centre(for: position, in: size)
        let origin: CGPoint
        if position.isVertical {
            // The column holds all three controls, Undo included, so the whole
            // column is the thing that is centred in the safe area.
            origin = CGPoint(x: anchor.x - cluster.width / 2, y: anchor.y - cluster.height / 2)
        } else {
            let pairHalf = traySize.width / 2
            let leading = undoSide == .leading
            origin = CGPoint(
                x: leading ? anchor.x - pairHalf - undoGap - undoControlSize : anchor.x - pairHalf,
                y: anchor.y - cluster.height / 2
            )
        }
        return CGRect(origin: origin, size: cluster)
    }
}
