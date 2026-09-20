import SwiftUI

/// Grocery Day step 4: click-and-drag swipe to pay on the trackpad/mouse.
struct GrocerySwipeLessonView: View {
    @StateObject private var model: GrocerySwipeModel
    private let force: TrackpadForce
    private let onContinue: () -> Void

    init(force: TrackpadForce, onContinue: @escaping () -> Void) {
        self.force = force
        self.onContinue = onContinue
        _model = StateObject(wrappedValue: GrocerySwipeModel(force: force))
    }

    var body: some View {
        LessonScaffold(currentSegment: 3,
                       introTime: model.scene.time,
                       outroElapsed: model.scene.completionElapsed,
                       title: GrocerySwipe.title,
                       subtitle: GrocerySwipe.subtitle,
                       continueStart: GrocerySwipe.continueStart,
                       contentAllowsHits: !model.scene.isComplete,
                       onContinue: onContinue) { size in
            GrocerySwipeScene(state: model.scene, size: size, force: force)
                .task(id: sizeEqualId(size)) {
                    model.updateContentSize(size)
                }
        }
        .overlay(alignment: .topTrailing) {
            PillButton(title: "Skip", style: .secondary, action: onContinue)
                .padding(24)
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

private func sizeEqualId(_ size: CGSize) -> String {
    "\(Int(size.width))x\(Int(size.height))"
}
