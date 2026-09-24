import SWIPRKit
import SwiftUI

/// Choose where a sorting session begins: the single door into sorting.
///
/// The screen answers one question — "where do I begin?" — so it says so out
/// loud, offers the two named traversals (`Newest` and `Random`), shows the
/// library by month with the newest first, and lets the user jump straight to a
/// month instead of scrolling in from one end. Opening it leaves a resumable
/// session alone; only choosing a photo replaces it.
///
/// Only visible cells request a thumbnail, and cells cancel their request when
/// they scroll away, so a large library never loads more than a screenful at
/// once.
struct ChoosePhotoView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var newestFirst = true
    @State private var monthTitles: [String: String] = [:]

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 2)]

    private var months: [LibraryMonth] {
        LibraryCalendar.months(in: model.order, newestFirst: newestFirst)
    }

    /// Recompute the titles only when the library or the sort order changes,
    /// rather than building a `DateFormatter` on every redraw.
    private var monthsSignature: String {
        let first = model.order.assets.first?.id ?? ""
        let last = model.order.assets.last?.id ?? ""
        return "\(model.order.count)|\(first)|\(last)|\(newestFirst)"
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                header
                if dynamicTypeSize.isAccessibilitySize {
                    // At accessibility sizes the chrome is taller than the
                    // screen, so it scrolls with the grid rather than squeezing
                    // the labels into ellipses and the jump bar off the bottom.
                    ScrollView {
                        VStack(spacing: 0) {
                            traversalRow
                            jumpBar(proxy)
                            Divider().overlay(Color.swiprBorder)
                            gridBody
                        }
                    }
                } else {
                    traversalRow
                    jumpBar(proxy)
                    Divider().overlay(Color.swiprBorder)

                    if model.order.isEmpty {
                        Spacer()
                        Text("No photos or Live Photos are visible.")
                            .foregroundStyle(Color.swiprSecondary)
                        Spacer()
                    } else {
                        grid
                    }
                }
            }
            .task(id: monthsSignature) {
                monthTitles = LibraryCalendar.titles(for: months)
            }
        }
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
            .accessibilityIdentifier("choosePhoto.back")
            Spacer()
            Text("Choose a photo")
                .font(.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .foregroundStyle(Color.swiprForeground)
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    /// The two named traversals. At accessibility sizes they stack, because a
    /// two-across row squeezes each label down to an ellipsis.
    private var traversalRow: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    newestButton
                    randomButton
                }
            } else {
                HStack(spacing: 10) {
                    newestButton
                    randomButton
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .disabled(model.order.isEmpty)
    }

    private var newestButton: some View {
        traversalButton(systemImage: "clock.arrow.circlepath", title: "Newest", identifier: "choosePhoto.newest") {
            model.startNewest()
        }
    }

    private var randomButton: some View {
        traversalButton(systemImage: "shuffle", title: "Random", identifier: "choosePhoto.random") {
            model.startTumbler()
        }
    }

    private func traversalButton(
        systemImage: String,
        title: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.swiprSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(Color.swiprForeground)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.swiprBorder, lineWidth: 1)
            )
        }
        .accessibilityIdentifier(identifier)
    }

    /// The jump menu and the order toggle. They stack at accessibility sizes for
    /// the same reason the traversal buttons do.
    private func jumpBar(_ proxy: ScrollViewProxy) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    jumpMenu(proxy)
                    sortButton
                }
            } else {
                HStack(spacing: 10) {
                    jumpMenu(proxy)
                    Spacer(minLength: 0)
                    sortButton
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func jumpMenu(_ proxy: ScrollViewProxy) -> some View {
        Menu {
            ForEach(months) { month in
                Button(monthTitles[month.id] ?? month.id) {
                    withAnimation { proxy.scrollTo(month.id, anchor: .top) }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text("Jump to month")
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.swiprSurface, in: Capsule())
            .foregroundStyle(Color.swiprForeground)
            .overlay(Capsule().stroke(Color.swiprBorder, lineWidth: 1))
        }
        .disabled(months.count < 2)
        .accessibilityIdentifier("choosePhoto.jump")
    }

    private var sortButton: some View {
        Button {
            newestFirst.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: newestFirst ? "arrow.down" : "arrow.up")
                Text(newestFirst ? "Newest first" : "Oldest first")
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.swiprSurface, in: Capsule())
            .foregroundStyle(Color.swiprForeground)
            .overlay(Capsule().stroke(Color.swiprBorder, lineWidth: 1))
        }
        .accessibilityIdentifier("choosePhoto.sort")
    }

    // MARK: - Grid

    private var grid: some View {
        ScrollView { gridBody }
    }

    private var gridBody: some View {
        LazyVGrid(columns: columns, spacing: 2, pinnedViews: [.sectionHeaders]) {
            ForEach(months) { month in
                Section {
                    ForEach(month.assets) { asset in
                        let isMarked = model.marks.contains(asset.id)
                        ChoosePhotoCell(asset: asset, isMarked: isMarked)
                            // A marked photo is waiting in review, not for a
                            // decision, so the cell explains itself instead of
                            // starting a session on it.
                            .onTapGesture {
                                guard !isMarked else { return }
                                model.startFrom(assetID: asset.id)
                            }
                    }
                } header: {
                    monthHeader(month)
                }
                .id(month.id)
            }
        }
        .padding(.horizontal, 2)
    }

    private func monthHeader(_ month: LibraryMonth) -> some View {
        HStack(spacing: 8) {
            Text(monthTitles[month.id] ?? month.id)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.swiprForeground)
            Text("\(month.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.swiprSecondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.swiprBackground.opacity(0.96))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("choosePhoto.month.\(month.id)")
    }
}

private struct ChoosePhotoCell: View {
    @EnvironmentObject private var model: AppModel
    let asset: AssetDescriptor
    /// Marked photos are skipped while sorting, so this cell shows why instead
    /// of silently ignoring a tap.
    let isMarked: Bool
    @State private var image: UIImage?

    var body: some View {
        // The cell owns the size and the thumbnail is an overlay on it. Left to
        // size itself, a 4:1 panorama in a 92pt-tall cell asks for 368pt of width
        // and draws straight across its neighbours' columns, so the grid stops
        // looking like a grid.
        Color.swiprElevated
            .frame(maxWidth: .infinity)
            .frame(height: 92)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .opacity(isMarked ? 0.35 : 1)
                }
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                if isMarked {
                    badge("MARKED", background: 0.75)
                } else if asset.isLivePhoto {
                    badge("LIVE", background: 0.6)
                }
            }
            .contentShape(Rectangle())
            .task(id: asset.id) {
                image = await model.library.thumbnail(for: asset.id, targetSize: CGSize(width: 184, height: 184))
            }
            .accessibilityIdentifier("choosePhoto.cell.\(asset.id)")
            .accessibilityLabel(isMarked ? "\(asset.id), marked for deletion" : asset.id)
    }

    private func badge(_ text: String, background: Double) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.swiprBackground.opacity(background), in: Capsule())
            .foregroundStyle(Color.swiprForeground)
            .padding(4)
            .accessibilityHidden(true)
    }
}
