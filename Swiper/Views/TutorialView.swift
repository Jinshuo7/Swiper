import SwiperKit
import SwiftUI

/// The one-time explanation of how sorting works.
///
/// It is deliberately short, uses words as well as symbols, and adapts to the
/// selected preset: someone using a button preset should not be told to swipe.
/// It is shown once for the first photo and can be replayed from
/// Settings → How to use.
struct TutorialView: View {
    let preset: ControlPreset
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

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

    private struct Instruction {
        let symbol: String
        let title: String
        let detail: String
        let tint: Color
    }

    private var instructions: [Instruction] {
        switch preset {
        case .swipe:
            return [
                Instruction(
                    symbol: "hand.draw",
                    title: "Drag left to mark for deletion",
                    detail: "The photo follows your finger. Past the threshold it arms, and releasing marks it.",
                    tint: .red
                ),
                Instruction(
                    symbol: "hand.draw",
                    title: "Drag right to keep",
                    detail: "A short or vertical drag makes no decision, so hesitating is safe.",
                    tint: .green
                ),
                Instruction(
                    symbol: "heart",
                    title: "Favorite keeps the photo",
                    detail: "The heart in the top bar marks it as an Apple Photos favorite.",
                    tint: .pink
                ),
                Instruction(
                    symbol: "trash",
                    title: "Review before anything is deleted",
                    detail: "Open Review from the photo or from home to restore or confirm.",
                    tint: .orange
                ),
            ]
        case .deleteOnly:
            return [
                Instruction(
                    symbol: "trash",
                    title: "Trash marks for deletion",
                    detail: "Only this button marks a photo.",
                    tint: .red
                ),
                Instruction(
                    symbol: "hand.tap",
                    title: "Tap the photo to keep it",
                    detail: "Tapping anywhere on the photo advances without deleting.",
                    tint: .green
                ),
                Instruction(
                    symbol: "trash",
                    title: "Review before anything is deleted",
                    detail: "Open Review from the photo or from home to restore or confirm.",
                    tint: .orange
                ),
            ]
        case .thumb, .extended:
            return [
                Instruction(
                    symbol: "trash",
                    title: "Trash marks for deletion",
                    detail: "The photo is only marked. Nothing leaves your library.",
                    tint: .red
                ),
                Instruction(
                    symbol: "checkmark",
                    title: "Checkmark keeps the photo",
                    detail: "The photo stays and the session moves on.",
                    tint: .green
                ),
                Instruction(
                    symbol: "heart",
                    title: "Favorite keeps the photo",
                    detail: "Use the heart to favorite it in Apple Photos as well.",
                    tint: .pink
                ),
                Instruction(
                    symbol: "arrow.uturn.backward",
                    title: "Undo reverses the last decision",
                    detail: "Undo never deletes anything.",
                    tint: .white
                ),
            ]
        }
    }
}
