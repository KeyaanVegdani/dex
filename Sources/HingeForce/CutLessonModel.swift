import Foundation

/// Runs the cutting lesson: follows the lid's hinge angle, picks the cut line, and decides when the
/// knife has been held on it long enough. Runs its own 60 fps clock.
@MainActor
final class CutLessonModel: ObservableObject {
    /// How quickly the drawn knife follows the sensor, in seconds (the sensor reports whole degrees).
    static let smoothing: TimeInterval = 0.08
    private static let frameInterval: TimeInterval = 1.0 / 60.0

    @Published private(set) var scene = CutSceneState()
    @Published private(set) var isComplete = false

    let lid: LidAngleSensor
    private var tracker = AlignmentTracker()
    private var displayedHinge: Double?
    private var target: Double?
    private var startedAt = Date()
    private var lastTick = Date()
    private var completedAt: Date?
    private var timer: Timer?

    init(lid: LidAngleSensor) {
        self.lid = lid
    }

    func start() {
        lid.start()
        guard timer == nil else { return }
        startedAt = Date()
        lastTick = startedAt
        timer = Timer.scheduledTimer(withTimeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let now = Date()
        let dt = min(now.timeIntervalSince(lastTick), 0.1)
        lastTick = now

        var state = CutSceneState()
        state.time = now.timeIntervalSince(startedAt)

        if let reading = lid.angle {
            let shown = displayedHinge.map { $0 + (reading - $0) * (1 - exp(-dt / Self.smoothing)) } ?? reading
            displayedHinge = shown

            // The cut line is chosen from wherever the lid is when the first reading arrives.
            if target == nil { target = HingeCut.randomTarget(current: reading) }

            if let target, completedAt == nil {
                tracker.update(onLine: HingeCut.isOnLine(hinge: shown, target: target), dt: dt)
                if tracker.isComplete {
                    completedAt = now
                    isComplete = true
                }
            }
        }

        state.hinge = displayedHinge
        state.target = target
        state.alignment = tracker.isComplete ? 1 : tracker.progress
        state.completionElapsed = completedAt.map { now.timeIntervalSince($0) }
        scene = state
    }
}
