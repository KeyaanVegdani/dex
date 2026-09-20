import Foundation
import CoreGraphics

struct GrocerySwipeSceneState: Equatable {
    var time = 0.0
    /// 0...1 along the slot path.
    var progress = 0.0
    var isPressed = false
    var isComplete = false
    /// Seconds since a successful swipe, or nil while still swiping.
    var completionElapsed: Double?
}

/// Drives swipe-to-pay from trackpad/mouse press + drag along the slot path.
@MainActor
final class GrocerySwipeModel: ObservableObject {
    private static let frameInterval: TimeInterval = 1.0 / 60.0
    private static let snapBackPerSecond = 2.8

    @Published private(set) var scene = GrocerySwipeSceneState()

    let force: TrackpadForce
    private var contentSize: CGSize = .zero
    private var wasPressed = false
    private var snappingBack = false
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
        wasPressed = false
        snappingBack = false
        completedAt = nil
        contentSize = .zero
        scene = GrocerySwipeSceneState()
        timer = Timer.scheduledTimer(withTimeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        force.release()
    }

    func updateContentSize(_ size: CGSize) {
        contentSize = size
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
            state.isPressed = false
            state.completionElapsed = now.timeIntervalSince(completedAt)
            scene = state
            return
        }

        // Wait for intro before counting drags.
        if state.time < LessonIntro.duration * 0.45 {
            state.progress = 0
            state.isPressed = false
            scene = state
            return
        }

        let size = contentSize
        let ready = size.width > 1 && size.height > 1
        let readerSide = GrocerySwipe.readerSide(for: size)
        let readerCenter = GrocerySwipe.readerCenter(for: size)

        if snappingBack {
            state.progress = max(0, state.progress - Self.snapBackPerSecond * dt)
            state.isPressed = false
            if state.progress <= 0.001 {
                state.progress = 0
                snappingBack = false
            }
            scene = state
            return
        }

        if ready, force.isPressed, let loc = force.locationNorm {
            let point = CGPoint(x: loc.x * size.width, y: loc.y * size.height)
            state.progress = GrocerySwipe.progress(for: point, readerCenter: readerCenter, readerSide: readerSide)
            state.isPressed = true
            wasPressed = true
        } else if wasPressed {
            wasPressed = false
            state.isPressed = false
            if state.progress >= GrocerySwipe.successThreshold {
                completedAt = now
                state.progress = 1
                state.isComplete = true
                state.completionElapsed = 0
            } else {
                snappingBack = true
            }
        } else {
            state.isPressed = false
        }

        scene = state
    }
}
