import SwiperKit
import SwiftUI

/// Pick the point in the library to start sorting from.
///
/// The screen exists to answer one question — "where do I begin?" — so it says so
/// out loud, shows the library by month with the newest first (a grid of recent
/// photos is what people look for), and lets the user jump straight to a month
/// instead of scrolling in from one end.
///
/// Only visible cells request a thumbnail, and cells cancel their request when
/// they scroll away, so a library with tens of thousands of photos never loads
/// more than a screenful at once.
struct StartHereGridView: View {
    @EnvironmentObject private var model: AppModel

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
                explanation
                jumpBar(proxy)
                Divider().overlay(Color.white.opacity(0.12))

                if model.order.isEmpty {
                    Spacer()
                    Text("No photos or Live Photos are visible.")
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                } else {
                    grid
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
            Spacer()
            Text("Start Here")
                .font(.headline)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    /// Says what the screen is for. Without this the grid is just a photo library
    /// with no explanation of what tapping a photo does.
    private var explanation: some View {
        Text("Pick the photo you want to start from. Swiper begins there and walks toward older photos, skipping anything you have already decided or marked for deletion.")
            .font(.footnote)
            .multilineTextAlignment(.leading)
            .foregroundStyle(.white.opacity(0.65))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .accessibilityIdentifier("startHere.explanation")
    }

    private func jumpBar(_ proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 10) {
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
                    Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .foregroundStyle(.white)
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
            .disabled(months.count < 2)
            .accessibilityIdentifier("startHere.jump")

            Spacer(minLength: 0)

            Button {
                newestFirst.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: newestFirst ? "arrow.down" : "arrow.up")
                    Text(newestFirst ? "Newest first" : "Oldest first")
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .foregroundStyle(.white)
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
            .accessibilityIdentifier("startHere.sort")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Grid

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2, pinnedViews: [.sectionHeaders]) {
                ForEach(months) { month in
                    Section {
                        ForEach(month.assets) { asset in
                            let isMarked = model.marks.contains(asset.id)
                            StartHereCell(asset: asset, isMarked: isMarked)
                                // A marked photo is waiting in review, not for a
                                // decision, so the cell explains itself instead of
                                // starting a session on it.
                                .onTapGesture {
                                    guard !isMarked else { return }
                                    model.startHere(assetID: asset.id)
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
    }

    private func monthHeader(_ month: LibraryMonth) -> some View {
        HStack(spacing: 8) {
            Text(monthTitles[month.id] ?? month.id)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text("\(month.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("startHere.month.\(month.id)")
    }
}

private struct StartHereCell: View {
    @EnvironmentObject private var model: AppModel
    let asset: AssetDescriptor
    /// Marked photos are skipped while sorting, so this cell shows why instead
    /// of silently ignoring a tap.
    let isMarked: Bool
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.white.opacity(0.05)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(isMarked ? 0.35 : 1)
            }
            if isMarked {
                Text("MARKED")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.75), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(4)
                    .accessibilityHidden(true)
            } else if asset.isLivePhoto {
                Text("LIVE")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.6), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(4)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 92)
        .clipped()
        .contentShape(Rectangle())
        .task(id: asset.id) {
            image = await model.library.thumbnail(for: asset.id, targetSize: CGSize(width: 184, height: 184))
        }
        .accessibilityIdentifier("startHere.cell.\(asset.id)")
        .accessibilityLabel(isMarked ? "\(asset.id), marked for deletion" : asset.id)
    }
}
