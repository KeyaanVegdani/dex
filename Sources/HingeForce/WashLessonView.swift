import SwiftUI

/// The washing lesson's page for a given moment.
struct WashLessonPage: View {
    let scene: WashSceneState
    var problem: String?
    var onFinish: () -> Void = {}

    /// Where the plate's top edge sits, as a fraction of the window height, while washing.
    static let plateTop: CGFloat = 0.541

    var body: some View {
        LessonScaffold(currentSegment: 3,
                       introTime: scene.time,
                       outroElapsed: scene.completionElapsed,
                       title: "Don’t forget to wash the dishes",
                       subtitle: problem ?? "Rotate your laptop to move the direction of water",
                       subtitleIsProblem: problem != nil,
                       continueTitle: "Finish",
                       continueStart: WashCut.continueStart,
                       onContinue: onFinish) { size in
            // The shower head and its pipe reach about 330 units above the plate; keep them clear of the bar.
            let unit = min(size.width * 0.3075 / Illustration.pressPlateSize.width,
                           (size.height * Self.plateTop - 120) / 327)
            let plate = Illustration.pressPlateSize
            let top = size.height * Self.plateTop + CGFloat(WashCut.plateOffset(elapsed: scene.completionElapsed)) * unit

            WashScene(state: scene, unit: unit)
                .position(x: size.width / 2 + (plate.width / 2 - 232.136) * unit,
                          y: top + plate.height * unit / 2)
        }
    }
}

/// Lesson 4: tip the laptop to steer the shower and wash the plate clean.
struct WashLessonView: View {
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
