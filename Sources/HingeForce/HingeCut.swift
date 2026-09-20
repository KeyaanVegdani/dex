import Foundation

/// The rules of the cutting lesson: how a hinge angle maps onto the cake, where the cut line goes,
/// and when the knife counts as being on it. All angles are in degrees.
enum HingeCut {
    /// The stretch of hinge travel the lesson uses (the same span as `hinge_reading`).
    static let hingeRange: ClosedRange<Double> = 40...130
    /// A new cut line is always at least this many degrees of hinge away from where the lid is now.
    static let minTargetDistance = 10.0
    /// How close (in hinge degrees) the lid must be to the line to count as on it.
    static let tolerance = 4.0
    /// How long the lid has to stay on the line for the line to turn fully white.
    static let holdDuration: TimeInterval = 1.5
    /// The knife's turn on screen for a hinge angle is `hinge - screenOffset`: 1 degree of hinge is 1 degree of knife.
    static let screenOffset = 25.0
    /// How far inside the cake's rim the cut line stops, in cake units.
    static let rimInset = 7.0

    /// Where the knife points for a hinge angle, in degrees clockwise from 12 o'clock.
    /// Hinge angles outside `hingeRange` are held at its ends so the knife stays on screen.
    static func screenAngle(forHinge hinge: Double) -> Double {
        min(max(hinge, hingeRange.lowerBound), hingeRange.upperBound) - screenOffset
    }

    /// A random hinge angle inside `hingeRange` that is at least `minTargetDistance` from `current`.
    static func randomTarget<G: RandomNumberGenerator>(current: Double, using generator: inout G) -> Double {
        let lo = hingeRange.lowerBound, hi = hingeRange.upperBound
        let below = lo...max(lo, min(hi, current - minTargetDistance))
        let above = min(hi, max(lo, current + minTargetDistance))...hi

        // Only intervals that genuinely respect the minimum distance are candidates.
        let candidates = [below, above].filter { $0.upperBound - $0.lowerBound > 0 &&
            (current - $0.upperBound >= minTargetDistance || $0.lowerBound - current >= minTargetDistance) }
        guard !candidates.isEmpty else {
            return abs(current - lo) > abs(current - hi) ? lo : hi
        }

        let total = candidates.reduce(0) { $0 + ($1.upperBound - $1.lowerBound) }
        var pick = Double.random(in: 0..<total, using: &generator)
        for range in candidates {
            let length = range.upperBound - range.lowerBound
            if pick < length { return range.lowerBound + pick }
            pick -= length
        }
        return candidates[candidates.count - 1].upperBound
    }

    static func randomTarget(current: Double) -> Double {
        var generator = SystemRandomNumberGenerator()
        return randomTarget(current: current, using: &generator)
    }

    static func isOnLine(hinge: Double, target: Double) -> Bool {
        abs(hinge - target) <= tolerance
    }

    /// Distance from the centre of an ellipse (half-sizes `rx`, `ry`) to its edge along a direction
    /// given in degrees clockwise from straight up.
    static func rimRadius(atAngle degrees: Double, rx: Double, ry: Double) -> Double {
        let radians = degrees * .pi / 180
        let dx = sin(radians) / rx
        let dy = cos(radians) / ry
        return 1 / (dx * dx + dy * dy).squareRoot()
    }
}

/// Tracks how long the lid has been on the cut line. Time on the line fills it, time off drains it,
/// so the line turns white gradually and fades back if the lid drifts away.
struct AlignmentTracker {
    private(set) var held: TimeInterval = 0
    private(set) var isComplete = false

    /// 0...1: how white the line is.
    var progress: Double { min(held / HingeCut.holdDuration, 1) }

    mutating func update(onLine: Bool, dt: TimeInterval) {
        guard !isComplete else { return }
        held = onLine ? held + dt : max(0, held - dt)
        if held >= HingeCut.holdDuration { isComplete = true }
    }
}
