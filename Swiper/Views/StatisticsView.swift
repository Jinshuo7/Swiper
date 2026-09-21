import SwiperKit
import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 16) {
                    section(
                        title: "This session",
                        rows: [
                            ("Photos deleted", "\(model.statistics.currentSessionDeletedCount)"),
                            ("Storage reclaimed", ByteFormatter.string(fromBytes: model.statistics.currentSessionReclaimedBytes)),
                        ]
                    )
                    section(
                        title: "Lifetime",
                        rows: [
                            ("Photos deleted", "\(model.statistics.lifetimeDeletedCount)"),
                            ("Storage reclaimed", "≈ \(ByteFormatter.string(fromBytes: model.statistics.lifetimeReclaimedBytes))"),
                            ("Cleanup sessions completed", "\(model.statistics.lifetimeCompletedSessions)"),
                        ]
                    )
                    Text("Only deletions confirmed by the system are counted. Photos that were only marked, and failed or cancelled deletions, are not included. Storage figures are estimates; Swiper does not use private APIs to read exact file sizes.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 4)
                }
                .padding(20)
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                model.route = .settings
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back")
            Spacer()
            Text("Statistics")
                .font(.headline)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    private func section(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.0)
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text(row.1)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                .font(.body)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
