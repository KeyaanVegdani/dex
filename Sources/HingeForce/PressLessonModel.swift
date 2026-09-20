import Foundation

/// Runs the pressing lesson: follows the trackpad's pressure, lowers the knife with it, and decides
/// when the press has reached the bottom. Runs its own 60 fps clock.
@MainActor
final class PressLessonModel: ObservableObject {
    /// How quickly the drawn knife follows a firmer press, and how quickly it rises when you ease off.
    static let pressSmoothing: TimeInterval = 0.04
    static let releaseSmoothing: TimeInterval = 0.12
    private static let frameInterval: TimeInterval = 1.0 / 60.0

    @Published private(set) var scene = PressSceneState()
    @Published private(set) var isComplete = false

    let force: TrackpadForce
    private var tracker = PressTracker()
    private var displayedReading = 1.0
    private var startedAt = Date()
    private var lastTick = Date()
    private var completedAt: Date?
    private var depthAtCompletion = 0.0
    private var timer: Timer?
    private var tickCount = 0
    private var previousDepth = 0.0

    init(force: TrackpadForce) {
        self.force = force
    }

    func start() {
        guard timer == nil else { return }
        force.release()
        startedAt = Date()
        lastTick = startedAt
        DebugLog.write("=== PressLessonModel.start() ===")
        timer = Timer.scheduledTimer(withTimeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        force.release()
        SoundEffects.shared.stopCut()
    }

    private func tick() {
        let now = Date()
        let dt = min(now.timeIntervalSince(lastTick), 0.1)
        lastTick = now

        var state = PressSceneState()
        state.time = now.timeIntervalSince(startedAt)

        if let completedAt {
            let elapsed = now.timeIntervalSince(completedAt)
            state.completionElapsed = elapsed
            state.depth = PressCut.settledDepth(from: depthAtCompletion, elapsed: elapsed)
        } else {
            let reading = force.pressureReading
            let tau = reading > displayedReading ? Self.pressSmoothing : Self.releaseSmoothing
            displayedReading += (reading - displayedReading) * (1 - exp(-dt / tau))
            state.depth = PressCut.depth(forReading: displayedReading)

            tracker.update(reading: reading, dt: dt)

            // The knife's sound goes on for as long as it is being pushed through, following how deep it is and how
            // fast it moves.
            let speed = dt > 0 ? (state.depth - previousDepth) / dt : 0
            previousDepth = state.depth
            SoundEffects.shared.setCut(level: CutSoundLevel.level(depth: state.depth, speed: speed, pressing: force.isPressed),
                                       depth: state.depth)

            if tracker.isComplete {
                completedAt = now
                depthAtCompletion = state.depth
                state.completionElapsed = 0
                isComplete = true
                SoundEffects.shared.stopCut()
                SoundEffects.shared.play(.partFinished)
            }

            tickCount += 1
            if force.isPressed, tickCount % 15 == 0 {
                DebugLog.write(String(format: "press raw=%.3f stage=%d reading=%.2f depth=%.2f hold=%.2f",
                                      force.pressure, force.stage, reading, state.depth, tracker.progress))
            }
        }
        scene = state
    }
}
