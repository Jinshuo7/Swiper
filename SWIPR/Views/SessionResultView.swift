import SWIPRKit
import SwiftUI

struct SessionResultView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let outcome: DeletionOutcome

    private var hasDeletions: Bool { outcome.deletedCount > 0 }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            // At accessibility sizes the card is taller than the screen, and a
            // squeezed card truncates the storage figure this screen exists to
            // report. It scrolls instead.
            ScrollView {
                card
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
            }
        } else {
            VStack {
                Spacer()
                card.padding(.horizontal, 20)
                Spacer()
            }
        }
    }

    private var card: some View {
        VStack(spacing: 18) {
            Image(systemName: hasDeletions ? "checkmark.circle.fill" : "info.circle")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(hasDeletions ? Color.swiprKeep : Color.swiprForeground)

            if hasDeletions {
                Text("\(outcome.deletedCount) \(outcome.deletedCount == 1 ? "photo" : "photos") deleted")
                    .font(.title2.weight(.semibold))
                     .foregroundStyle(Color.swiprForeground)
                    .fixedSize(horizontal: false, vertical: true)
                Text("You reclaimed approximately \(ByteFormatter.string(fromBytes: outcome.deletedBytes)).")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.swiprSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Nothing was deleted")
                    .font(.title2.weight(.semibold))
                     .foregroundStyle(Color.swiprForeground)
                    .fixedSize(horizontal: false, vertical: true)
                Text("No marked photo was confirmed deleted. Unconfirmed items are never counted as deletions.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.swiprSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if outcome.failedCount > 0 {
                Text("\(outcome.failedCount) could not be confirmed as deleted and stayed marked. Nothing about them was counted.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.swiprWarning)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("result.remaining")
            }

            Button {
                model.dismissResult()
            } label: {
                Text(model.resultContinuationTitle)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 6)
            .accessibilityIdentifier("result.done")
        }
        .padding(28)
        .frame(maxWidth: 420)
        .background(Color.swiprSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.swiprBorder, lineWidth: 1)
        )
    }
}
