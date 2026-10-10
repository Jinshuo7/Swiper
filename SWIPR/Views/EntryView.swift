import SWIPRKit
import SwiftUI

/// The exact Orange & Porcelain hex values, so the code carries the approved
/// tokens literally rather than an approximation.
private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Orange & Porcelain semantic colours for the Home and filter screens.
///
/// Explicit light and dark values, rather than system colours, keep the
/// porcelain look identical on every iOS version and let a screen render in
/// either appearance on demand. The seven tokens the design board pins are
/// exactly `#F8F8F6`, `#FFFFFF`, `#C05A20`, `#272724`, `#191A18`, `#2C2D29`
/// and `#F2A66B`.
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
        background: Color(hex: 0xF8F8F6),
        surface: Color(hex: 0xFFFFFF),
        elevated: Color(hex: 0xF1F0EC),
        foreground: Color(hex: 0x272724),
        secondary: Color(hex: 0x6E6A64),
        border: Color(hex: 0xE4E2DC),
        accent: Color(hex: 0xC05A20),
        accentSoft: Color(hex: 0xE8A06A),
        onAccent: Color.white
    )

    static let dark = PorcelainPalette(
        background: Color(hex: 0x191A18),
        surface: Color(hex: 0x2C2D29),
        elevated: Color(hex: 0x232421),
        foreground: Color(hex: 0xF5F3EF),
        secondary: Color(hex: 0xB4B1AA),
        border: Color(hex: 0x3A3C38),
        accent: Color(hex: 0xF2A66B),
        accentSoft: Color(hex: 0x5A4632),
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
/// the saved session's own filters and pool; the round Review button is the way
/// into marked items and never touches either.
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
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                topBar
                heading
            }
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

    /// The compact wordmark on the leading edge and the Settings gear on the
    /// trailing edge, exactly as the approved board; the round Review button
    /// (an owner decision) sits inside the gear when anything is marked.
    private var topBar: some View {
        HStack(spacing: 6) {
            wordmark
            Spacer(minLength: 0)
            reviewChip
            settingsButton
        }
        .foregroundStyle(palette.foreground)
    }

    private var wordmark: some View {
        Text("SWIPR")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(palette.accent)
            .frame(height: 44)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("entry.wordmark")
    }

    private var settingsButton: some View {
        Button {
            model.route = .settings
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("entry.settings")
    }

    private var heading: some View {
        Text("What are we cleaning today?")
            .font(.system(size: 30, weight: .bold))
            .lineSpacing(-1)
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
        }
    }

    // MARK: - Media choices

    private var presetCards: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    everythingCard
                    squareCard(for: .photos, title: "Photos", identifier: "entry.preset.photos", symbol: "photo")
                    squareCard(for: .videos, title: "Videos", identifier: "entry.preset.videos", symbol: "video")
                }
            } else {
                VStack(spacing: 12) {
                    everythingCard
                    HStack(spacing: 12) {
                        squareCard(for: .photos, title: "Photos", identifier: "entry.preset.photos", symbol: "photo")
                        squareCard(for: .videos, title: "Videos", identifier: "entry.preset.videos", symbol: "video")
                    }
                }
            }
        }
        .disabled(!model.hasPhotos)
    }

    private var everythingCard: some View {
        EverythingCard(
            title: "Everything",
            identifier: "entry.preset.everything",
            assets: newestAssets(matching: .everything, count: 3),
            palette: palette,
            enabled: model.hasPhotos
        ) {
            model.showFilters(.everything)
        }
    }

    private func squareCard(
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

    /// The newest assets the preset would include, used only as the card's
    /// cover images; the pool itself is captured when a session starts.
    private func newestAssets(matching preset: MediaFilter, count: Int) -> [AssetDescriptor] {
        Array(model.order.assets.reversed().filter { preset.includes($0) }.prefix(count))
    }

    private func newestAsset(matching preset: MediaFilter) -> AssetDescriptor? {
        newestAssets(matching: preset, count: 1).first
    }

    // MARK: - Waiting work

    private var continueSorting: some View {
        Button {
            model.resumeSession()
        } label: {
            HStack(spacing: 12) {
                SessionThumbnail(asset: resumeAsset, palette: palette)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Continue sorting")
                        .font(.system(size: 17, weight: .semibold))
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
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continue sorting")
        .accessibilityValue(resumableSubtitle)
        .accessibilityIdentifier("entry.resume")
    }

    /// The asset the waiting session will next show, used for the row's
    /// thumbnail; nil falls back to the neutral clock tile.
    private var resumeAsset: AssetDescriptor? {
        guard let session = model.resumableSession else { return nil }
        if let id = session.currentAssetID,
           let current = model.order.assets.first(where: { $0.id == id }) {
            return current
        }
        guard let ids = session.poolIDs else { return nil }
        let wanted = Set(ids)
        return model.order.assets.first { wanted.contains($0.id) }
    }

    /// What the waiting session will walk: its saved filter name and the month
    /// of the photo it will show next, e.g. "Photos · September".
    private var resumableSubtitle: String {
        let name = model.resumableSession?.filterCategories
            .map { MediaFilter(categories: $0).selectionName } ?? "Saved session"
        guard let date = resumeAsset?.creationDate else { return name }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return "\(name) · \(formatter.string(from: date))"
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
            Text("About \(ByteFormatter.string(fromBytes: model.statistics.lifetimeReclaimedBytes)) freed · \(model.statistics.lifetimeDeletedCount) items deleted")
                .font(.footnote)
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("entry.impact")
    }
}

/// The wide **Everything** card: three overlapping photo prints on a soft card,
/// with the label over the prints, matching the approved composition.
private struct EverythingCard: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale
    let title: String
    let identifier: String
    let assets: [AssetDescriptor]
    let palette: PorcelainPalette
    let enabled: Bool
    let action: () -> Void

    @State private var images: [String: UIImage] = [:]

    var body: some View {
        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 0) {
                        fan.frame(height: 140)
                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(palette.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(palette.elevated)
                } else {
                    ZStack(alignment: .bottomLeading) {
                        palette.elevated
                        fan
                        // A soft bottom scrim keeps the white label legible
                        // over any photo, the way the square cards do.
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.55)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        Text(title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                    }
                    .frame(height: 248)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
            .opacity(enabled ? 1 : 0.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
        .task(id: assets.map(\.id).joined(separator: ",")) {
            // Cover the largest print at this screen's scale so a card image is
            // never upscaled: the middle print is 46% x 88% of a ~343 x 248 pt
            // card, the widest it gets on the supported layouts.
            let target = CGSize(width: 170 * displayScale, height: 230 * displayScale)
            var loaded: [String: UIImage] = [:]
            for asset in assets {
                if let image = await model.library.thumbnail(for: asset.id, targetSize: target) {
                    loaded[asset.id] = image
                }
            }
            images = loaded
        }
    }

    private var fan: some View {
        GeometryReader { geometry in
            let side = geometry.size.width * 0.38
            let sideHeight = geometry.size.height * 0.74
            let middleWidth = geometry.size.width * 0.46
            let middleHeight = geometry.size.height * 0.88
            ZStack {
                printCard(0, side, sideHeight)
                    .rotationEffect(.degrees(-9))
                    .offset(x: -geometry.size.width * 0.26, y: geometry.size.height * 0.14)
                printCard(2, side, sideHeight)
                    .rotationEffect(.degrees(9))
                    .offset(x: geometry.size.width * 0.26, y: geometry.size.height * 0.10)
                // The middle print is the largest and sits in front, exactly as
                // the approved board; its neighbours tuck behind it.
                printCard(1, middleWidth, middleHeight)
                    .rotationEffect(.degrees(1.5))
                    .offset(y: -geometry.size.height * 0.02)
                    .zIndex(1)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    @ViewBuilder
    private func printCard(_ index: Int, _ width: CGFloat, _ height: CGFloat) -> some View {
        Group {
            if assets.indices.contains(index), let image = images[assets[index].id] {
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
                    Image(systemName: "photo")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                )
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color(hex: 0xFFFFFF), lineWidth: 5))
        .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
    }
}

/// A square-ish photographic media-choice card (Photos / Videos). It shows the
/// newest asset the choice would include when one is available, and a warm
/// symbol tile otherwise.
private struct PresetCard: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale
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
                    // A square card, the size the approved board uses.
                    Rectangle()
                        .fill(palette.elevated)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay { cover }
                        .overlay { linearGradient }
                        .overlay {
                            if asset?.kind == .video {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(13)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                        }
                        .overlay(alignment: .bottomLeading) {
                            Text(title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(14)
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
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
            // The square card is ~166 pt on the narrowest layout; request it at
            // pixel scale so it is never upscaled.
            let side = 170 * displayScale
            image = await model.library.thumbnail(
                for: asset.id,
                targetSize: CGSize(width: side, height: side)
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

/// The Continue sorting row's small square thumbnail, or a neutral clock tile
/// while the session has no resolvable asset.
private struct SessionThumbnail: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.displayScale) private var displayScale
    let asset: AssetDescriptor?
    let palette: PorcelainPalette

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                palette.elevated
                    .overlay(
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(palette.accent)
                    )
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: asset?.id) {
            guard let asset else {
                image = nil
                return
            }
            let side = 48 * displayScale
            image = await model.library.thumbnail(
                for: asset.id,
                targetSize: CGSize(width: side, height: side)
            )
        }
    }
}
