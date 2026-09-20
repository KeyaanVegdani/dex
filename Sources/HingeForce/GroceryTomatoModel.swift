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
    /// True when success came from a second too-soft after the one allowed replacement.
    var isGoodEnough = false
}

/// Pure policy for soft-replacement limits (testable without the timer model).
enum GroceryTomatoRetry {
    /// First too-soft → offer Get another. After that replacement is used, further too-soft → good enough.
    static func softOutcome(alreadyReplacedOnce: Bool) -> GroceryTomatoPhase {
        alreadyReplacedOnce ? .good : .tooSoft
    }

    static func shouldOfferGetAnother(phase: GroceryTomatoPhase, alreadyReplacedOnce: Bool) -> Bool {
        switch phase {
        case .tooHard: return true
        case .tooSoft: return !alreadyReplacedOnce
        default: return false
        }
    }
}

/// Runs the tomato-squish lesson: too soft / good / too hard from Force Touch.
@MainActor
final class GroceryTomatoModel: ObservableObject {
    static let pressSmoothing: TimeInterval = 0.04
    static let releaseSmoothing: TimeInterval = 0.12
    private static let frameInterval: TimeInterval = 1.0 / 60.0

    @Published private(set) var scene = GroceryTomatoSceneState()
    /// Soft “Get another tomato” may be used once per visit to this step.
    @Published private(set) var usedSoftReplacement = false

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
        // Fresh entry to this step — one soft replacement again.
        usedSoftReplacement = false
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
        usedSoftReplacement = false
    }

    func getAnother() {
        if scene.phase == .tooSoft {
            usedSoftReplacement = true
        }
        force.release()
        displayedReading = 1.0
        peakReading = 1.0
        wasPressed = false
        completedAt = nil
        scene = GroceryTomatoSceneState(time: scene.time, depth: 0, phase: .squishing,
                                        completionElapsed: nil, dentNorm: nil, isGoodEnough: false)
    }

    var offersGetAnother: Bool {
        GroceryTomatoRetry.shouldOfferGetAnother(phase: scene.phase, alreadyReplacedOnce: usedSoftReplacement)
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
                state.isGoodEnough = false
                scene = state
                return
            }
        } else if wasPressed {
            wasPressed = false
            if peakReading < GroceryTomato.firmMin {
                let soft = GroceryTomatoRetry.softOutcome(alreadyReplacedOnce: usedSoftReplacement)
                if soft == .good {
                    // Already used the one soft replacement — accept and Continue.
                    completedAt = now
                    state.phase = .good
                    state.isGoodEnough = true
                    state.completionElapsed = 0
                    state.depth = 0
                    state.dentNorm = nil
                } else {
                    state.phase = .tooSoft
                    state.depth = 0
                    state.dentNorm = nil
                    state.isGoodEnough = false
                }
            } else if peakReading < GroceryTomato.hardMax {
                completedAt = now
                state.phase = .good
                state.isGoodEnough = false
                state.completionElapsed = 0
                state.depth = GroceryTomato.depth(forReading: peakReading)
            }
            peakReading = 1.0
            displayedReading = 1.0
        }

        scene = state
    }
}
