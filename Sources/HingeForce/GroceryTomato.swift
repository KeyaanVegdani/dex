import Foundation

/// Rules for the Grocery Day tomato-squish step (pressure via Force Touch).
enum GroceryTomato {
    /// Pressure reading (1...10) that breaks the tomato.
    static let breakThreshold = 8.2
    /// Soft floor of the “good squish” band — must reach this without breaking.
    static let successMin = 5.2
    /// Soft ceiling of the good band (below break). Holding here completes the step.
    static let successMax = 7.4
    /// How long a good-band press must be held to succeed.
    static let successHold: TimeInterval = 0.45
    /// Drain rate when pressure leaves the good band (same idea as PressCut).
    static let drainRate = 2.5
    /// Continue button timing after a gentle success.
    static let continueStart = 0.3

    /// 0...1 press depth from a 1...10 reading.
    static func depth(forReading reading: Double) -> Double {
        min(max((reading - 1) / 9, 0), 1)
    }

    /// Dent overlay opacity from depth (full before break).
    static func dentOpacity(depth: Double) -> Double {
        let full = Self.depth(forReading: breakThreshold)
        return min(max(depth / max(full, 0.001), 0), 1)
    }

    /// Brightness adjustment for the whole tomato (−1...0); harder press → darker.
    static func darken(depth: Double) -> Double {
        -0.35 * min(max(depth, 0), 1)
    }

    static func isBroken(reading: Double) -> Bool {
        reading >= breakThreshold
    }

    static func isInSuccessBand(reading: Double) -> Bool {
        reading >= successMin && reading <= successMax
    }
}

/// Tracks a sustained gentle squish without breaking.
struct TomatoSquishTracker {
    private(set) var held: TimeInterval = 0
    private(set) var isComplete = false

    var progress: Double { min(held / GroceryTomato.successHold, 1) }

    mutating func update(reading: Double, dt: TimeInterval) {
        guard !isComplete else { return }
        if GroceryTomato.isBroken(reading: reading) {
            held = 0
            return
        }
        if GroceryTomato.isInSuccessBand(reading: reading) {
            held += dt
        } else {
            held = max(0, held - dt * GroceryTomato.drainRate)
        }
        if held >= GroceryTomato.successHold { isComplete = true }
    }

    mutating func reset() {
        held = 0
        isComplete = false
    }
}
