import Foundation
import CoreGraphics

struct GroceryTossSceneState {
    var time = 0.0
    /// 0...1 along the toss path (above cart → inside basket).
    var progress = 0.0
    /// Seconds since the tomato landed, or nil while still tossing.
    var completionElapsed: Double?
}

/// Drives the tomato toss from lid fold speed (angle decreasing).
@MainActor
final class GroceryTossModel: ObservableObject {
    private static let frameInterval: TimeInterval = 1.0 / 60.0

    @Published private(set) var scene = GroceryTossSceneState()

    let lid: LidAngleSensor
    private var previousAngle: Double?
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
        previousAngle = lid.angle
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

        var state = GroceryTossSceneState()
        state.time = now.timeIntervalSince(startedAt)

        if let completedAt {
            state.progress = 1
            state.completionElapsed = now.timeIntervalSince(completedAt)
            scene = state
            return
        }

        // Wait for intro before counting folds.
        if state.time < LessonIntro.duration * 0.55 {
            previousAngle = lid.angle
            state.progress = scene.progress
            scene = state
            return
        }

        var progress = scene.progress
        if let angle = lid.angle {
            if let previous = previousAngle {
                let speed = GroceryToss.foldSpeed(previous: previous, current: angle, dt: dt)
                progress = min(progress + GroceryToss.progressDelta(foldSpeed: speed, dt: dt), 1)
            }
            previousAngle = angle
        }

        state.progress = progress
        if progress >= 1 {
            completedAt = now
            state.completionElapsed = 0
        }
        scene = state
    }
}
