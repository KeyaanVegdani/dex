import Foundation

struct GroceryCartSceneState {
    /// Seconds since the page appeared.
    var time = 0.0
    /// 0...1 along the top-left → bottom-right path.
    var progress = 0.0
    /// Smoothed blow strength 0...1 (drives speed and trail length).
    var intensity = 0.0
    /// Seconds since the cart reached the end, or nil while still pushing.
    var completionElapsed: Double?
}

/// Turns the live microphone reading into cart motion along the grocery aisle path.
@MainActor
final class GroceryCartModel: ObservableObject {
    static let smoothing: TimeInterval = 0.08
    private static let frameInterval: TimeInterval = 1.0 / 60.0

    @Published private(set) var scene = GroceryCartSceneState()
    @Published private(set) var isComplete = false

    let mic: MicMonitor
    private var displayedIntensity = 0.0
    private var startedAt = Date()
    private var lastTick = Date()
    private var completedAt: Date?
    private var timer: Timer?

    init(mic: MicMonitor) {
        self.mic = mic
    }

    func start() {
        mic.start()
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

        var state = GroceryCartSceneState()
        state.time = now.timeIntervalSince(startedAt)

        if let completedAt {
            state.progress = 1
            state.intensity = displayedIntensity
            state.completionElapsed = now.timeIntervalSince(completedAt)
            scene = state
            return
        }

        let target = GroceryCart.intensity(reading: mic.blowReading)
        displayedIntensity += (target - displayedIntensity) * (1 - exp(-dt / Self.smoothing))
        state.intensity = displayedIntensity

        // Ignore the mic until the scaffold intro has mostly settled.
        if state.time >= LessonIntro.duration * 0.6 {
            let next = min(scene.progress + GroceryCart.progressDelta(intensity: displayedIntensity, dt: dt), 1)
            state.progress = next
            if next >= 1 {
                completedAt = now
                state.completionElapsed = 0
                isComplete = true
            }
        } else {
            state.progress = scene.progress
        }

        scene = state
    }
}
