import SWIPRKit
import SwiftUI

/// Orange & Porcelain semantic colours for the Home and filter screens.
///
/// Explicit light and dark values, rather than system colours, keep the
/// porcelain look identical on every iOS version and let a screen render in
/// either appearance on demand. Both appearances share one warm orange accent
/// and one cream/near-black ground.
struct PorcelainPalette {
    let background: Color
    let surface: Color
    let elevated: Color
    let foreground: Color
    let secondary: Color
    let border: Color
    let accent: Color
    let accentSoft: Color
    let onAccent: Color

    static let light = PorcelainPalette(
        background: Color(red: 0.988, green: 0.965, blue: 0.937), // #FCF6EF
        surface: Color(red: 1.0, green: 1.0, blue: 1.0),
        elevated: Color(red: 0.949, green: 0.925, blue: 0.894),   // #F2ECE4
        foreground: Color(red: 0.106, green: 0.106, blue: 0.106), // #1B1B1B
        secondary: Color(red: 0.431, green: 0.416, blue: 0.392),  // #6E6A64
        border: Color(red: 0.890, green: 0.863, blue: 0.824),     // #E3DCD2
        accent: Color(red: 0.737, green: 0.325, blue: 0.078),     // #BC5314
        accentSoft: Color(red: 0.992, green: 0.694, blue: 0.443), // #FDB171
        onAccent: Color.white
    )

    static let dark = PorcelainPalette(
        background: Color(red: 0.078, green: 0.086, blue: 0.078), // #141614
        surface: Color(red: 0.122, green: 0.129, blue: 0.118),    // #1F211E
        elevated: Color(red: 0.165, green: 0.173, blue: 0.157),   // #2A2C28
        foreground: Color(red: 0.961, green: 0.953, blue: 0.937), // #F5F3EF
        secondary: Color(red: 0.706, green: 0.694, blue: 0.667),  // #B4B1AA
        border: Color(red: 0.227, green: 0.235, blue: 0.220),     // #3A3C38
        accent: Color(red: 0.878, green: 0.478, blue: 0.220),     // #E07A38
        accentSoft: Color(red: 0.290, green: 0.180, blue: 0.090),
        onAccent: Color.white
    )

    static func forScheme(_ scheme: ColorScheme) -> PorcelainPalette {
        scheme == .dark ? .dark : .light
    }
}

