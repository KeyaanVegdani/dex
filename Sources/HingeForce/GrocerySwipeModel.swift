import AVFoundation
import Foundation

struct GrocerySwipeSceneState: Equatable {
    var time = 0.0
    /// True once tilt has armed playback (video may still be playing).
    var hasStartedPlayback = false
    var isComplete = false
    /// Seconds since the video finished, or nil while still waiting / playing.
    var completionElapsed: Double?
}

/// Drives swipe-to-pay: tilt MacBook down → play bundled swipe video → Finish → History.
@MainActor
final class GrocerySwipeModel: ObservableObject {
    private static let frameInterval: TimeInterval = 1.0 / 60.0

    @Published private(set) var scene = GrocerySwipeSceneState()
    /// Shared player: paused on first frame until tilt starts playback.
    @Published private(set) var player: AVPlayer?

    let accelerometer: Accelerometer
    private var baselinePitch: Double?
    private var startedAt = Date()
    private var lastTick = Date()
    private var completedAt: Date?
    private var timer: Timer?
    private var endObserver: NSObjectProtocol?

    init(accelerometer: Accelerometer) {
        self.accelerometer = accelerometer
    }

    func start() {
        accelerometer.start()
        preparePlayer()
        guard timer == nil else { return }
        startedAt = Date()
        lastTick = startedAt
        baselinePitch = nil
        completedAt = nil
        scene = GrocerySwipeSceneState()
        timer = Timer.scheduledTimer(withTimeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
        accelerometer.stop()
    }

    private func preparePlayer() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        guard let url = AppResources.swipeVideoURL() else {
            player = nil
            return
        }
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.pause()
        newPlayer.seek(to: .zero)
        player = newPlayer

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.videoDidFinish() }
        }
    }

    private func videoDidFinish() {
        guard completedAt == nil else { return }
        let now = Date()
        completedAt = now
        var state = scene
        state.hasStartedPlayback = true
        state.isComplete = true
        state.completionElapsed = 0
        scene = state
    }

    private func tick() {
        let now = Date()
        lastTick = now

        var state = scene
        state.time = now.timeIntervalSince(startedAt)

        if let completedAt {
            state.isComplete = true
            state.hasStartedPlayback = true
            state.completionElapsed = now.timeIntervalSince(completedAt)
            scene = state
            return
        }

        // Wait for intro before counting tilt; capture a resting baseline.
        if state.time < LessonIntro.duration * 0.45 {
            if let pitch = accelerometer.pitchDegrees, baselinePitch == nil {
                baselinePitch = pitch
            }
            scene = state
            return
        }

        guard let pitch = accelerometer.pitchDegrees else {
            scene = state
            return
        }

        if baselinePitch == nil {
            baselinePitch = pitch
        }

        let tip = GrocerySwipe.tipAmount(pitchDegrees: pitch, baselinePitch: baselinePitch ?? pitch)
        if !state.hasStartedPlayback, GrocerySwipe.shouldStartPlayback(tipDegrees: tip) {
            state.hasStartedPlayback = true
            player?.play()
        }

        scene = state
    }
}
