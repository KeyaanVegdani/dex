import SwiftUI

/// The pressing lesson's page for a given moment.
struct PressLessonPage: View {
    let scene: PressSceneState
    /// Catches the trackpad press; nil when only drawing (previews, tests).
    var force: TrackpadForce?
    var onContinue: () -> Void = {}

    var body: some View {
        LessonScaffold(currentSegment: 2,
                       introTime: scene.time,
                       outroElapsed: scene.completionElapsed,
                       title: "Press and hold to cut the slice",
                       subtitle: "Press and hold down on your trackpad",
                       continueStart: PressCut.continueStart,
                       contentAllowsHits: true,
                       onContinue: onContinue) { size in
            // The plate and the whole cake, without the raised knife, are centred on the screen.
            let unit = min(size.width * 0.30 / Illustration.pressPlateSize.width,
                           size.height * 0.36 / 289)
            let origin = CGPoint(x: size.width / 2 - 232.136 * unit,
                                 y: size.height / 2 + 23.5 * unit)

            ZStack {
                // The whole window listens for the press; the artwork above ignores the pointer.
                if let force { ForcePad(model: force) }

                PressScene(state: scene, unit: unit)
                    .position(x: origin.x + Illustration.pressPlateSize.width * unit / 2,
                              y: origin.y + Illustration.pressPlateSize.height * unit / 2)
            }
        }
    }
}

/// Lesson 3: press down on the trackpad to push the knife through the cake.
struct PressLessonView: View {
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
