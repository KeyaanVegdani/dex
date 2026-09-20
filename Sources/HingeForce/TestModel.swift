import Foundation

/// Everything the Test System pages draw, smoothed for display.
struct TestState: Equatable {
    /// Seconds since the section opened; drives the "Hang tight" bounce.
    var time = 0.0
    /// The hinge angle being shown, which begins at the 50% default.
    var hinge = TestMotion.defaultHinge
    /// 0...1 loudness of the microphone.
    var micLevel = 0.0
    /// 0...1 how deep the trackpad press is.
    var pressDepth = 0.0
    /// The laptop's sideways roll in degrees.
    var roll = 0.0
}

/// Reads the sensors the Test System pages use and smooths them. Runs its own 60 fps clock. It only reads: which
/// sensors are switched on is up to the page that needs them.
@MainActor
final class TestModel: ObservableObject {
    private static let frameInterval: TimeInterval = 1.0 / 60.0

    @Published private(set) var state = TestState()

    private let lid: LidAngleSensor
    private let mic: MicMonitor
    private let force: TrackpadForce
    private let accelerometer: Accelerometer

    private var current = TestState()
    private var startedAt = Date()
    private var lastTick = Date()
    private var timer: Timer?

    init(lid: LidAngleSensor, mic: MicMonitor, force: TrackpadForce, accelerometer: Accelerometer) {
        self.lid = lid
        self.mic = mic
        self.force = force
        self.accelerometer = accelerometer
    }

    func start() {
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

        // Each value eases towards its target; louder and firmer are followed quickly, easing off more slowly.
        func ease(_ value: Double, to target: Double, rise: Double, fall: Double) -> Double {
            let tau = target > value ? rise : fall
            return value + (target - value) * (1 - exp(-dt / tau))
        }

        current.time = now.timeIntervalSince(startedAt)
        current.hinge = ease(current.hinge, to: lid.angle ?? TestMotion.defaultHinge, rise: 0.1, fall: 0.1)
        current.micLevel = ease(current.micLevel, to: TestMotion.micLevel(reading: mic.blowReading), rise: 0.05, fall: 0.18)
        current.pressDepth = ease(current.pressDepth, to: PressCut.depth(forReading: force.pressureReading), rise: 0.04, fall: 0.12)
        current.roll = ease(current.roll, to: accelerometer.rollDegrees ?? 0, rise: 0.08, fall: 0.08)
        state = current
    }
}
