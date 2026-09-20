import Foundation

/// Decides when a sustained, hard blow has put the candles out.
///
/// The blow reading has to stay at or above `threshold` for `holdDuration` seconds. A dip
/// below the threshold doesn't reset the count outright; it drains at `drainRate` times the
/// speed it filled, so a momentary wobble in a long blow is forgiven but stopping is not.
struct BlowOutTracker {
    /// Reading counted as "at 10". The reading is smoothed, so it only approaches 10 asymptotically.
    static let threshold = 8.5
    static let holdDuration: TimeInterval = 0.8
    static let drainRate = 2.0

    private(set) var held: TimeInterval = 0
    private(set) var isBlownOut = false

    /// 0...1 progress toward blowing the candles out.
    var progress: Double { min(held / Self.holdDuration, 1) }

    mutating func update(reading: Double, dt: TimeInterval) {
        guard !isBlownOut else { return }

        if reading >= Self.threshold {
            held += dt
        } else {
            held = max(0, held - dt * Self.drainRate)
        }
        if held >= Self.holdDuration { isBlownOut = true }
    }

    mutating func reset() {
        held = 0
        isBlownOut = false
    }
}