/// The Orange & Porcelain Home: choose a media scope, continue where you left
/// off, or open the deletion review.
///
/// The three media choices (Everything, Photos, Videos) each open editable
/// filters rather than starting straight away, so what is included is always
/// visible before a session captures its fixed pool. Continue sorting restores
/// the saved session's own filters and pool; Review marked items never touches
/// either.
struct EntryView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var palette: PorcelainPalette { .forScheme(colorScheme) }

    var body: some View {
        // Exactly one screen tall at normal sizes. When the largest
        // accessibility text needs more room the same content scrolls instead of
        // pushing the media choices off the screen.
        GeometryReader { geometry in
            ScrollView {
                content.frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(palette.background)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            topBar
            wordmark
            heading
            presetCards
            if model.resumableSession != nil {
                continueSorting
            }
            if !model.hasPhotos {
                Text("No photos to sort.")
                    .font(.body)
                    .foregroundStyle(palette.secondary)
                    .accessibilityIdentifier("entry.empty")
            }
            if model.hasPhotos, model.authorization.isLimited {
                Button {
                    model.manageLimitedLibrary()
                } label: {
                    Text("Select more photos")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityIdentifier("entry.selectMorePhotos")
            }
            if hasImpact {
                yourImpact
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    // MARK: - Chrome

    /// Settings and Review mirror the top corners, so their positions never move
    /// as work appears and disappears.
    private var topBar: some View {
        HStack {
            Button {
                model.route = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("entry.settings")

            Spacer(minLength: 0)

            reviewChip
        }
        .foregroundStyle(palette.foreground)
    }

    /// The wordmark frames the top strip on its own centred line, so a wide
    /// review count can never push it off-centre.
    private var wordmark: some View {
        Text("SWIPR")
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(palette.accent)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("entry.wordmark")
    }

    private var heading: some View {
        Text("What are we cleaning today?")
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(palette.foreground)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("entry.heading")
    }

    @ViewBuilder
    private var reviewChip: some View {
        if model.queueCount > 0 {
            Button {
                model.goToReview(from: .entry)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .overlay(alignment: .topTrailing) { CountBadge(count: model.queueCount) }
            }
            .accessibilityLabel(DeletionWording.markedForDeletion(model.queueCount))
            .accessibilityValue(DeletionWording.nothingDeletedYet)
            .accessibilityIdentifier("entry.review")
        } else {
            Color.clear.frame(width: 44, height: 44)
        }
    }

    // MARK: - Media choices

    private var presetCards: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    card(for: .everything, title: "Everything", identifier: "entry.preset.everything", symbol: "photo.stack")
                    card(for: .photos, title: "Photos", identifier: "entry.preset.photos", symbol: "photo")
                    card(for: .videos, title: "Videos", identifier: "entry.preset.videos", symbol: "video")
                }
            } else {
                VStack(spacing: 12) {
                    card(for: .everything, title: "Everything", identifier: "entry.preset.everything", symbol: "photo.stack")
                    HStack(spacing: 12) {
                        card(for: .photos, title: "Photos", identifier: "entry.preset.photos", symbol: "photo")
                        card(for: .videos, title: "Videos", identifier: "entry.preset.videos", symbol: "video")
                    }
                }
            }
        }
        .disabled(!model.hasPhotos)
    }

    private func card(
        for preset: MediaFilter,
        title: String,
        identifier: String,
        symbol: String
    ) -> some View {
        PresetCard(
            title: title,
            identifier: identifier,
            symbol: symbol,
            asset: newestAsset(matching: preset),
            palette: palette,
            enabled: model.hasPhotos
        ) {
            model.showFilters(preset)
        }
    }

    /// The newest asset the preset would include, used only as the card's
    /// cover image; the pool itself is captured when a session starts.
    private func newestAsset(matching preset: MediaFilter) -> AssetDescriptor? {
        model.order.assets.reversed().first { preset.includes($0) }
    }

    // MARK: - Waiting work

    private var continueSorting: some View {
        Button {
            model.resumeSession()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Continue sorting")
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(resumableSubtitle)
                        .font(.footnote)
                        .foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continue sorting")
        .accessibilityValue(resumableSubtitle)
        .accessibilityIdentifier("entry.resume")
    }

    /// What the waiting session will walk, named from its saved filters.
    private var resumableSubtitle: String {
        guard let categories = model.resumableSession?.filterCategories else {
            return "Saved session"
        }
        return MediaFilter(categories: categories).selectionName
    }

    // MARK: - Your impact

    private var hasImpact: Bool {
        model.statistics.lifetimeDeletedCount > 0 || model.statistics.lifetimeReclaimedBytes > 0
    }

    private var yourImpact: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Your impact", systemImage: "leaf")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.foreground)
            Text("≈ \(ByteFormatter.string(fromBytes: model.statistics.lifetimeReclaimedBytes)) freed · \(model.statistics.lifetimeDeletedCount) items deleted")
                .font(.footnote)
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("entry.impact")
    }
}

/// A photographic media-choice card. It shows the newest asset the choice would
/// include when one is available, and a warm symbol tile otherwise.
private struct PresetCard: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let identifier: String
    let symbol: String
    let asset: AssetDescriptor?
    let palette: PorcelainPalette
    let enabled: Bool
    let action: () -> Void

    @State private var image: UIImage?

    var body: some View {
        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    // At the largest text sizes a label over the photo would
                    // spill out of the card, so it sits under a shorter cover.
                    VStack(alignment: .leading, spacing: 0) {
                        cover
                            .frame(maxWidth: .infinity)
                            .frame(height: 96)
                            .clipped()
                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(palette.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(palette.surface)
                } else {
                    Rectangle()
                        .fill(palette.elevated)
                        .frame(maxWidth: .infinity)
                        .frame(height: 128)
                        .overlay { cover }
                        .overlay { linearGradient }
                        .overlay(alignment: .bottomLeading) {
                            Text(title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(14)
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
            .opacity(enabled ? 1 : 0.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
        .task(id: asset?.id) {
            guard let asset else {
                image = nil
                return
            }
            image = await model.library.thumbnail(
                for: asset.id,
                targetSize: CGSize(width: 600, height: 400)
            )
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [palette.accent, palette.accentSoft],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            )
        }
    }

    /// A soft scrim so the label stays legible over any photo.
    private var linearGradient: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.55)],
            startPoint: .center,
            endPoint: .bottom
        )
    }
}
