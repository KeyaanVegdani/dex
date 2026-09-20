import SwiftUI

/// Post-cake story log: a three-card timeline (tomato → cake → next-up) with focus scrubbing.
/// The focused card is always centered on screen; earlier/later cards sit to its left/right.
struct ProgressTrackerView: View {
    @State private var focusedIndex = ProgressMilestone.cake.rawValue

    private let milestones = ProgressMilestone.allCases
    /// Shared by every card so side tiles don’t look rounder/sharper than the center.
    private static let cornerRadius: CGFloat = 36
    private static let scrubSpring = Animation.spring(response: 0.38, dampingFraction: 0.82)

    var body: some View {
        GeometryReader { geo in
            let focusedSide = min(geo.size.width * 0.28, geo.size.height * 0.42, 320)
            let sideSide = focusedSide * 0.7
            let buttonGap: CGFloat = 76
            let pitch = focusedSide + buttonGap
            let centerX = geo.size.width / 2
            // Sit the row a bit above true center so the date label can clear below.
            let cardY = geo.size.height * 0.46
            let dateY = cardY + focusedSide * 0.5 + 48

            ZStack {
                Theme.background

                ForEach(milestones) { milestone in
                    let relative = milestone.rawValue - focusedIndex
                    let focused = relative == 0
                    let visible = abs(relative) <= 1
                    let size = focused ? focusedSide : sideSide

                    card(for: milestone, side: size)
                        .opacity(focused ? 1 : (visible ? 0.5 : 0))
                        .position(x: centerX + CGFloat(relative) * pitch, y: cardY)
                        .zIndex(focused ? 1 : 0)
                        .accessibilityHidden(!visible)
                }

                scrubButton(systemName: "arrow.left", enabled: focusedIndex > 0) {
                    moveFocus(by: -1)
                }
                .position(x: centerX - pitch / 2, y: cardY)

                scrubButton(systemName: "arrow.right", enabled: focusedIndex < milestones.count - 1) {
                    moveFocus(by: 1)
                }
                .position(x: centerX + pitch / 2, y: cardY)

                Text(milestones[focusedIndex].dateLabel)
                    .font(Theme.headingFont)
                    .foregroundStyle(Theme.title)
                    .multilineTextAlignment(.center)
                    .position(x: centerX, y: dateY)
                    .animation(.easeInOut(duration: 0.22), value: focusedIndex)
                    .id(focusedIndex)
            }
            .animation(Self.scrubSpring, value: focusedIndex)
        }
    }

    private func card(for milestone: ProgressMilestone, side: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        let inset = milestone.imageInset * (side / 280)

        return Image(nsImage: AppResources.image(milestone.imageName))
            .resizable()
            .scaledToFit()
            .padding(inset)
            .frame(width: side, height: side)
            .background(milestone.background, in: shape)
            .clipShape(shape)
            .accessibilityLabel(milestone.accessibilityLabel)
    }

    private func scrubButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        PillCircleButton(systemName: systemName, action: action)
            .opacity(enabled ? 1 : 0.35)
            .disabled(!enabled)
            .accessibilityLabel(systemName == "arrow.left" ? "Previous milestone" : "Next milestone")
    }

    private func moveFocus(by delta: Int) {
        let next = focusedIndex + delta
        guard milestones.indices.contains(next) else { return }
        withAnimation(Self.scrubSpring) {
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

    /// All three milestone PNGs are full square tiles.
    var imageInset: CGFloat { 0 }

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
        case .nextUp: return "Unlock tomorrow"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .tomato: return "Tomato lesson, September 19"
        case .cake: return "Cake lesson, September 20"
        case .nextUp: return "Next lesson, Unlock tomorrow"
        }
    }
}
