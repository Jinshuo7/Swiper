import SwiperKit
import SwiftUI

/// A lazily loaded grid of the whole library used to pick a starting photo.
///
/// Only visible cells request a thumbnail, and cells cancel their request when
/// they scroll away, so a library with tens of thousands of photos never loads
/// more than a screenful at once.
struct StartHereGridView: View {
    @EnvironmentObject private var model: AppModel
    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 2)]

    var body: some View {
        VStack(spacing: 0) {
            header
            if model.order.isEmpty {
                Spacer()
                Text("No photos or Live Photos are visible.")
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(model.order.assets) { asset in
                            StartHereCell(asset: asset)
                                .onTapGesture { model.startHere(assetID: asset.id) }
                        }
                    }
                    .padding(.horizontal, 2)
                }
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
            Text("Start Here")
                .font(.headline)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .foregroundStyle(.white)
        .padding(.bottom, 10)
    }
}

private struct StartHereCell: View {
    @EnvironmentObject private var model: AppModel
    let asset: AssetDescriptor
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.white.opacity(0.05)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            if asset.isLivePhoto {
                Text("LIVE")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.6), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(4)
            }
        }
        .frame(height: 92)
        .clipped()
        .contentShape(Rectangle())
        .task(id: asset.id) {
            image = await model.library.thumbnail(for: asset.id, targetSize: CGSize(width: 184, height: 184))
        }
        .accessibilityIdentifier("startHere.cell.\(asset.id)")
    }
}
