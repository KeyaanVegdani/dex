import SwiftUI

/// Grocery Day step 2: Force Touch squish — too soft / good / too hard.
struct GroceryCutLessonView: View {
    @StateObject private var model: GroceryTomatoModel
    private let force: TrackpadForce
    private let onContinue: () -> Void

    init(force: TrackpadForce, onContinue: @escaping () -> Void) {
        self.force = force
        self.onContinue = onContinue
        _model = StateObject(wrappedValue: GroceryTomatoModel(force: force))
    }

    var body: some View {
        let phase = model.scene.phase
        let burst = phase.isBurst
        let good = phase == .good

        // No small PillButton variant exists — keep the standard pill and stack heading above it
        // with clear spacing so they never overlap (see tomato-button-overlap-bug).
        LessonScaffold(currentSegment: 1,
                       introTime: model.scene.time,
                       outroElapsed: good ? model.scene.completionElapsed : nil,
                       title: burst ? "" : title(for: phase),
                       subtitle: burst || good ? "" : GroceryTomato.subtitleSquish,
                       continueStart: GroceryTomato.continueStart,
                       contentAllowsHits: phase == .squishing,
                       onContinue: onContinue) { size in
            let side = min(size.width * 0.34, size.height * 0.42, 320)
            ZStack {
                if phase == .squishing {
                    // Same frame as the tomato art so locationNorm maps 1:1 onto the dent.
                    ForcePad(model: force)
                        .frame(width: side, height: side)
                        .contentShape(Ellipse())
                }

                GroceryTomatoScene(state: model.scene, side: side)
                    .allowsHitTesting(false)
            }
            .frame(width: size.width, height: size.height)
        }
        .overlay {
            if burst {
                VStack(spacing: 28) {
                    Spacer()
                    Text(title(for: phase))
                        .font(Theme.headingFont)
                        .foregroundStyle(Theme.title)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    PillButton(title: GroceryTomato.getAnotherTitle, style: .secondary) {
                        model.getAnother()
                    }
                    .padding(.bottom, 56)
                }
                .transition(.opacity)
            }
        }
        .overlay(alignment: .topTrailing) {
            if phase == .squishing {
                PillButton(title: "Skip", style: .secondary, action: onContinue)
                    .padding(24)
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private func title(for phase: GroceryTomatoPhase) -> String {
        switch phase {
        case .squishing: return GroceryTomato.titleSquish
        case .tooSoft: return GroceryTomato.titleTooSoft
        case .good: return GroceryTomato.titleGood
        case .tooHard: return GroceryTomato.titleTooHard
        }
    }
}
