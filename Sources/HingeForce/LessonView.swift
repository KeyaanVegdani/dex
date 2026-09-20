import SwiftUI

/// Lesson 1's page for a given moment: progress bar, candle scene and caption.
struct LessonPage: View {
    let scene: CandleSceneState
    let currentSegment: Int
    let title: String
    let subtitle: String
    var subtitleIsProblem = false
    var onContinue: () -> Void = {}

    var body: some View {
        LessonScaffold(currentSegment: currentSegment,
                       introTime: scene.time,
                       outroElapsed: scene.blowOutElapsed,
                       title: title,
                       subtitle: subtitle,
                       subtitleIsProblem: subtitleIsProblem,
                       onContinue: onContinue) { size in
            let cakeWidth = min(size.width * 0.34, size.height * 0.55)
            CandleScene(state: scene, width: cakeWidth)
                .frame(width: cakeWidth, height: cakeWidth * Illustration.cakeSize.height / Illustration.cakeSize.width)
                .position(x: size.width / 2, y: size.height * 0.5)
        }
    }
}

/// Lesson 1: blow out the candles using the microphone.
struct LessonView: View {
    @StateObject private var model: LessonModel
    @ObservedObject private var mic: MicMonitor
    private let onContinue: () -> Void

    init(mic: MicMonitor, onContinue: @escaping () -> Void) {
        self.mic = mic
        self.onContinue = onContinue
        _model = StateObject(wrappedValue: LessonModel(mic: mic))
    }

    var body: some View {
        LessonPage(scene: model.scene,
                   currentSegment: 0,
                   title: "Make a wish & blow out the candles",
                   subtitle: subtitle,
                   subtitleIsProblem: isProblem,
                   onContinue: onContinue)
            .overlay(alignment: .topTrailing) {
                // Testing affordance: jump past blow-out to the cut lesson.
                PillButton(title: "Skip", style: .secondary, action: onContinue)
                    .padding(24)
            }
            .overlay(alignment: .bottomLeading) { micReadout.padding(20) }
            .onAppear { model.start() }
            .onDisappear {
                model.stop()
                mic.stop()
            }
    }

    /// Small readout of which microphone is being listened to, for checking while testing.
    private var micReadout: some View {
        Text(mic.inputDeviceName.map { "mic: \($0)" } ?? "")
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(Color(white: 0.6))
    }

    private var subtitle: String {
        switch mic.status {
        case .idle, .listening: return "Blow into the left side of your laptop"
        case .calibrating: return "Getting ready… stay quiet for a moment"
        case .denied: return "Microphone access is off. Allow it in System Settings › Privacy & Security › Microphone."
        case .unavailable(let reason): return reason
        }
    }

    private var isProblem: Bool {
        switch mic.status {
        case .denied, .unavailable: return true
        default: return false
        }
    }
}
