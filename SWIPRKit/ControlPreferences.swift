import Foundation

/// The interaction styles the user can choose between.
///
/// Every preset keeps the same three controls on the rail: Trash, Undo and
/// Checkmark. The preset decides only whether dragging the photo decides
/// anything, because the buttons are always the non-gesture way to act.
public enum ControlPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Full-screen gestures: drag left to delete, drag right to keep. The three
    /// rail controls work as well.
    case swipe
    /// Dragging decides nothing, so a stray swipe can never mark a photo.
    case thumb
    /// Like ``thumb``, and a tap on the photo keeps it.
    case deleteOnly
    /// The old name for ``swipe``. It is kept so saved preferences still decode,
    /// and it is no longer offered in Settings.
    case extended

    public var id: String { rawValue }

    /// The presets worth offering. `extended` became a synonym for `swipe` once
    /// the rail's controls stopped varying by preset.
    public static let selectable: [ControlPreset] = [.swipe, .thumb, .deleteOnly]

    public var title: String {
        switch self {
        case .swipe, .extended: return "Swipe"
        case .thumb: return "Buttons only"
        case .deleteOnly: return "Tap to keep"
        }
    }

    public var subtitle: String {
        switch self {
        case .swipe, .extended:
            return "Drag left to delete or right to keep. The three controls work too."
        case .thumb:
            return "Dragging decides nothing, so a stray swipe can never mark a photo."
        case .deleteOnly:
            return "Dragging decides nothing, and tapping the photo keeps it."
        }
    }

    /// Whether a horizontal drag on the photo decides keep or delete.
    public var usesSwipeGestures: Bool { self == .swipe || self == .extended }

    /// Whether tapping the photo is also a way to keep it.
    public var tapToKeep: Bool { self == .deleteOnly }
}

/// Which edge the three controls dock to.
///
/// The user picks it by dragging the cluster: dropping it against the left or
/// right edge docks it there as a column, and anywhere else docks it along the
/// bottom as a row. The edge and the position along it are remembered.
public enum ControlRail: String, Codable, CaseIterable, Identifiable, Sendable {
    /// A horizontal row along the bottom edge.
    case bottom
    /// A vertical column down the left edge.
    case leading
    /// A vertical column down the right edge.
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
}

/// The user's persisted interaction preferences.
public struct ControlPreferences: Codable, Equatable, Sendable {
    public var preset: ControlPreset
    /// Which edge the controls dock to.
    public var rail: ControlRail
    /// How far along that edge the cluster sits: 0 at the start end (the left of
    /// a bottom row, the top of a column), 1 at the end, 0.5 centred. The user
    /// sets it by dragging the cluster, so it is continuous rather than one of
    /// three stops, and it is clamped whenever it is read or written.
    public var position: Double
    /// Direction a new session starts in. SWIPR always starts out toward
    /// older photos; the user can change this and it is remembered.
    public var defaultDirection: TraversalDirection

    public init(
        preset: ControlPreset = .swipe,
        rail: ControlRail = .bottom,
        position: Double = 0.5,
        defaultDirection: TraversalDirection = .older
    ) {
        self.preset = preset
        self.rail = rail
        self.position = ControlPreferences.clamped(position)
        self.defaultDirection = defaultDirection
    }

    public static let `default` = ControlPreferences()

    /// Keeps a dragged or decoded position usable: finite, and inside 0...1.
    public static func clamped(_ position: Double) -> Double {
        guard position.isFinite else { return 0.5 }
        return min(max(position, 0), 1)
    }

    // MARK: - Storage

    /// The three-way horizontal placement written before the rail existed. It is
    /// kept only so an existing choice carries over instead of being reset.
    private enum LegacyPlacement: String, Codable {
        case left
        case center
        case right
    }

    /// The three stops the rail used before the cluster could be dragged.
    private enum LegacyAnchor: String, Codable {
        case start
        case center
        case end
    }

    private enum CodingKeys: String, CodingKey {
        case preset
        case rail
        case position
        case defaultDirection
        case placement
        case anchor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preset = try container.decodeIfPresent(ControlPreset.self, forKey: .preset) ?? .swipe
        defaultDirection = try container.decodeIfPresent(TraversalDirection.self, forKey: .defaultDirection) ?? .older
        rail = try container.decodeIfPresent(ControlRail.self, forKey: .rail) ?? .bottom

        if let storedPosition = try container.decodeIfPresent(Double.self, forKey: .position) {
            position = ControlPreferences.clamped(storedPosition)
        } else if let anchor = try container.decodeIfPresent(LegacyAnchor.self, forKey: .anchor) {
            // An older choice of one of three stops becomes a continuous position.
            position = ControlPreferences.legacyPosition(start: anchor == .start, end: anchor == .end)
        } else if let placement = try container.decodeIfPresent(LegacyPlacement.self, forKey: .placement) {
            position = ControlPreferences.legacyPosition(start: placement == .left, end: placement == .right)
        } else {
            position = 0.5
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(preset, forKey: .preset)
        try container.encode(rail, forKey: .rail)
        try container.encode(position, forKey: .position)
        try container.encode(defaultDirection, forKey: .defaultDirection)
    }

    private static func legacyPosition(start: Bool, end: Bool) -> Double {
        if start { return 0 }
        if end { return 1 }
        return 0.5
    }
}
