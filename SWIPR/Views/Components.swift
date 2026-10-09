import SWIPRKit
import SwiftUI

/// The app's primary button look: full-width, high contrast, generous tap area.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            // At accessibility text sizes a one-line label like "Delete 1 photo"
            // is wider than the screen, so it wraps before it scales — a
            // truncated primary action says less than nothing.
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(configuration.isPressed ? Color.white.opacity(0.85) : Color.white)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.white.opacity(configuration.isPressed ? 0.18 : 0.1))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }
}

/// Applies the primary or secondary look based on a runtime flag.
struct AdaptiveButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        if isPrimary {
            PrimaryButtonStyle().makeBody(configuration: configuration)
        } else {
            SecondaryButtonStyle().makeBody(configuration: configuration)
        }
    }
}

/// The only red and green in the viewer: a faint, desaturated glow along a
/// control's own edges (docs/SPEC.md §4.3). It is drawn at the same strength in
/// every state, because saturation never carries a meaning — the symbol, the
/// word, the stroke weight and the scale do — so these two values stay barely
/// visible on purpose.
enum DockEdgeTint {
    /// Delete: a dusty, desaturated red that never reads as an alarm.
    static let delete = Color(red: 0.74, green: 0.48, blue: 0.45)
    /// Keep: the matching desaturated green.
    static let keep = Color(red: 0.47, green: 0.60, blue: 0.49)
}

/// The edge illumination itself: the tint at the leading and trailing rim, and
/// nothing in between, so the middle of a control always stays neutral glass.
private func dockEdgeGlow(_ tint: Color) -> LinearGradient {
    LinearGradient(
        stops: [
            .init(color: tint.opacity(0.16), location: 0),
            .init(color: tint.opacity(0), location: 0.3),
            .init(color: tint.opacity(0), location: 0.7),
            .init(color: tint.opacity(0.16), location: 1),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

/// The neutral chrome one dock control wears: glass, a hairline white edge, and
/// — for Delete and Keep only — the extremely faint desaturated edge glow above.
///
/// Undo and the moving token pass `nil`, because neither is an outcome and
/// neither is allowed to lean on colour.
struct DockControlBackground<Shape: InsettableShape>: View {
    let shape: Shape
    /// The control's faint edge glow, or `nil` for a neutral part of the dock.
    var edgeTint: Color?

    var body: some View {
        shape
            .fill(.ultraThinMaterial)
            .overlay {
                if let edgeTint {
                    shape.fill(dockEdgeGlow(edgeTint))
                }
            }
            .overlay(
                shape.strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            )
    }
}

/// A circular, floating control used over the full-screen photo.
struct CircleControl: View {
    let systemImage: String
    let label: String
    /// Defaults to `control.<label>`. Close names its own, because it lives in
    /// the top strip rather than on the decision cluster.
    var identifier: String?
    var tint: Color = .white
    /// The faint desaturated edge glow for Delete and Keep; `nil` keeps a
    /// control neutral.
    var edgeTint: Color?
    /// The drawn circle, and the tap region around it. Close is drawn smaller
    /// than the decision controls but keeps a full 44 pt tap region.
    var visualSize: CGFloat = 56
    var hitSize: CGFloat = 56
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: visualSize * 0.39, weight: .semibold))
                .frame(width: visualSize, height: visualSize)
                .background(DockControlBackground(shape: Circle(), edgeTint: edgeTint))
                .foregroundStyle(tint)
                .frame(width: max(visualSize, hitSize), height: max(visualSize, hitSize))
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier ?? "control.\(label.lowercased())")
    }
}

/// One labelled action of the bottom dock: the symbol and the word carry the
/// action, and the only colour is the faint desaturated edge glow shared with
/// the side layout's controls.
///
/// The pill takes the width the tray gives it — the tray is fixed for its screen
/// width, so the dock never resizes with its content or its state — and the label
/// stops growing rather than truncating.
struct DecisionPill: View {
    /// The dock is a fixed-geometry control (docs/SPEC.md §5), so its own label
    /// grows a little with Dynamic Type and then stops: a wider pill is not an
    /// option, and a truncated action says less than nothing. The full action
    /// name is always spoken by the control's accessibility label.
    @ScaledMetric(relativeTo: .subheadline) private var scaledLabelSize: CGFloat = 15

    let systemImage: String
    let title: String
    let edgeTint: Color
    var identifier: String
    let action: () -> Void

    private var labelSize: CGFloat { min(scaledLabelSize, 20) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: labelSize, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                DockControlBackground(
                    shape: RoundedRectangle(
                        cornerRadius: ControlClusterLayout.controlSize / 2,
                        style: .continuous
                    ),
                    edgeTint: edgeTint
                )
            )
        }
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }
}

struct TopBarButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .foregroundStyle(.white)
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier("topbar.\(label.lowercased())")
    }
}

/// The translucent material behind a swipe outcome well. It arms — heavier
/// stroke, a little scale and the drag's own opacity — the moment the drag
/// crosses the commit threshold, so the threshold is visible as well as felt.
///
/// `tint` is one of the faint desaturated `DockEdgeTint` values, and it stays a
/// rim at the same strength in both states: the well's symbol and its wording
/// carry the outcome, and its outline carries the threshold (docs/SPEC.md §4.3).
struct WellBackground: View {
    let tint: Color
    let armed: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        shape
            .fill(.ultraThinMaterial)
            .overlay(shape.fill(dockEdgeGlow(tint)))
            .overlay(
                shape.stroke(Color.white.opacity(armed ? 0.9 : 0.25), lineWidth: armed ? 3 : 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
    }
}

/// The confirmation between the user and discarding an unfinished session.
///
/// It states the one consequence that matters — the current position and Undo
/// history are replaced while marked items stay in Review — and offers the two
/// ways out. It is a plain card rather than a system alert so the explanation and
/// both actions stay legible at every text size and in both appearances.
struct ReplacementConfirmationView: View {
    @Environment(\.colorScheme) private var colorScheme
    let onKeepCurrent: () -> Void
    let onStartNew: () -> Void

    private var palette: PorcelainPalette { .forScheme(colorScheme) }

    var body: some View {
        ZStack {
            // Tapping the dimmed backdrop is the safe choice: it keeps the
            // session rather than replacing it.
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onKeepCurrent)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Start a new session?")
                            .font(.headline)
                            .foregroundStyle(palette.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Starting a new session replaces your current position and Undo history. Photos you marked for deletion stay in Review.")
                            .font(.footnote)
                            .foregroundStyle(palette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(spacing: 10) {
                    Button("Keep current", action: onKeepCurrent)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(palette.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(palette.foreground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(palette.border, lineWidth: 1)
                        )
                        .accessibilityIdentifier("replaceSession.keep")

                    Button("Start new", action: onStartNew)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(palette.onAccent)
                        .accessibilityIdentifier("replaceSession.startNew")
                }
            }
            .padding(22)
            .frame(maxWidth: 420)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 24, y: 8)
            .padding(24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("replaceSession.confirmation")
    }
}

/// A card that tells the user, in plain words, that something they did was not
/// saved — and gives them the one action that can fix it. Never used to imply
/// that unsaved work was accepted.
struct PersistenceBanner: View {
    let systemImage: String
    let title: String
    let message: String
    let primaryTitle: String
    let primaryAction: () -> Void
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                Button(primaryTitle, action: primaryAction)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
                if let secondaryTitle, let secondaryAction {
                    Button(secondaryTitle, action: secondaryAction)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.12))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .frame(maxWidth: 460)
    }
}
