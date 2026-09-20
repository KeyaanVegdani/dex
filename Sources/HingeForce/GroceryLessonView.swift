import SwiftUI

/// Grocery Day step 1: blow to push the cart down the aisle (top-left → bottom-right).
/// Jane: later grocery steps plug in after `onContinue`; keep Skip + LessonScaffold chrome.
struct GroceryLessonView: View {
    @StateObject private var model: GroceryCartModel
    @ObservedObject private var mic: MicMonitor
    private let onContinue: () -> Void

    init(mic: MicMonitor, onContinue: @escaping () -> Void) {
        self.mic = mic
        self.onContinue = onContinue
        _model = StateObject(wrappedValue: GroceryCartModel(mic: mic))
    }

    var body: some View {
        LessonScaffold(currentSegment: 0,
                       introTime: model.scene.time,
                       outroElapsed: model.scene.completionElapsed,
                       title: "Push the cart",
                       subtitle: subtitle,
                       subtitleIsProblem: isProblem,
                       continueStart: GroceryCart.continueStart,
                       onContinue: onContinue) { size in
            GroceryCartScene(state: model.scene, size: size)
        }
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
        case .idle, .listening: return "Blow into the left side of your laptop."
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
