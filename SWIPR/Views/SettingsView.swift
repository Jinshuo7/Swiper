import SWIPRKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    settingSection(title: "Interaction") {
                        ForEach(ControlPreset.selectable) { preset in
                            presetRow(preset)
                        }
                        Text("Trash, Undo and Checkmark are always on the photo.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 6)
                    }

                    settingSection(title: "Controls") {
                        buttonRow(
                            systemImage: "hand.draw",
                            title: "Reset control position",
                            subtitle: "Docked to the \(model.preferences.rail.title) edge. Brings the three buttons back to the bottom centre.",
                            identifier: "settings.resetControls"
                        ) {
                            var preferences = model.preferences
                            preferences.rail = .bottom
                            preferences.position = 0.5
                            model.updatePreferences(preferences)
                        }
                        Text("Touch and hold the buttons on a photo to move them. They dock to the bottom, left or right edge, and SWIPR remembers where you put them.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 6)
                    }

                    settingSection(title: "Statistics") {
                        buttonRow(
                            systemImage: "chart.pie",
                            title: "Deletion statistics",
                            subtitle: "Confirmed deletions and estimated storage reclaimed.",
                            identifier: "settings.statistics"
                        ) {
                            model.route = .statistics
                        }
                    }

                    settingSection(title: "Help") {
                        buttonRow(
                            systemImage: "questionmark.circle",
                            title: "How to use SWIPR",
                            subtitle: "Replay the explanation of marking, keeping, review and saving.",
                            identifier: "settings.howToUse"
                        ) {
                            model.replayTutorial()
                        }
                    }

                    settingSection(title: "Default direction") {
                        Picker("Default direction", selection: directionBinding) {
                            Text("Older first").tag(TraversalDirection.older)
                            Text("Newer first").tag(TraversalDirection.newer)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("settings.direction")
                        Text("Start Here walks in this direction, and SWIPR remembers it. Recent always begins at the newest photo.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(20)
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                model.route = .entry
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back")
            Spacer()
            Text("Settings")
                .font(.headline)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    private func presetRow(_ preset: ControlPreset) -> some View {
        Button {
            var preferences = model.preferences
            preferences.preset = preset
            model.updatePreferences(preferences)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: model.preferences.preset == preset ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(model.preferences.preset == preset ? .blue : .white.opacity(0.4))
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(preset.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.preset.\(preset.rawValue)")
    }

    /// A tappable row that opens something or does one thing. Buttons carry
    /// their own identifiers, which a segmented `Picker` does not expose.
    private func buttonRow(
        systemImage: String,
        title: String,
        subtitle: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private var directionBinding: Binding<TraversalDirection> {
        Binding(
            get: { model.preferences.defaultDirection },
            set: { newValue in
                var preferences = model.preferences
                preferences.defaultDirection = newValue
                model.updatePreferences(preferences)
            }
        )
    }

    private func settingSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
