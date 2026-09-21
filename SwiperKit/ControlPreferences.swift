import Foundation

/// The interaction styles the user can choose between.
///
/// Presets exist so nobody is forced into large thumb movement. Every preset
/// keeps the photo edge-to-edge; they only change which controls are shown.
public enum ControlPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Full-screen gestures: swipe left to mark for deletion, swipe right to
    /// keep, swipe horizontally to decide. No large on-screen buttons.
    case swipe
    /// A floating cluster with Keep and Delete.
    case thumb
    /// Only a Delete control; advancing (tap/swipe) keeps the photo.
    case deleteOnly
    /// Keep, Delete, Favorite and Undo are all present.
    case extended

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .swipe: return "Swipe"
        case .thumb: return "Thumb"
        case .deleteOnly: return "Delete only"
        case .extended: return "Extended"
        }
    }

    public var subtitle: String {
        switch self {
        case .swipe: return "Swipe left to delete and right to keep."
        case .thumb: return "Floating Keep and Delete buttons within thumb reach."
        case .deleteOnly: return "Only delete is a button; advancing keeps the photo."
        case .extended: return "Keep, Delete, Favorite and Undo buttons."
        }
    }

    public var usesSwipeGestures: Bool { self == .swipe }
    public var showsKeepButton: Bool { self == .thumb || self == .extended }
    public var showsDeleteButton: Bool { self == .thumb || self == .deleteOnly || self == .extended }
    public var showsFavoriteButton: Bool { self == .extended }
    public var showsUndoButton: Bool { self == .extended }
    /// Whether this preset puts any decision control on screen at all. When it
    /// does not, the rail is hidden and the gestures carry the whole flow.
    public var showsAnyDecisionControl: Bool {
        showsKeepButton || showsDeleteButton || showsFavoriteButton || showsUndoButton
    }
}

/// Which edge the controls live on.
///
/// One rail carries every control so the targets never move between photos or
/// mid-session. Which edge it sits on is the handedness choice: a right-handed
/// person reaches the bottom or right rail with a thumb, a left-handed person
/// the bottom or left one.
public enum ControlRail: String, Codable, CaseIterable, Identifiable, Sendable {
    /// A horizontal rail along the bottom edge.
    case bottom
    /// A vertical rail down the left edge.
    case leading
    /// A vertical rail down the right edge.
    case trailing

    public var id: String { rawValue }
    public var isVertical: Bool { self != .bottom }

    public var title: String {
        switch self {
        case .bottom: return "Bottom"
        case .leading: return "Left side"
        case .trailing: return "Right side"
        }
    }

    public var subtitle: String {
        switch self {
        case .bottom: return "A row of controls along the bottom edge."
        case .leading: return "A column down the left edge, for a left thumb."
        case .trailing: return "A column down the right edge, for a right thumb."
        }
    }
}

/// Which end of the rail the decisions sit at.
///
/// The order is the second half of the handedness choice. A right thumb reaches
/// the *end* of a bottom rail and the *bottom* of a side rail, so decisions go
/// there by default. A left thumb on a bottom rail reaches the other end, which
/// is what `.decisionsFirst` is for.
public enum ControlOrder: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Close, Favorite, Undo, then the decision pair, with Keep last.
    case closeFirst
    /// The mirror image: Keep first, then Delete, Undo, Favorite, Close last.
    case keepFirst

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .closeFirst: return "Close first"
        case .keepFirst: return "Keep first"
        }
    }

    public var subtitle: String {
        switch self {
        case .closeFirst: return "Close at the far end, Keep nearest your thumb."
        case .keepFirst: return "Keep at the near end instead, for a left thumb on a bottom rail."
        }
    }
}

/// Where the rail sits along its edge.
public enum ControlAnchor: String, Codable, CaseIterable, Identifiable, Sendable {
    case start
    case center
    case end

    public var id: String { rawValue }

    /// The wording depends on the rail: "Start" is left on a bottom rail and top
    /// on a vertical one.
    public func title(for rail: ControlRail) -> String {
        switch (rail.isVertical, self) {
        case (true, .start): return "Top"
        case (true, .center): return "Middle"
        case (true, .end): return "Bottom"
        case (false, .start): return "Left"
        case (false, .center): return "Centre"
        case (false, .end): return "Right"
        }
    }
}

/// The user's persisted interaction preferences.
public struct ControlPreferences: Codable, Equatable, Sendable {
    public var preset: ControlPreset
    /// Which edge the controls sit on.
    public var rail: ControlRail
    /// Where along that edge they sit.
    public var anchor: ControlAnchor
    /// Which end of the rail the decisions sit at.
    public var order: ControlOrder
    /// Direction a new session starts in. Swiper always starts out toward
    /// older photos; the user can change this and it is remembered.
    public var defaultDirection: TraversalDirection

    public init(
        preset: ControlPreset = .swipe,
        rail: ControlRail = .bottom,
        anchor: ControlAnchor = .center,
        order: ControlOrder = .closeFirst,
        defaultDirection: TraversalDirection = .older
    ) {
        self.preset = preset
        self.rail = rail
        self.anchor = anchor
        self.order = order
        self.defaultDirection = defaultDirection
    }

    public static let `default` = ControlPreferences()

    // MARK: - Storage

    /// The placement preference written before the rail existed. It is kept only
    /// so an existing choice carries over instead of being silently reset.
    private enum LegacyPlacement: String, Codable {
        case left
        case center
        case right
    }

    private enum CodingKeys: String, CodingKey {
        case preset
        case rail
        case anchor
        case order
        case defaultDirection
        case placement
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preset = try container.decodeIfPresent(ControlPreset.self, forKey: .preset) ?? .swipe
        order = try container.decodeIfPresent(ControlOrder.self, forKey: .order) ?? .closeFirst
        defaultDirection = try container.decodeIfPresent(TraversalDirection.self, forKey: .defaultDirection) ?? .older

        if let storedRail = try container.decodeIfPresent(ControlRail.self, forKey: .rail) {
            rail = storedRail
            anchor = try container.decodeIfPresent(ControlAnchor.self, forKey: .anchor) ?? .center
        } else {
            // Older state: a three-way horizontal placement on an implicit
            // bottom rail. Keep the user's choice as the anchor.
            rail = .bottom
            switch try container.decodeIfPresent(LegacyPlacement.self, forKey: .placement) {
            case .left: anchor = .start
            case .right: anchor = .end
            case .center, .none: anchor = .center
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(preset, forKey: .preset)
        try container.encode(rail, forKey: .rail)
        try container.encode(anchor, forKey: .anchor)
        try container.encode(order, forKey: .order)
        try container.encode(defaultDirection, forKey: .defaultDirection)
    }
}
