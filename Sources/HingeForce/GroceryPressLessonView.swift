import SwiftUI

/// Grocery Day step 3 — placeholder reuses the cake trackpad-press lesson.
/// Jane: swap `PressLessonPage` / `PressScene` for the new activity; keep `onContinue`.
struct GroceryPressLessonView: View {
    @StateObject private var model: PressLessonModel
    private let force: TrackpadForce
    private let onContinue: () -> Void

    init(force: TrackpadForce, onContinue: @escaping () -> Void) {
        self.force = force
        self.onContinue = onContinue
        _model = StateObject(wrappedValue: PressLessonModel(force: force))
    }

    var body: some View {
        PressLessonPage(scene: model.scene, force: force, onContinue: onContinue)
            .onAppear { model.start() }
            .onDisappear { model.stop() }
    }
}
