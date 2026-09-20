import Foundation

/// Pure helpers for the Grocery Day “Push the cart” activity.
enum GroceryCart {
    /// Blow reading is 1...10; map to 0...1 push strength.
    static func intensity(reading: Double) -> Double {
        min(max((reading - 1) / 9, 0), 1)
    }

    /// How far the cart advances along the path per second at full blow (progress units 0...1).
    static let maxProgressPerSecond = 0.55

    /// Progress advance this frame from smoothed intensity.
    static func progressDelta(intensity: Double, dt: TimeInterval) -> Double {
        max(0, intensity) * maxProgressPerSecond * dt
    }

    /// Visible trail length as a fraction of the speed-lines art (0 = hidden, 1 = full).
    /// Keeps a little trail once moving so soft blows still read as motion.
    static func trailLength(intensity: Double) -> Double {
        guard intensity > 0.02 else { return 0 }
        return min(max(0.18 + intensity * 0.82, 0), 1)
    }

    /// Seconds of outro before Continue becomes available (same family as other lessons).
    static let continueStart = 0.35
}
