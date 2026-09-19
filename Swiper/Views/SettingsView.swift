import SwiperKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    settingSection(title: "Interaction") {
                        ForEach(ControlPreset.allCases) { preset in
                            presetRow(preset)
                        }
                    }

                    settingSection(title: "Control placement") {
                        Picker("Control placement", selection: placementBinding) {
                            ForEach(ControlPlacement.allCases) { placement in
                                Text(placement.title).tag(placement)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("settings.placement")
                    }

                    settingSection(title: "Default direction") {
                        Picker("Default direction", selection: directionBinding) {
                            Text("Older first").tag(TraversalDirection.older)
                            Text("Newer first").tag(TraversalDirection.newer)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("settings.direction")
                        Text("Swiper starts toward older photos and remembers your choice for the next session.")
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

    private var placementBinding: Binding<ControlPlacement> {
        Binding(
            get: { model.preferences.placement },
            set: { newValue in
                var preferences = model.preferences
                preferences.placement = newValue
                model.updatePreferences(preferences)
            }
        )
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
