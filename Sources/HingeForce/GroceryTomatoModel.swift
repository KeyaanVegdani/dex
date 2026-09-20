import Foundation

struct GroceryTomatoSceneState: Equatable {
    var time = 0.0
    /// Smoothed press depth 0...1 (drives dent only).
    var depth = 0.0
    var phase = GroceryTomatoPhase.squishing
    /// Seconds since a good squish (nil until then).
    var completionElapsed: Double?
    /// Dent position in the tomato frame, normalized 0...1 top-left origin; nil when not pressing.
    var dentNorm: CGPoint?
}

/// Runs the tomato-squish lesson: too soft / good / too hard from Force Touch.
@MainActor
final class GroceryTomatoModel: ObservableObject {
    static let pressSmoothing: TimeInterval = 0.04
    static let releaseSmoothing: TimeInterval = 0.12
    private static let frameInterval: TimeInterval = 1.0 / 60.0

    @Published private(set) var scene = GroceryTomatoSceneState()

    let force: TrackpadForce
    private var displayedReading = 1.0
    private var peakReading = 1.0
    private var wasPressed = false
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

    func getAnother() {
        force.release()
        displayedReading = 1.0
        peakReading = 1.0
        wasPressed = false
        completedAt = nil
        scene = GroceryTomatoSceneState(time: scene.time, depth: 0, phase: .squishing,
                                        completionElapsed: nil, dentNorm: nil)
    }

    private func tick() {
        let now = Date()
        let dt = min(now.timeIntervalSince(lastTick), 0.1)
        lastTick = now

        var state = scene
        state.time = now.timeIntervalSince(startedAt)

        switch state.phase {
        case .tooSoft, .tooHard:
            state.dentNorm = nil
            scene = state
            return
        case .good:
            if let completedAt {
                state.completionElapsed = now.timeIntervalSince(completedAt)
            }
            state.dentNorm = force.locationNorm ?? state.dentNorm
            scene = state
            return
        case .squishing:
            break
        }

        let reading = force.pressureReading
        let pressed = force.isPressed
        let tau = reading > displayedReading ? Self.pressSmoothing : Self.releaseSmoothing
        displayedReading += (reading - displayedReading) * (1 - exp(-dt / tau))
        state.depth = GroceryTomato.depth(forReading: displayedReading)
        state.dentNorm = pressed ? force.locationNorm : nil

        guard state.time >= LessonIntro.duration * 0.5 else {
            scene = state
            return
        }

        if pressed {
            peakReading = max(peakReading, reading)
            wasPressed = true

            if GroceryTomato.isTooHard(reading: reading) {
                force.release()
                state.phase = .tooHard
                state.depth = GroceryTomato.depth(forReading: GroceryTomato.hardMax)
                state.dentNorm = nil
                scene = state
                return
            }
        } else if wasPressed {
            wasPressed = false
            if peakReading < GroceryTomato.firmMin {
                state.phase = .tooSoft
                state.depth = 0
                state.dentNorm = nil
            } else if peakReading < GroceryTomato.hardMax {
                completedAt = now
                state.phase = .good
                state.completionElapsed = 0
                state.depth = GroceryTomato.depth(forReading: peakReading)
            }
            peakReading = 1.0
            displayedReading = 1.0
        }

        scene = state
    }
}
