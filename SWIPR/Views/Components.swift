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

/// A circular, floating control used over the full-screen photo.
struct CircleControl: View {
    let systemImage: String
    let label: String
    /// Defaults to `control.<label>`. Close names its own, because it lives in
    /// the top strip rather than on the decision cluster.
    var identifier: String?
    var tint: Color = .white
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
                .background(.ultraThinMaterial, in: Circle())
                .foregroundStyle(tint)
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                .frame(width: max(visualSize, hitSize), height: max(visualSize, hitSize))
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier ?? "control.\(label.lowercased())")
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
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .foregroundStyle(.white)
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier("topbar.\(label.lowercased())")
    }
}

/// The translucent material behind a swipe outcome well. It arms — brighter
/// fill, stronger stroke — the moment the drag crosses the commit threshold, so
/// the threshold is visible as well as felt.
struct WellBackground: View {
    let tint: Color
    let armed: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.opacity(armed ? 0.55 : 0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(armed ? 0.9 : 0.25), lineWidth: armed ? 3 : 1)
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
