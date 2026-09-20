import Foundation
import CoreGraphics

struct GrocerySwipeSceneState: Equatable {
    var time = 0.0
    /// 0...1 along the slot path (drives arrow opacity + success check).
    var progress = 0.0
    /// Card center in scene coordinates. While pressed this is the raw mouse x/y;
    /// when nil, the view uses the rest pose at the top of the slot.
    var cardPoint: CGPoint?
    var isPressed = false
    var isComplete = false
    /// Seconds since a successful swipe, or nil while still swiping.
    var completionElapsed: Double?
}

/// Drives swipe-to-pay from trackpad/mouse press + drag. Card follows cursor x/y while pressed.
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
            state.cardPoint = nil
            state.completionElapsed = now.timeIntervalSince(completedAt)
            scene = state
            return
        }

        let size = contentSize
        let ready = size.width > 1 && size.height > 1
        let readerSize = GrocerySwipe.readerSize(for: size)
        let readerCenter = GrocerySwipe.readerCenter(for: size)
        let rest = GrocerySwipe.pathStart(readerCenter: readerCenter, readerSize: readerSize)

        // Wait for intro before counting drags.
        if state.time < LessonIntro.duration * 0.45 {
            state.progress = 0
            state.isPressed = false
            state.cardPoint = nil
            scene = state
            return
        }

        if snappingBack {
            state.isPressed = false
            let current = state.cardPoint ?? GrocerySwipe.cardCenter(progress: state.progress,
                                                                     readerCenter: readerCenter,
                                                                     readerSize: readerSize)
            let nextProgress = max(0, state.progress - Self.snapBackPerSecond * dt)
            let target = GrocerySwipe.cardCenter(progress: nextProgress,
                                                 readerCenter: readerCenter,
                                                 readerSize: readerSize)
            // Ease the free-follow point back toward the slot rest pose.
            let blend = min(1, Self.snapBackPerSecond * dt)
            state.cardPoint = CGPoint(
                x: current.x + (target.x - current.x) * blend,
                y: current.y + (target.y - current.y) * blend
            )
            state.progress = nextProgress
            if nextProgress <= 0.001 {
                state.progress = 0
                state.cardPoint = nil
                snappingBack = false
            }
            scene = state
            return
        }

        if ready, force.isPressed, let loc = force.locationNorm {
            // True follow: card center = mouse x/y in scene space.
            let point = CGPoint(x: loc.x * size.width, y: loc.y * size.height)
            state.cardPoint = point
            state.progress = GrocerySwipe.progress(for: point, readerCenter: readerCenter, readerSize: readerSize)
            state.isPressed = true
            wasPressed = true
        } else if wasPressed {
            wasPressed = false
            state.isPressed = false
            if state.progress >= GrocerySwipe.successThreshold {
                completedAt = now
                state.progress = 1
                state.isComplete = true
                state.cardPoint = nil
                state.completionElapsed = 0
            } else {
                snappingBack = true
            }
        } else {
            state.isPressed = false
            if state.cardPoint == nil {
                // Rest pose implied by nil; keep progress at 0.
                _ = rest
            }
        }

        scene = state
    }
}
