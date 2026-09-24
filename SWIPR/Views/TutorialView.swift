import SWIPRKit
import SwiftUI

/// The one-time explanation of how sorting works.
///
/// It is deliberately short, uses words as well as symbols, and teaches the
/// gestures first: dragging the photo always decides, and the three buttons are
/// the alternative for anyone who prefers them. Swiping is never disabled, so
/// there is no preset branch here any more.
struct TutorialView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.swiprBackground.opacity(0.78)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: 16) {
                if dynamicTypeSize.isAccessibilitySize {
                    // At accessibility sizes the explanation is taller than the
                    // screen. It scrolls inside the card so the one way out stays
                    // reachable instead of sitting below the bottom edge.
                    ScrollView { explanation }
                } else {
                    explanation
                }

                Button(action: onDismiss) {
                    Text("Got it")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("viewer.tutorial.dismiss")
            }
            .padding(22)
            .frame(maxWidth: 420)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.swiprBorder, lineWidth: 1)
            )
            .padding(24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("viewer.tutorial")
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How sorting works")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.swiprForeground)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(instructions, id: \.title) { instruction in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: instruction.symbol)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(instruction.tint)
                            .frame(width: 30)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(instruction.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.swiprForeground)
                            Text(instruction.detail)
                                .font(.footnote)
                                .foregroundStyle(Color.swiprSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Divider().overlay(Color.swiprBorder)

            VStack(alignment: .leading, spacing: 8) {
                Text("Nothing is deleted until you review and confirm.")
                    .font(.footnote.weight(.semibold))
                     .foregroundStyle(Color.swiprForeground)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Every decision is saved as you make it, so closing the app or an interruption does not erase work you already accepted.")
                    .font(.footnote)
                    .foregroundStyle(Color.swiprSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private struct Instruction {
        let symbol: String
        let title: String
        let detail: String
        let tint: Color
    }

    private var instructions: [Instruction] {
        [
            Instruction(
                symbol: "hand.draw",
                title: "Drag left to delete",
                detail: "The photo follows your finger. Past the threshold it arms, and releasing marks it. Nothing is deleted yet.",
                tint: .swiprDelete
            ),
            Instruction(
                symbol: "hand.draw",
                title: "Drag right to keep",
                detail: "A short or vertical drag makes no decision, so hesitating is safe.",
                tint: .swiprKeep
            ),
            Instruction(
                symbol: "trash",
                title: "Or use the buttons",
                detail: "Trash, Undo and Checkmark are on the photo unless you turn them off in Settings.",
                tint: .swiprAccent
            ),
            Instruction(
                symbol: "ellipsis",
                title: "Move the buttons",
                detail: "Drag the three dots to put the buttons at the bottom, left or right edge. The photo stays exactly where it is.",
                tint: .swiprAccent
            ),
        ]
    }
}
