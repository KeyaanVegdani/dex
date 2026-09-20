import SwiftUI

/// Post-cake story log: a three-card timeline (tomato → cake → next-up) with focus scrubbing.
struct ProgressTrackerView: View {
    @State private var focusedIndex = ProgressMilestone.cake.rawValue

    private let milestones = ProgressMilestone.allCases

    var body: some View {
        GeometryReader { geo in
            let cardSide = min(geo.size.width * 0.28, geo.size.height * 0.42, 320)

            ZStack {
                Theme.background

                VStack(spacing: 36) {
                    Spacer(minLength: 0)

                    HStack(spacing: 0) {
                        card(for: .tomato, side: cardSide, focused: focusedIndex == 0)

                        scrubButton(systemName: "arrow.left", enabled: focusedIndex > 0) {
                            moveFocus(by: -1)
                        }

                        card(for: .cake, side: cardSide, focused: focusedIndex == 1)

                        scrubButton(systemName: "arrow.right", enabled: focusedIndex < milestones.count - 1) {
                            moveFocus(by: 1)
                        }

                        card(for: .nextUp, side: cardSide, focused: focusedIndex == 2)
                    }
                    .frame(maxWidth: .infinity)

                    Text(milestones[focusedIndex].dateLabel)
                        .font(Theme.headingFont)
                        .foregroundStyle(Theme.title)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.22), value: focusedIndex)
                        .id(focusedIndex)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 40)
            }
        }
    }

    private func card(for milestone: ProgressMilestone, side: CGFloat, focused: Bool) -> some View {
        Image(nsImage: AppResources.image(milestone.imageName))
            .resizable()
            .scaledToFit()
            .padding(milestone.imageInset)
            .frame(width: side, height: side)
            .background(milestone.background, in: RoundedRectangle(cornerRadius: side * 0.14, style: .continuous))
            .scaleEffect(focused ? 1 : 0.7)
            .opacity(focused ? 1 : 0.5)
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: focusedIndex)
            .accessibilityLabel(milestone.accessibilityLabel)
    }

    private func scrubButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        PillCircleButton(systemName: systemName, action: action)
            .padding(.horizontal, 10)
            .opacity(enabled ? 1 : 0.35)
            .disabled(!enabled)
            .accessibilityLabel(systemName == "arrow.left" ? "Previous milestone" : "Next milestone")
    }

    private func moveFocus(by delta: Int) {
        let next = focusedIndex + delta
        guard milestones.indices.contains(next) else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            focusedIndex = next
        }
    }
}

enum ProgressMilestone: Int, CaseIterable, Identifiable {
    case tomato
    case cake
    case nextUp

    var id: Int { rawValue }

    var imageName: String {
        switch self {
        case .tomato: return "tomato"
        case .cake: return "cake"
        case .nextUp: return "next-up"
        }
    }

    /// Cake sits smaller in its tile (transparent sticker); tomato / next-up already fill the square.
    var imageInset: CGFloat {
        switch self {
        case .cake: return 36
        case .tomato, .nextUp: return 0
        }
    }

    var background: Color {
        switch self {
        case .tomato: return Theme.tomatoCard
        case .cake: return Theme.cakeCard
        case .nextUp: return Theme.nextCard
        }
    }

    /// Tomato is the day before cake; next-up stays open-ended in product voice.
    var dateLabel: String {
        switch self {
        case .tomato: return "September 19"
        case .cake: return "September 20"
        case .nextUp: return "Coming soon"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .tomato: return "Tomato lesson, September 19"
        case .cake: return "Cake lesson, September 20"
        case .nextUp: return "Next lesson, coming soon"
        }
    }
}
