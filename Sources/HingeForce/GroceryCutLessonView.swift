import SwiftUI

/// Grocery Day step 2 — placeholder reuses the cake hinge-cut lesson.
/// Jane: swap `CutLessonPage` / `CutScene` for the new activity; keep `onContinue`.
struct GroceryCutLessonView: View {
    @StateObject private var model: CutLessonModel
    @ObservedObject private var lid: LidAngleSensor
    private let onContinue: () -> Void

    init(lid: LidAngleSensor, onContinue: @escaping () -> Void) {
        self.lid = lid
        self.onContinue = onContinue
        _model = StateObject(wrappedValue: CutLessonModel(lid: lid))
    }

    var body: some View {
        CutLessonPage(scene: model.scene,
                      title: "How about we cut a slice?",
                      subtitle: subtitle,
                      subtitleIsProblem: isProblem,
                      onContinue: onContinue)
            .onAppear { model.start() }
            .onDisappear { model.stop() }
    }

    private var subtitle: String {
        if case .unavailable(let reason) = lid.status { return reason }
        return "Move the hinge of your laptop to the asked slice size"
    }

    private var isProblem: Bool {
        if case .unavailable = lid.status { return true }
        return false
    }
}
