import Foundation

/// The interaction styles the user can choose between.
///
/// Presets exist so nobody is forced into large thumb movement. Every preset
/// keeps the photo edge-to-edge; they only change which controls are shown.
public enum ControlPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Full-screen gestures: swipe left to queue deletion, swipe right to keep,
    /// swipe horizontally to decide. No large on-screen buttons.
    case swipe
    /// A floating cluster with Keep and Delete at thumb height.
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
}

/// Where the floating controls sit, for left- or right-handed use.
public enum ControlPlacement: String, Codable, CaseIterable, Identifiable, Sendable {
    case left
    case center
    case right

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .left: return "Left"
        case .center: return "Center"
        case .right: return "Right"
        }
    }
}

/// The user's persisted interaction preferences.
public struct ControlPreferences: Codable, Equatable, Sendable {
    public var preset: ControlPreset
    public var placement: ControlPlacement
    /// Direction a new session starts in. Swiper always starts out toward
    /// older photos; the user can change this and it is remembered.
    public var defaultDirection: TraversalDirection

    public init(
        preset: ControlPreset = .swipe,
        placement: ControlPlacement = .center,
        defaultDirection: TraversalDirection = .older
    ) {
        self.preset = preset
        self.placement = placement
        self.defaultDirection = defaultDirection
    }

    public static let `default` = ControlPreferences()
}
