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
    /// Whether the three buttons and their grip are drawn at all. Swipe gestures
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

/// Pure geometry for the control cluster: how big it is, where its centre sits
/// at each of the three fixed positions, and where its grip starts a drag.
///
/// Kept in the framework rather than only inside the SwiftUI view so the
/// geometry the spec pins down is directly testable on macOS.
public enum ControlClusterLayout {
    public static let controlSize: CGFloat = 64
    public static let controlSpacing: CGFloat = 10
    public static let trayInset: CGFloat = 12
    /// The grip's hit region. The drawn three dots are much smaller; this is the
    /// area that can be grabbed.
    public static let gripHitSize: CGFloat = 44
    /// How far the cluster stays from the safe-area edge.
    public static let edgeMargin: CGFloat = 20
    /// Columns are centred at this fraction of the safe-area height.
    public static let columnHeightFraction: CGFloat = 0.75

    // Motion values, here so a test can assert the bounce ceiling the spec sets.
    public static let landingBounce: Double = 0.12
    public static let landingDuration: Double = 0.32
    public static let reduceMotionDuration: Double = 0.16

    /// The cluster's size, including the tray's padding and the grip's slot.
    ///
    /// The short axis is 88 pt, as the spec pins it. The long axis grew past the
    /// spec's 228 pt once the grip moved into the tray's leading end; the 228
    /// described the three buttons alone, and is no longer the number the three
    /// positions depend on.
    public static func clusterSize(for position: ControlPosition) -> CGSize {
        let controls = controlSize * 3 + controlSpacing * 2
        let long = trayInset * 2 + gripHitSize + controlSpacing + controls
        let short = trayInset * 2 + controlSize
        return position.isVertical
            ? CGSize(width: short, height: long)
            : CGSize(width: long, height: short)
    }

    /// The cluster's centre in a safe area of `size`.
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
    /// at the end opposite the grip, and the user chooses which end.
    public enum ClusterControl: String, CaseIterable, Identifiable, Sendable {
        case grip
        case trash
        case keep
        case undo

        public var id: String { rawValue }
    }

    public static func order(for undoSide: UndoSide) -> [ClusterControl] {
        switch undoSide {
        case .leading: return [.undo, .trash, .keep, .grip]
        case .trailing: return [.grip, .trash, .keep, .undo]
        }
    }

    /// Where the grip sits: the outer end opposite Undo, in both orientations.
    /// A drag starts here, and the puck then follows the finger from this point.
    public static func gripCentre(
        for position: ControlPosition,
        in size: CGSize,
        undoSide: UndoSide
    ) -> CGPoint {
        let cluster = clusterSize(for: position)
        let centre = centre(for: position, in: size)
        let half = (position.isVertical ? cluster.height : cluster.width) / 2
        let offset = half - trayInset - gripHitSize / 2
        let gripIsLeading = undoSide == .trailing
        let signed = gripIsLeading ? -offset : offset
        return position.isVertical
            ? CGPoint(x: centre.x, y: centre.y + signed)
            : CGPoint(x: centre.x + signed, y: centre.y)
    }

    /// The rectangular area a slot occupies.
    public static func slotRect(for position: ControlPosition, in size: CGSize) -> CGRect {
        let cluster = clusterSize(for: position)
        let centre = centre(for: position, in: size)
        return CGRect(
            x: centre.x - cluster.width / 2,
            y: centre.y - cluster.height / 2,
            width: cluster.width,
            height: cluster.height
        )
    }

    /// The slot a puck released at `point` lands in, or `nil` when it is over
    /// none and the release must change nothing. When more than one slot
    /// contains the point, the nearest centre wins.
    public static func slot(
        at point: CGPoint,
        in size: CGSize,
        inflation: CGFloat = 20
    ) -> ControlPosition? {
        var best: (position: ControlPosition, distance: CGFloat)?
        for position in ControlPosition.allCases {
            let rect = slotRect(for: position, in: size).insetBy(dx: -inflation, dy: -inflation)
            guard rect.contains(point) else { continue }
            let centre = centre(for: position, in: size)
            let distance = hypot(point.x - centre.x, point.y - centre.y)
            if best == nil || distance < best!.distance {
                best = (position, distance)
            }
        }
        return best?.position
    }
}
