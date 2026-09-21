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

                    settingSection(title: "Control rail") {
                        ForEach(ControlRail.allCases) { rail in
                            optionRow(
                                title: rail.title,
                                subtitle: rail.subtitle,
                                isSelected: model.preferences.rail == rail,
                                identifier: "settings.rail.\(rail.rawValue)"
                            ) {
                                var preferences = model.preferences
                                preferences.rail = rail
                                model.updatePreferences(preferences)
                            }
                        }

                        Text("Position on the rail")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 6)

                        ForEach(ControlAnchor.allCases) { anchor in
                            optionRow(
                                title: anchor.title(for: model.preferences.rail),
                                subtitle: nil,
                                isSelected: model.preferences.anchor == anchor,
                                identifier: "settings.anchor.\(anchor.rawValue)"
                            ) {
                                var preferences = model.preferences
                                preferences.anchor = anchor
                                model.updatePreferences(preferences)
                            }
                        }

                        Text("Order on the rail")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 6)

                        ForEach(ControlOrder.allCases) { order in
                            optionRow(
                                title: order.title,
                                subtitle: order.subtitle,
                                isSelected: model.preferences.order == order,
                                identifier: "settings.order.\(order.rawValue)"
                            ) {
                                var preferences = model.preferences
                                preferences.order = order
                                model.updatePreferences(preferences)
                            }
                        }

                        Text("Every control lives on this one rail, so it never moves between photos. Pick the edge your thumb reaches; a left-handed grip usually wants the left side, a right-handed one the right side or the bottom.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 6)
                    }

                    settingSection(title: "Statistics") {
                        Button {
                            model.route = .statistics
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "chart.pie")
                                    .foregroundStyle(.white)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Deletion statistics")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                    Text("Confirmed deletions and estimated storage reclaimed.")
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
                        .accessibilityIdentifier("settings.statistics")
                    }

                    settingSection(title: "Help") {
                        Button {
                            model.replayTutorial()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "questionmark.circle")
                                    .foregroundStyle(.white)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("How to use Swiper")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                    Text("Replay the explanation of marking, keeping, review and saving.")
                                        .font(.footnote)
                                        .foregroundStyle(.white.opacity(0.6))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.howToUse")
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

    /// A labelled choice row. Buttons carry their own identifiers, which a
    /// segmented `Picker` does not expose — and it matches the preset list above.
    private func optionRow(
        title: String,
        subtitle: String?,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.blue : Color.white.opacity(0.4))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
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
