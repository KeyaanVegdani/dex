import Foundation

enum GroceryTomatoPhase: Equatable {
    case squishing
    case broken
    case succeeded
}

struct GroceryTomatoSceneState: Equatable {
    var time = 0.0
    /// Smoothed press depth 0...1.
    var depth = 0.0
    var phase = GroceryTomatoPhase.squishing
    /// Seconds since gentle success (nil until then).
    var completionElapsed: Double?
}

/// Runs the tomato-squish lesson from Force Touch pressure.
@MainActor
final class GroceryTomatoModel: ObservableObject {
    static let pressSmoothing: TimeInterval = 0.04
    static let releaseSmoothing: TimeInterval = 0.12
    private static let frameInterval: TimeInterval = 1.0 / 60.0

    @Published private(set) var scene = GroceryTomatoSceneState()

    let force: TrackpadForce
    private var tracker = TomatoSquishTracker()
    private var displayedReading = 1.0
    private var startedAt = Date()
    private var lastTick = Date()
    private var completedAt: Date?
    private var timer: Timer?

    init(force: TrackpadForce) {
        self.force = force
    }

    func start() {
        guard timer == nil else { return }
        force.release()
        startedAt = Date()
        lastTick = startedAt
        timer = Timer.scheduledTimer(withTimeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        force.release()
    }

    /// Broken-state reset: new tomato, clear pressure.
    func pickAnother() {
        force.release()
        tracker.reset()
        displayedReading = 1.0
        completedAt = nil
        scene = GroceryTomatoSceneState(time: scene.time, depth: 0, phase: .squishing, completionElapsed: nil)
    }

    private func tick() {
        let now = Date()
        let dt = min(now.timeIntervalSince(lastTick), 0.1)
        lastTick = now

        var state = scene
        state.time = now.timeIntervalSince(startedAt)

        switch state.phase {
        case .broken:
            state.depth = 0
            scene = state
            return
        case .succeeded:
            if let completedAt {
                state.completionElapsed = now.timeIntervalSince(completedAt)
            }
            scene = state
            return
        case .squishing:
            break
        }

        let reading = force.pressureReading
        let tau = reading > displayedReading ? Self.pressSmoothing : Self.releaseSmoothing
        displayedReading += (reading - displayedReading) * (1 - exp(-dt / tau))
        state.depth = GroceryTomato.depth(forReading: displayedReading)

        // Ignore force until the scaffold intro has settled a bit.
        guard state.time >= LessonIntro.duration * 0.5 else {
            scene = state
            return
        }

        if GroceryTomato.isBroken(reading: reading) {
            force.release()
            state.phase = .broken
            state.depth = 1
            scene = state
            return
        }

        tracker.update(reading: reading, dt: dt)
        if tracker.isComplete {
            completedAt = now
            state.phase = .succeeded
            state.completionElapsed = 0
        }
        scene = state
    }
}
