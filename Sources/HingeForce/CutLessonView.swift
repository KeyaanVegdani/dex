import SwiftUI

/// The cutting lesson's page for a given moment.
struct CutLessonPage: View {
    let scene: CutSceneState
    let title: String
    let subtitle: String
    var subtitleIsProblem = false
    var onContinue: () -> Void = {}

    /// Time after completing before the Continue button appears; the white line is left to sink in first.
    static let continueStart = 0.6

    var body: some View {
        LessonScaffold(currentSegment: 1,
                       introTime: scene.time,
                       outroElapsed: scene.completionElapsed,
                       title: title,
                       subtitle: subtitle,
                       subtitleIsProblem: subtitleIsProblem,
                       continueStart: Self.continueStart,
                       onContinue: onContinue) { size in
            // The cake sits in the middle of the screen. The knife reaches about a cake-width from the
            // cake's centre and may pass behind the progress bar, which is drawn above it.
            let unit = min(size.width * 0.3 / Illustration.cutCakeSize.width,
                           size.height * 0.42 / Illustration.cutCakeSize.height)
            let width = Illustration.cutCakeSize.width * unit

            CutScene(state: scene, width: width)
                .frame(width: width, height: Illustration.cutCakeSize.height * unit)
                .position(x: size.width / 2, y: size.height / 2)
        }
        .overlay(alignment: .bottomLeading) { hingeReadout(scene).padding(20) }
    }

    /// Small readout of the numbers behind the picture, for checking the sensor while testing.
    private func hingeReadout(_ scene: CutSceneState) -> some View {
        Group {
            if let hinge = scene.hinge, let target = scene.target {
                Text(String(format: "hinge %.0f°   line %.0f°   off by %.0f°", hinge, target, abs(hinge - target)))
            }
        }
        .font(.system(size: 13, design: .monospaced))
        .foregroundStyle(Color(white: 0.6))
    }
}

/// Lesson 2: turn the lid's hinge to bring the knife onto the cut line.
struct CutLessonView: View {
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
