import CoreGraphics
import Foundation

/// Pure geometry for directly moving the decision dock between its three fixed
/// positions (left, bottom, right).
///
/// Production v1 replaces the grip/puck/slot mechanism with a drag that starts
/// anywhere in the dock and moves the whole dock (`docs/adr/0007` amended). This
/// type owns only the arithmetic: when a drag stops being a tap, which
/// destination it has captured (with hysteresis so a held dock does not
/// flicker), and where the dock sits. It imports no SwiftUI, so the gesture
/// rules are directly testable on macOS.
public enum DockGeometry {
    /// Movement below this many points is still a tap, so a Delete, Keep or Undo
    /// button is never stolen by an unsteady finger.
    public static let tapCancelThreshold: CGFloat = 9
    /// The finger captures a destination once it is within this distance of the
    /// destination's centre.
    public static let captureRadius: CGFloat = 72
    /// After a capture, the finger must leave this larger distance before the
    /// dock is released, so a dock held near the boundary does not flicker
    /// between captured and free.
    public static let releaseRadius: CGFloat = 96

    /// The dock centre at a destination in a safe area of `size`. The three
    /// destinations are the fixed stops the dock may occupy.
    public static func centre(for position: ControlPosition, in size: CGSize) -> CGPoint {
        ControlClusterLayout.centre(for: position, in: size)
    }

    /// Whether a drag from `start` to `current` has moved far enough to cancel
    /// the pending tap for that gesture.
    public static func cancelsTap(from start: CGPoint, to current: CGPoint) -> Bool {
        distance(from: start, to: current) > tapCancelThreshold
    }

    /// The destination a finger at `point` captures, given the destination
    /// currently captured (`nil` while free).
    ///
    /// A newly captured destination uses ``captureRadius``; keeping one already
    /// captured uses the larger ``releaseRadius``. Returns `nil` when the finger
    /// is outside the applicable radius, so the dock is free again.
    public static func capture(
        at point: CGPoint,
        in size: CGSize,
        currentlyCaptured: ControlPosition?
    ) -> ControlPosition? {
        guard let nearest = nearestDestination(to: point, in: size) else { return nil }
        let radius = currentlyCaptured == nearest ? releaseRadius : captureRadius
        return distance(from: point, to: centre(for: nearest, in: size)) <= radius ? nearest : nil
    }

    /// The destination a release at `point` lands in, or `nil` when the release
    /// must restore the source because nothing is captured any more.
    public static func destination(
        forReleaseAt point: CGPoint,
        in size: CGSize,
        captured: ControlPosition?
    ) -> ControlPosition? {
        guard let captured else { return nil }
        return capture(at: point, in: size, currentlyCaptured: captured) == captured ? captured : nil
    }

    /// The destination whose centre is nearest to `point`, or `nil` when the
    /// safe area is empty.
    public static func nearestDestination(to point: CGPoint, in size: CGSize) -> ControlPosition? {
        guard size.width > 0, size.height > 0 else { return nil }
        return ControlPosition.allCases.min { left, right in
            squaredDistance(from: point, to: centre(for: left, in: size))
                < squaredDistance(from: point, to: centre(for: right, in: size))
        }
    }

    private static func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        sqrt(squaredDistance(from: a, to: b))
    }

    private static func squaredDistance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }
}
