import SwiftUI

/// The Test System section: check the hinge, microphone, trackpad and rotation one after another.
struct TestSystemView: View {
    enum Step { case hinge, calibrate, blow, trackpad, rotate }

    let lid: LidAngleSensor
    let mic: MicMonitor
    let force: TrackpadForce
    let accelerometer: Accelerometer
    let onExit: () -> Void

    @StateObject private var model: TestModel
    @ObservedObject private var micStatus: MicMonitor
    @State private var step: Step = .hinge
    /// When (on the model's clock) the current page appeared, so its own animations start from zero.
    @State private var stepStart = 0.0

    init(lid: LidAngleSensor, mic: MicMonitor, force: TrackpadForce, accelerometer: Accelerometer, onExit: @escaping () -> Void) {
        self.lid = lid
        self.mic = mic
        self.force = force
        self.accelerometer = accelerometer
        self.onExit = onExit
        self.micStatus = mic
        _model = StateObject(wrappedValue: TestModel(lid: lid, mic: mic, force: force, accelerometer: accelerometer))
    }

    var body: some View {
        ZStack {
            switch step {
            case .hinge:
                HingeTestPage(state: model.state) { go(to: .calibrate) }
                    .transition(.opacity)
            case .calibrate:
                HangTightPage(time: model.state.time - stepStart, problem: micProblem) { go(to: .trackpad) }
                    .transition(.opacity)
            case .blow:
                MicTestPage(state: model.state) { go(to: .trackpad) }
                    .transition(.opacity)
            case .trackpad:
                TrackpadTestPage(state: model.state, force: force) { go(to: .rotate) }
                    .transition(.opacity)
            case .rotate:
                RotateTestPage(state: model.state) { finish() }
                    .transition(.opacity)
            }
        }
        .onAppear {
            model.start()
            lid.start()
        }
        .onDisappear { stopEverything() }
        // The microphone is ready once it has learned the background noise.
        .onChange(of: micStatus.thresholdDB) { _, threshold in
            if step == .calibrate, threshold != nil { go(to: .blow) }
        }
        .onExitCommand { finish() }
    }

    /// Why the microphone can't be used, if it can't.
    private var micProblem: String? {
        switch micStatus.status {
        case .denied: return "Microphone access is off. Allow it in System Settings › Privacy & Security › Microphone."
        case .unavailable(let reason): return reason
        default: return nil
        }
    }

    private func go(to next: Step) {
        let leaving = step
        stepStart = model.state.time
        withAnimation(.easeInOut(duration: 0.25)) { step = next }

        // Switch on what the next page needs, and off what the last one used.
        if leaving == .blow || (leaving == .calibrate && next == .trackpad) { mic.stop() }
        switch next {
        case .hinge: lid.start()
        case .calibrate:
            mic.start()
            // If the microphone has already learned the room there is nothing to wait for.
            if mic.thresholdDB != nil { withAnimation(.easeInOut(duration: 0.25)) { step = .blow } }
        case .blow: break
        case .trackpad: force.release()
        case .rotate: accelerometer.start()
        }
        if leaving == .rotate { accelerometer.stop() }
    }

    private func finish() {
        stopEverything()
        onExit()
    }

    private func stopEverything() {
        model.stop()
        lid.stop()
        mic.stop()
        force.release()
        accelerometer.stop()
    }
}
