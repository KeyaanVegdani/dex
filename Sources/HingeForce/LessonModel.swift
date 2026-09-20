import Foundation

/// Turns the live microphone reading into the candle scene's animation state, and decides
/// when the candles are blown out. Runs its own 60 fps clock.
@MainActor
final class LessonModel: ObservableObject {
    /// How quickly the drawn lean follows the mic reading, in seconds (mic updates arrive ~10x/s).
    static let smoothing: TimeInterval = 0.08
    private static let frameInterval: TimeInterval = 1.0 / 60.0

    @Published private(set) var scene = CandleSceneState()
    @Published private(set) var isComplete = false

    let mic: MicMonitor
    private var tracker = BlowOutTracker()
    private var displayedReading = 1.0
    private var startedAt = Date()
    private var lastTick = Date()
    private var blownOutAt: Date?
    private var bendAtBlowOut = 0.0
    private var timer: Timer?

    init(mic: MicMonitor) {
        self.mic = mic
    }

    private var tickCount = 0

    func start() {
        DebugLog.write("=== LessonModel.start() ===")
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
        SoundEffects.shared.stopAmbient(.candles)
    }

    private func tick() {
        let now = Date()
        let dt = min(now.timeIntervalSince(lastTick), 0.1)
        lastTick = now

        let reading = mic.blowReading
        displayedReading += (reading - displayedReading) * (1 - exp(-dt / Self.smoothing))

        var state = CandleSceneState()
        state.time = now.timeIntervalSince(startedAt)

        if let blownOutAt {
            state.bend = bendAtBlowOut
            state.blowOutElapsed = now.timeIntervalSince(blownOutAt)
        } else if state.time >= LessonIntro.duration {
            // The mic is ignored until the entrance animation has finished and the candles are lit.
            tracker.update(reading: reading, dt: dt)
            state.bend = (displayedReading - 1) / 9
            state.holdProgress = tracker.progress

            if tracker.isBlownOut {
                blownOutAt = now
                bendAtBlowOut = state.bend
                state.blowOutElapsed = 0
                isComplete = true
                SoundEffects.shared.play(.partFinished)
            }
        }
        scene = state

        // The candles crackle softly while they burn: quiet at first, coming up as the flames light, more turbulent as
        // they are blown, and gone when they go out.
        let flames = LessonIntro.cake(at: state.time).flameScale
        let lit = flames.reduce(0, +) / Double(flames.count)
        SoundEffects.shared.setAmbient(.candles,
                                       level: CandleSoundLevel.level(lit: lit, blowOutElapsed: state.blowOutElapsed),
                                       tone: state.bend)

        tickCount += 1
        if tickCount % 30 == 0 {
            DebugLog.write(String(format: "lesson t=%.2f micReading=%.2f bend=%.2f hold=%.2f status=%@ out=%d", state.time, reading, state.bend, state.holdProgress, "\(mic.status)", isComplete ? 1 : 0))
        }
    }
}
