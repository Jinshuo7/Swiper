import SwiftUI

/// The app's primary button look: full-width, high contrast, generous tap area.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
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
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 56, height: 56)
                .background(.ultraThinMaterial, in: Circle())
                .foregroundStyle(tint)
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier("control.\(label.lowercased())")
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
