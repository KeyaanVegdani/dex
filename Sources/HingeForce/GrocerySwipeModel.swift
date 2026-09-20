import Foundation
import CoreGraphics

struct GrocerySwipeSceneState: Equatable {
    var time = 0.0
    /// 0...1 along the fixed 30° slot path.
    var progress = 0.0
    var isComplete = false
    /// Seconds since a successful swipe, or nil while still swiping.
    var completionElapsed: Double?
}

/// Drives swipe-to-pay from MacBook pitch tilt (accelerometer). Card stays on the 30° path.
@MainActor
final class GrocerySwipeModel: ObservableObject {
    private static let frameInterval: TimeInterval = 1.0 / 60.0

    @Published private(set) var scene = GrocerySwipeSceneState()

    let accelerometer: Accelerometer
    private var baselinePitch: Double?
    private var previousTipAmount = 0.0
    private var startedAt = Date()
    private var lastTick = Date()
    private var completedAt: Date?
    private var timer: Timer?

    init(accelerometer: Accelerometer) {
        self.accelerometer = accelerometer
    }

    func start() {
        accelerometer.start()
        guard timer == nil else { return }
        startedAt = Date()
        lastTick = startedAt
        baselinePitch = nil
        previousTipAmount = 0
        completedAt = nil
        scene = GrocerySwipeSceneState()
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

        var state = scene
        state.time = now.timeIntervalSince(startedAt)

        if let completedAt {
            state.progress = 1
            state.isComplete = true
            state.completionElapsed = now.timeIntervalSince(completedAt)
            scene = state
            return
        }

        // Wait for intro before counting tilt.
        if state.time < LessonIntro.duration * 0.45 {
            if let pitch = accelerometer.pitchDegrees, baselinePitch == nil {
                baselinePitch = pitch
            }
            state.progress = 0
            scene = state
            return
        }

        guard let pitch = accelerometer.pitchDegrees else {
            scene = state
            return
        }

        if baselinePitch == nil {
            baselinePitch = pitch
            previousTipAmount = 0
        }

        let baseline = baselinePitch ?? pitch
        let tip = GrocerySwipe.tipAmount(pitchDegrees: pitch, baselinePitch: baseline)
        let tipRate = dt > 1e-6 ? max(0, (tip - previousTipAmount) / dt) : 0
        previousTipAmount = tip

        let progress = GrocerySwipe.progress(tipDegrees: tip,
                                             tipRateDegPerSec: tipRate,
                                             previous: state.progress)
        state.progress = progress

        if progress >= GrocerySwipe.successThreshold {
            completedAt = now
            state.progress = 1
            state.isComplete = true
            state.completionElapsed = 0
        }

        scene = state
    }
}
