import Foundation

/// Runs the washing lesson: turns the laptop's tilt into the shower's swing, tracks how long the water
/// has been on each mess, and decides when the plate is clean. Runs its own 60 fps clock.
@MainActor
final class WashLessonModel: ObservableObject {
    /// How quickly the drawn shower follows the tilt, in seconds.
    static let smoothing: TimeInterval = 0.08
    private static let frameInterval: TimeInterval = 1.0 / 60.0

    @Published private(set) var scene = WashSceneState()
    @Published private(set) var isComplete = false

    let accelerometer: Accelerometer
    private var tracker = WashTracker()
    private var displayedSwing = 0.0
    private var startedAt = Date()
    private var lastTick = Date()
    private var completedAt: Date?
    private var timer: Timer?
    private var tickCount = 0

    init(accelerometer: Accelerometer) {
        self.accelerometer = accelerometer
    }

    func start() {
        accelerometer.start()
        guard timer == nil else { return }
        startedAt = Date()
        lastTick = startedAt
        DebugLog.write("=== WashLessonModel.start() ===")
        timer = Timer.scheduledTimer(withTimeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        accelerometer.stop()
    }

    private func tick() {
        let now = Date()
        let dt = min(now.timeIntervalSince(lastTick), 0.1)
        lastTick = now

        // The shower keeps still once the plate is clean.
        if completedAt == nil {
            let target = WashCut.swing(forRoll: accelerometer.rollDegrees ?? 0)
            displayedSwing += (target - displayedSwing) * (1 - exp(-dt / Self.smoothing))
            tracker.update(swing: displayedSwing, dt: dt)
            if tracker.isComplete {
                completedAt = now
                isComplete = true
            }
        }

        var state = WashSceneState()
        state.time = now.timeIntervalSince(startedAt)
        state.swing = displayedSwing
        state.washed = tracker.washed
        state.completionElapsed = completedAt.map { now.timeIntervalSince($0) }
        scene = state

        tickCount += 1
        if tickCount % 15 == 0, let g = accelerometer.gravity {
            DebugLog.write(String(format: "wash accel x=%.3f y=%.3f z=%.3f roll=%.1f swing=%.1f washed=%@",
                                  g.x, g.y, g.z, accelerometer.rollDegrees ?? 0, displayedSwing,
                                  tracker.washed.map { String(format: "%.1f", $0) }.joined(separator: ",")))
        }
    }
}
