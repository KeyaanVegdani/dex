import Foundation
import CoreGraphics

struct GroceryTossSceneState {
    var time = 0.0
    /// 0...1 along the toss path (hand → apex → basket).
    var progress = 0.0
    /// Seconds since the tomato landed, or nil while still tossing.
    var completionElapsed: Double?
}

/// Drives the tomato toss: fold under ~45° sets impulse, then momentum finishes the arc.
@MainActor
final class GroceryTossModel: ObservableObject {
    private static let frameInterval: TimeInterval = 1.0 / 60.0

    @Published private(set) var scene = GroceryTossSceneState()

    let lid: LidAngleSensor
    private var previousAngle: Double?
    private var impulseDegrees = 0.0
    private var coastSpeed = 0.0
    private var inFlight = false
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
        impulseDegrees = 0
        coastSpeed = 0
        inFlight = false
        completedAt = nil
        scene = GroceryTossSceneState()
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

        if inFlight {
            // Momentum owns the arc — hinge slowdown cannot stall the toss.
            progress = min(progress + GroceryToss.coastProgressDelta(coastSpeed: coastSpeed,
                                                                     progress: progress,
                                                                     dt: dt), 1)
            if let angle = lid.angle {
                previousAngle = angle
            }
        } else if let angle = lid.angle {
            if let previous = previousAngle {
                let speed = GroceryToss.foldSpeed(previous: previous, current: angle, dt: dt)
                impulseDegrees += GroceryToss.impulseDelta(foldSpeed: speed, angle: angle, dt: dt)
                if impulseDegrees >= GroceryToss.launchImpulseDegrees {
                    inFlight = true
                    coastSpeed = GroceryToss.coastSpeed(fromImpulse: impulseDegrees)
                    progress = min(progress + GroceryToss.coastProgressDelta(coastSpeed: coastSpeed,
                                                                             progress: progress,
                                                                             dt: dt), 1)
                }
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
