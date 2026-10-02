import SWIPRKit
import SwiftUI

/// Editable filters for the next sorting session.
///
/// A Home media choice opens this screen with a documented preset already
/// applied. Each of the five categories toggles independently, **Only** isolates
/// one category, and the plain-language summary plus matching count lets the
/// user verify the pool before **Continue** captures it. Nothing is written
/// until a session actually starts, so this screen can be explored freely.
struct FilterView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var palette: PorcelainPalette { .forScheme(colorScheme) }

    private var isContinueDisabled: Bool {
        model.filter.isEmpty || model.filteredCount == 0
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    presets
                    categoryHeader
                    categoryRows
                    summary
                    if model.filteredCount == 0 {
                        emptyNote
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .scrollBounceBehavior(.basedOnSize)
            continueBar
        }
        .background(palette.background)
    }

    // MARK: - Chrome

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
            .accessibilityIdentifier("filter.back")

            Spacer(minLength: 0)

            Text("What's included?")
                .font(.headline)
                .foregroundStyle(palette.foreground)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Color.clear.frame(width: 44, height: 44)
        }
        .foregroundStyle(palette.foreground)
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    // MARK: - Presets

    /// The three documented starting points. Choosing one replaces the whole
    /// selection, so a previous attempt's exclusions never leak in.
    private var presets: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    presetButton(.everything, title: "Everything")
                    presetButton(.photos, title: "Photos")
                    presetButton(.videos, title: "Videos")
                }
            } else {
                HStack(spacing: 8) {
                    presetButton(.everything, title: "Everything")
                    presetButton(.photos, title: "Photos")
                    presetButton(.videos, title: "Videos")
                }
            }
        }
    }

    private func presetButton(_ preset: MediaFilter, title: String) -> some View {
        let isSelected = model.filter.categories == preset.categories
        return Button {
            model.showFilters(preset)
        } label: {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                isSelected ? palette.accent : palette.elevated,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .foregroundStyle(isSelected ? palette.onAccent : palette.foreground)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("filter.preset.\(presetIdentifier(preset))")
    }

    private func presetIdentifier(_ preset: MediaFilter) -> String {
        if preset.categories == MediaFilter.everything.categories { return "everything" }
        if preset.categories == MediaFilter.photos.categories { return "photos" }
        if preset.categories == MediaFilter.videos.categories { return "videos" }
        return "custom"
    }

    // MARK: - Categories

    private var categoryHeader: some View {
        HStack {
            Text("Categories")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.secondary)
            Spacer(minLength: 0)
            Button("Clear") {
                model.clearFilter()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(model.filter.isEmpty ? palette.secondary : palette.accent)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("filter.clear")
        }
    }

    private var categoryRows: some View {
        VStack(spacing: 10) {
            ForEach(MediaCategory.allCases, id: \.self) { category in
                categoryRow(category)
            }
        }
    }

    private func categoryRow(_ category: MediaCategory) -> some View {
        let isSelected = model.filter.contains(category)
        let matching = categoryCounts[category] ?? 0
        return HStack(spacing: 10) {
            Button {
                model.toggleFilterCategory(category)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(isSelected ? palette.accent : palette.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(for: category))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(palette.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(matching) \(matching == 1 ? "item" : "items")")
                            .font(.footnote)
                            .foregroundStyle(palette.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("filter.toggle.\(category.rawValue)")
            .accessibilityLabel(title(for: category))
            .accessibilityValue(isSelected ? "Included" : "Excluded")

            Button("Only") {
                model.onlyFilterCategory(category)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(palette.accent)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("filter.only.\(category.rawValue)")
            .accessibilityLabel("Only \(title(for: category))")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
    }

    /// How many library assets carry each category, regardless of the current
    /// selection, so a row's count does not change as other rows toggle.
    private var categoryCounts: [MediaCategory: Int] {
        var counts: [MediaCategory: Int] = [:]
        for asset in model.order.assets {
            for category in asset.categories {
                counts[category, default: 0] += 1
            }
        }
        return counts
    }

    private func title(for category: MediaCategory) -> String {
        switch category {
        case .screenshot: return "Screenshots"
        case .livePhoto: return "Live Photos"
        case .panorama: return "Panoramas"
        case .otherPhoto: return "Other Photos"
        case .video: return "Videos"
        }
    }

    // MARK: - Summary and Continue

    private var summary: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle")
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)
            Text(model.filterSummary)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.foreground)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("filter.summary")
    }

    private var emptyNote: some View {
        Text("Nothing matches these filters. Turn a category back on to continue.")
            .font(.footnote)
            .foregroundStyle(palette.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("filter.empty")
    }

    private var continueBar: some View {
        Button {
            model.continueToChoosePhoto()
        } label: {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    isContinueDisabled ? palette.elevated : palette.accent,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .foregroundStyle(isContinueDisabled ? palette.secondary : palette.onAccent)
        }
        .buttonStyle(.plain)
        .disabled(isContinueDisabled)
        .accessibilityIdentifier("filter.continue")
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(palette.background)
    }
}
