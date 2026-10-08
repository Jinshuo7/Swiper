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
            Color.black.opacity(0.78)
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
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
                .foregroundStyle(.white)

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
                                .foregroundStyle(.white)
                            Text(instruction.detail)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Divider().overlay(Color.white.opacity(0.2))

            VStack(alignment: .leading, spacing: 8) {
                Text("Nothing is deleted until you review and confirm.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Every decision is saved as you make it, so closing the app or an interruption does not erase work you already accepted.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
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
                tint: .red
            ),
            Instruction(
                symbol: "hand.draw",
                title: "Drag right to keep",
                detail: "A short or vertical drag makes no decision, so hesitating is safe.",
                tint: .green
            ),
            Instruction(
                symbol: "trash",
                title: "Or use the buttons",
                detail: "Trash, Undo and Checkmark are on the photo unless you turn them off in Settings.",
                tint: .orange
            ),
            Instruction(
                symbol: "hand.draw",
                title: "Move the buttons",
                detail: "Drag the buttons — or the space between them — to put them at the bottom, left or right edge. The photo stays exactly where it is.",
                tint: .blue
            ),
        ]
    }
}
