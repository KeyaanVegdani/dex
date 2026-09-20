import SwiftUI

/// Grocery Day step 4 — placeholder reuses the cake wash lesson.
/// Jane: swap `WashLessonPage` / `WashScene` for the new activity; keep `onFinish` → Log.
struct GroceryWashLessonView: View {
    @StateObject private var model: WashLessonModel
    @ObservedObject private var accelerometer: Accelerometer
    private let onFinish: () -> Void

    init(accelerometer: Accelerometer, onFinish: @escaping () -> Void) {
        self.accelerometer = accelerometer
        self.onFinish = onFinish
        _model = StateObject(wrappedValue: WashLessonModel(accelerometer: accelerometer))
    }

    var body: some View {
        WashLessonPage(scene: model.scene, problem: problem, onFinish: onFinish)
            .onAppear { model.start() }
            .onDisappear { model.stop() }
    }

    private var problem: String? {
        if case .unavailable(let reason) = accelerometer.status { return reason }
        return nil
    }
}
