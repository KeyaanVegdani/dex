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

        LessonScaffold(currentSegment: 1,
                       introTime: model.scene.time,
                       outroElapsed: good ? model.scene.completionElapsed : nil,
                       title: title(for: phase),
                       subtitle: burst ? " " : (good ? " " : GroceryTomato.subtitleSquish),
                       continueStart: GroceryTomato.continueStart,
                       contentAllowsHits: phase == .squishing,
                       onContinue: onContinue) { size in
            let side = min(size.width * 0.34, size.height * 0.42, 320)
            ZStack {
                if phase == .squishing {
                    ForcePad(model: force)
                        .frame(width: side * 0.92, height: side * 0.78)
                        .contentShape(Ellipse())
                }

                GroceryTomatoScene(state: model.scene, side: side)
                    .allowsHitTesting(false)
            }
            .frame(width: size.width, height: size.height)
        }
        .overlay {
            if burst {
                VStack {
                    Spacer()
                    // Subheading replaced by the reset pill (Jane’s exact label).
                    PillButton(title: GroceryTomato.getAnotherTitle, style: .secondary) {
                        model.getAnother()
                    }
                    .padding(.bottom, 90)
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
