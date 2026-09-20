import SwiftUI

/// Grocery Day step 1 — placeholder reuses the cake blow-out lesson (same Theme / scaffold / Skip).
/// Jane: swap `LessonPage` / `CandleScene` for the new Grocery Day activity; keep `onContinue`.
struct GroceryLessonView: View {
    @StateObject private var model: LessonModel
    @ObservedObject private var mic: MicMonitor
    private let onContinue: () -> Void

    init(mic: MicMonitor, onContinue: @escaping () -> Void) {
        self.mic = mic
        self.onContinue = onContinue
        _model = StateObject(wrappedValue: LessonModel(mic: mic))
    }

    var body: some View {
        // Same copy & styling as cake for now — replace title/subtitle/scene when Grocery Day is ready.
        LessonPage(scene: model.scene,
                   currentSegment: 0,
                   title: "Make a wish & blow out the candles",
                   subtitle: subtitle,
                   subtitleIsProblem: isProblem,
                   onContinue: onContinue)
            .overlay(alignment: .topTrailing) {
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
