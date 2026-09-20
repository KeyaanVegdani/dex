import SwiftUI

/// Past-activity History: a three-card timeline (tomato → cake → next-up) with focus scrubbing.
/// The focused card is always centered on screen; earlier/later cards sit to its left/right.
/// Date and title are baked into each card PNG — no separate caption under the carousel.
struct ProgressTrackerView: View {
    @State private var focusedIndex = ProgressMilestone.cake.rawValue

    /// Visible page title (was “Log”).
    static let pageTitle = "History"

    /// Dex logo → back to Home (same asset / corner placement as HomeView).
    var onHome: () -> Void = {}
    /// Restart the cake story set from the blow-candles lesson.
    var onReplayCake: () -> Void = {}
    /// Restart the Grocery Day set from Push the cart.
    var onReplayTomato: () -> Void = {}

    private let milestones = ProgressMilestone.allCases
    private static let scrubSpring = Animation.spring(response: 0.38, dampingFraction: 0.82)

    var body: some View {
        GeometryReader { geo in
            let layout = HomeLayout(size: geo.size)
            let logo = HomeArtwork.logoSize
            let focusedSide = min(geo.size.width * 0.28, geo.size.height * 0.42, 320)
            let sideSide = focusedSide * 0.7
            let buttonGap: CGFloat = 76
            let pitch = focusedSide + buttonGap
            let centerX = geo.size.width / 2
            let cardY = geo.size.height * 0.48
            let titleY: CGFloat = 72
            let replayY = geo.size.height - 90

            ZStack(alignment: .topLeading) {
                Theme.background

                Button(action: onHome) {
                    Image(nsImage: HomeArtwork.logo)
                        .resizable()
                        .frame(width: logo.width * layout.unit * 1.02,
                               height: logo.height * layout.unit * 1.02)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: 34, y: 40)
                .accessibilityLabel("Home")

                Text(Self.pageTitle)
                    .font(Theme.headingFont)
                    .foregroundStyle(Theme.title)
                    .position(x: centerX, y: titleY)
                    .accessibilityAddTraits(.isHeader)

                ForEach(milestones) { milestone in
                    let relative = milestone.rawValue - focusedIndex
                    let focused = relative == 0
                    let visible = abs(relative) <= 1
                    let size = focused ? focusedSide : sideSide

                    card(for: milestone, side: size)
                        .rotationEffect(.degrees(Self.rotationDegrees(relative: relative)))
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

                if Self.showsReplay(for: milestones[focusedIndex]) {
                    PillButton(title: "Replay", style: .secondary, action: replayFocused)
                        .position(x: centerX, y: replayY)
                        .transition(.opacity)
                }
            }
            .animation(Self.scrubSpring, value: focusedIndex)
        }
    }

    private func card(for milestone: ProgressMilestone, side: CGFloat) -> some View {
        // Full card art already includes corner radius, date pill, and title.
        Image(nsImage: AppResources.image(milestone.imageName))
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
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

    private func replayFocused() {
        switch milestones[focusedIndex] {
        case .cake: onReplayCake()
        case .tomato: onReplayTomato()
        case .nextUp: break
        }
    }

    /// Left of center tilts +6°, right −6°, focused stays upright.
    static func rotationDegrees(relative: Int) -> Double {
        switch relative {
        case -1: return 6
        case 1: return -6
        default: return 0
        }
    }

    /// Replay is available for completed sets (tomato / cake), not next-up.
    static func showsReplay(for milestone: ProgressMilestone) -> Bool {
        milestone != .nextUp
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

    /// Titles baked into the card art (for a11y / tests — not drawn separately).
    var title: String {
        switch self {
        case .tomato: return "Grocery Day"
        case .cake: return "It’s Celebratin’ Time"
        case .nextUp: return "Unlock Tomorrow"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .tomato: return "Grocery Day, Sep 19"
        case .cake: return "It’s Celebratin’ Time, Sep 20"
        case .nextUp: return "Unlock Tomorrow, Sep 21"
        }
    }
}
