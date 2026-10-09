import SWIPRKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    statisticsSection

                    settingSection(title: "Controls") {
                        toggleRow(
                            title: "Show buttons",
                            subtitle: "Trash, Undo and Checkmark on the photo. Turning them off leaves swiping fully available.",
                            isOn: showButtonsBinding,
                            identifier: "settings.showButtons"
                        )
                        toggleRow(
                            title: "Haptics",
                            subtitle: "A light tap when a move captures a place and a soft one when it lands. Off silences every optional tap.",
                            isOn: hapticsBinding,
                            identifier: "settings.haptics"
                        )
                        positionChoices
                        undoPositionChoices
                        buttonRow(
                            systemImage: "hand.draw",
                            title: "Reset control position",
                            subtitle: "Brings the three buttons back to the bottom centre.",
                            identifier: "settings.resetControls"
                        ) {
                            var preferences = model.preferences
                            preferences.position = .bottom
                            model.updatePreferences(preferences)
                        }
                        Text("Swipe gestures are always available: drag left to delete or right to keep. Undo sits at an end of the buttons, away from Delete and Keep, and you can put it before or after them. Drag the buttons themselves — or the space between them — to move them to the bottom, left or right edge, and the photo never moves.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 6)
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
                        Text("Choose a photo walks in this direction, and SWIPR remembers it. Newest always begins at the newest photo.")
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

    // MARK: - Statistics

    /// Read-only, inline at the top, with no chevron: what the user has cleared
    /// is the first thing Settings should say, not something hidden behind a
    /// row.
    private var statisticsSection: some View {
        settingSection(title: "Statistics", titleIdentifier: "settings.statistics") {
            statisticsRow(
                title: "Photos deleted",
                value: "\(model.statistics.lifetimeDeletedCount)",
                identifier: "settings.statistics.lifetimeDeleted"
            )
            statisticsRow(
                title: "Storage reclaimed",
                value: storageText(model.statistics.lifetimeReclaimedBytes),
                identifier: "settings.statistics.lifetimeReclaimed"
            )
            statisticsRow(
                title: "Sessions completed",
                value: "\(model.statistics.lifetimeCompletedSessions)",
                identifier: "settings.statistics.sessions"
            )
            if model.resumableSession != nil {
                statisticsRow(
                    title: "This session",
                    value: "\(model.statistics.currentSessionDeletedCount) deleted · \(storageText(model.statistics.currentSessionReclaimedBytes))",
                    identifier: "settings.statistics.currentSession"
                )
            }
            Text("Only deletions confirmed by the system are counted. Storage figures are estimates.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    /// Storage is an estimate, so it is prefixed with "≈" — except at zero,
    /// where "≈ 0 bytes" reads worse than the plain truth.
    private func storageText(_ bytes: Int64) -> String {
        bytes == 0 ? ByteFormatter.string(fromBytes: 0) : "≈ \(ByteFormatter.string(fromBytes: bytes))"
    }

    private func statisticsRow(title: String, value: String, identifier: String) -> some View {
        let label = Text(title)
            .foregroundStyle(.white.opacity(0.85))
            .accessibilityIdentifier("\(identifier).label")
        let valueText = Text(value)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .accessibilityIdentifier(identifier)
        // At accessibility sizes the value is wide enough to squeeze the label
        // into mid-word breaks, so the two stack instead of sitting side by side.
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    label
                    valueText
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack {
                    label
                    Spacer()
                    valueText
                }
            }
        }
        .font(.body)
    }

    // MARK: - Controls

    private var positionChoices: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(ControlPosition.allCases) { position in
                positionRow(position)
            }
        }
    }

    private func positionRow(_ position: ControlPosition) -> some View {
        let isCurrent = model.preferences.position == position
        let subtitle: String
        switch position {
        case .bottom: subtitle = "A row centred near the bottom edge."
        case .leading: subtitle = "A column down the left edge."
        case .trailing: subtitle = "A column down the right edge."
        }
        return Button {
            var preferences = model.preferences
            preferences.position = position
            model.updatePreferences(preferences)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                selectionMark(isCurrent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Buttons at the \(position.title)")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.position.\(position.rawValue)")
        .accessibilityValue(isCurrent ? "Selected" : "")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    /// Where Undo sits, read relative to the Delete/Keep pair: **Before actions**
    /// (the default) or **After actions** (docs/SPEC.md §5.6).
    private var undoPositionChoices: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Undo position")
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            ForEach(UndoSide.allCases) { side in
                undoPositionRow(side)
            }
        }
    }

    private func undoPositionRow(_ side: UndoSide) -> some View {
        let isCurrent = model.preferences.undoSide == side
        let subtitle: String
        switch side {
        case .leading: subtitle = "Undo comes before Delete and Keep. This is the default."
        case .trailing: subtitle = "Undo comes after Delete and Keep."
        }
        return Button {
            var preferences = model.preferences
            preferences.undoSide = side
            model.updatePreferences(preferences)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                selectionMark(isCurrent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(side.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.undoSide.\(side.rawValue)")
        .accessibilityValue(isCurrent ? "Selected" : "")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    /// The chosen row of a group of choices. Visually the filled mark says which
    /// one it is; `accessibilityValue` says the same thing to VoiceOver, which
    /// is what announces the current position rather than just the options.
    private func selectionMark(_ isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
            .foregroundStyle(isSelected ? .blue : .white.opacity(0.4))
    }

    private var showButtonsBinding: Binding<Bool> {
        Binding(
            get: { model.preferences.showButtons },
            set: { newValue in
                var preferences = model.preferences
                preferences.showButtons = newValue
                model.updatePreferences(preferences)
            }
        )
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { model.preferences.haptics },
            set: { newValue in
                var preferences = model.preferences
                preferences.haptics = newValue
                model.updatePreferences(preferences)
            }
        )
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

    private func toggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        identifier: String
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(.green)
        .padding(.vertical, 6)
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

    private func settingSection<Content: View>(
        title: String,
        titleIdentifier: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
                .accessibilityIdentifier(titleIdentifier ?? title)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
