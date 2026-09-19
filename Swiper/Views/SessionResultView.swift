import SwiperKit
import SwiftUI

struct SessionResultView: View {
    @EnvironmentObject private var model: AppModel
    let outcome: DeletionOutcome

    private var hasDeletions: Bool { outcome.deletedCount > 0 }

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 18) {
                Image(systemName: hasDeletions ? "checkmark.circle.fill" : "info.circle")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(hasDeletions ? .green : .white)

                if hasDeletions {
                    Text("\(outcome.deletedCount) \(outcome.deletedCount == 1 ? "photo" : "photos") deleted")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("You reclaimed approximately \(ByteFormatter.string(fromBytes: outcome.deletedBytes)).")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    Text("Nothing was deleted")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("No queued photo was confirmed deleted. Unconfirmed items are never counted as deletions.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.7))
                }

                if outcome.failedCount > 0 {
                    Text("\(outcome.failedCount) could not be confirmed as deleted.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                Button {
                    model.dismissResult()
                } label: {
                    Text("Done")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 6)
                .accessibilityIdentifier("result.done")

            }
            .padding(28)
            .frame(maxWidth: 420)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            Spacer()
        }
    }
}
