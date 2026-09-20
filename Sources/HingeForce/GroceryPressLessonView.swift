import SwiftUI

/// Grocery Day step 3: fold the lid to toss the tomato into the cart.
struct GroceryPressLessonView: View {
    @StateObject private var model: GroceryTossModel
    @ObservedObject private var lid: LidAngleSensor
    private let onContinue: () -> Void

    init(lid: LidAngleSensor, onContinue: @escaping () -> Void) {
        self.lid = lid
        self.onContinue = onContinue
        _model = StateObject(wrappedValue: GroceryTossModel(lid: lid))
    }

    var body: some View {
        LessonScaffold(currentSegment: 2,
                       introTime: model.scene.time,
                       outroElapsed: model.scene.completionElapsed,
                       title: GroceryToss.title,
                       subtitle: subtitle,
                       subtitleIsProblem: isProblem,
                       continueStart: GroceryToss.continueStart,
                       onContinue: onContinue) { size in
            GroceryTossScene(state: model.scene, size: size)
        }
        .overlay(alignment: .topTrailing) {
            PillButton(title: "Skip", style: .secondary, action: onContinue)
                .padding(24)
        }
        .overlay(alignment: .bottomLeading) { hingeReadout.padding(20) }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var subtitle: String {
        if case .unavailable(let reason) = lid.status { return reason }
        return GroceryToss.subtitle
    }

    private var isProblem: Bool {
        if case .unavailable = lid.status { return true }
        return false
    }

    private var hingeReadout: some View {
        Text(lid.angle.map { String(format: "hinge %.0f°", $0) } ?? "hinge —")
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(Color(white: 0.6))
    }
}
