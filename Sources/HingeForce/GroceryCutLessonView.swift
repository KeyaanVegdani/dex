import SwiftUI

/// Grocery Day step 2: Force Touch squish — dent + darken, or break / gentle success.
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
        let broken = model.scene.phase == .broken
        let succeeded = model.scene.phase == .succeeded

        LessonScaffold(currentSegment: 1,
                       introTime: model.scene.time,
                       outroElapsed: succeeded ? model.scene.completionElapsed : nil,
                       title: broken ? "Oops, you broke it" : "Gently squish the tomato",
                       subtitle: broken ? " " : "Tap the tomato with one finger.",
                       continueStart: GroceryTomato.continueStart,
                       contentAllowsHits: !broken && !succeeded,
                       onContinue: onContinue) { size in
            let side = min(size.width * 0.34, size.height * 0.42, 320)
            ZStack {
                if !broken && !succeeded {
                    // Force pad only over the tomato so presses must land on it.
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
            if broken {
                VStack {
                    Spacer()
                    PillButton(title: "Pick out another tomato", style: .secondary) {
                        model.pickAnother()
                    }
                    .padding(.bottom, 90)
                }
                .transition(.opacity)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !broken {
                PillButton(title: "Skip", style: .secondary, action: onContinue)
                    .padding(24)
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}
