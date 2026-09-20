import CoreGraphics
import Foundation

/// Pure helpers for the Grocery Day “Toss the tomato” hinge activity.
enum GroceryToss {
    /// Closing speed (deg/s) that drives a full-speed toss.
    static let referenceFoldDegPerSec = 45.0
    /// Progress units (0...1) per second at reference fold speed.
    static let maxProgressPerSecond = 0.95
    static let continueStart = 0.35

    static let title = "Toss the tomato in the cart"
    static let subtitle = "Fold your laptop screen down."

    /// Positive when the lid is folding closed (angle decreasing).
    static func foldSpeed(previous: Double, current: Double, dt: TimeInterval) -> Double {
        guard dt > 0 else { return 0 }
        return max(0, (previous - current) / dt)
    }

    /// How far the tomato advances this frame from fold speed.
    static func progressDelta(foldSpeed: Double, dt: TimeInterval) -> Double {
        let intensity = min(max(foldSpeed / referenceFoldDegPerSec, 0), 1.6)
        return intensity * maxProgressPerSecond * dt
    }

    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat {
        a + (b - a) * CGFloat(min(max(t, 0), 1))
    }
}
