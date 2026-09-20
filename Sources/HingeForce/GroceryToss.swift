import CoreGraphics
import Foundation

/// Pure helpers for the Grocery Day “Toss the tomato” hinge activity.
enum GroceryToss {
    /// Lid must be at or below this angle (degrees) to start the toss.
    static let launchAngleMax = 45.0
    /// Closing speed (deg/s) used as the reference impulse scale.
    static let referenceFoldDegPerSec = 45.0
    /// Degrees of closing (while gated) needed to launch.
    static let launchImpulseDegrees = 6.0
    /// Progress units (0...1) per second once airborne at reference impulse.
    static let referenceCoastPerSec = 0.95
    static let minCoastPerSec = 0.55
    static let maxCoastPerSec = 1.4
    static let continueStart = 0.35

    static let title = "Toss the tomato in the cart"
    static let subtitle = "Fold your laptop screen down."

    /// Positive when the lid is folding closed (angle decreasing).
    static func foldSpeed(previous: Double, current: Double, dt: TimeInterval) -> Double {
        guard dt > 0 else { return 0 }
        return max(0, (previous - current) / dt)
    }

    static func canLaunch(angle: Double) -> Bool {
        angle <= launchAngleMax
    }

    /// Closing degrees this frame (foldSpeed × dt), only while gated.
    static func impulseDelta(foldSpeed: Double, angle: Double, dt: TimeInterval) -> Double {
        guard canLaunch(angle: angle), foldSpeed > 0, dt > 0 else { return 0 }
        return foldSpeed * dt
    }

    /// Maps accumulated closing impulse → coast speed along the 0...1 path.
    static func coastSpeed(fromImpulse impulse: Double) -> Double {
        let reference = launchImpulseDegrees * 1.4
        let intensity = min(max(impulse / max(reference, 1e-6), 0.45), 1.65)
        return min(max(intensity * referenceCoastPerSec, minCoastPerSec), maxCoastPerSec)
    }

    /// Once airborne: fold no longer drives 1:1 — momentum eases and picks up along the arc.
    static func coastProgressDelta(coastSpeed: Double, progress: Double, dt: TimeInterval) -> Double {
        guard dt > 0, coastSpeed > 0 else { return 0 }
        let t = min(max(progress, 0), 1)
        // Ease-in then surge: slow leave-hand, accelerate over the apex, settle into the cart.
        let momentum = 0.55 + 0.75 * sin(Double.pi * t)
        return coastSpeed * momentum * dt
    }

    /// Start right of center → arc up → land in basket center.
    static func tomatoPosition(progress t: Double, cartCenter: CGPoint, cartSide: CGFloat) -> CGPoint {
        let u = min(max(t, 0), 1)
        let start = CGPoint(
            x: cartCenter.x + cartSide * 0.24,
            y: cartCenter.y - cartSide * 0.36
        )
        let end = CGPoint(
            x: cartCenter.x,
            y: cartCenter.y + cartSide * 0.04
        )
        let lift = cartSide * 0.30
        let x = lerp(start.x, end.x, u)
        let chordY = lerp(start.y, end.y, u)
        // 4u(1−u) peaks at mid-flight — classic toss parabola above the chord.
        let y = chordY - lift * 4 * u * (1 - u)
        return CGPoint(x: x, y: y)
    }

    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat {
        a + (b - a) * CGFloat(min(max(t, 0), 1))
    }
}
