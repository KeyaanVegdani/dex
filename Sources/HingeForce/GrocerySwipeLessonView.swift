import SwiftUI

/// Grocery Day step 4: tilt the MacBook down to swipe the card through the reader.
struct GrocerySwipeLessonView: View {
    @StateObject private var model: GrocerySwipeModel
    @ObservedObject private var accelerometer: Accelerometer
    private let onContinue: () -> Void

    init(accelerometer: Accelerometer, onContinue: @escaping () -> Void) {
        self.accelerometer = accelerometer
        self.onContinue = onContinue
        _model = StateObject(wrappedValue: GrocerySwipeModel(accelerometer: accelerometer))
    }

    var body: some View {
        LessonScaffold(currentSegment: 3,
                       introTime: model.scene.time,
                       outroElapsed: model.scene.completionElapsed,
                       title: GrocerySwipe.title,
                       subtitle: subtitle,
                       subtitleIsProblem: isProblem,
                       continueStart: GrocerySwipe.continueStart,
                       onContinue: onContinue) { size in
            GrocerySwipeScene(state: model.scene, size: size)
        }
        .overlay(alignment: .topTrailing) {
            PillButton(title: "Skip", style: .secondary, action: onContinue)
                .padding(24)
        }
        .overlay(alignment: .bottomLeading) { tiltReadout.padding(20) }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var subtitle: String {
        if case .unavailable(let reason) = accelerometer.status { return reason }
        return GrocerySwipe.subtitle
    }

    private var isProblem: Bool {
        if case .unavailable = accelerometer.status { return true }
        return false
    }

    private var tiltReadout: some View {
        Text(accelerometer.pitchDegrees.map { String(format: "tilt %.0f°", $0) } ?? "tilt —")
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(Color(white: 0.6))
    }
}
