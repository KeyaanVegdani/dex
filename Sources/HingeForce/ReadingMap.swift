import Foundation

/// Maps raw sensor values onto the output scales the app reports.
enum ReadingMap {
    /// Hinge angle (degrees) -> `hinge_reading`. Below the first point the reading is 0,
    /// above the last it is 100, and it is linear in between.
    static let hingeCurve: [(angle: Double, reading: Double)] = [
        (40, 0),
        (100, 50),
        (130, 100),
    ]

    static func hinge(angle: Double) -> Double {
        guard let first = hingeCurve.first, let last = hingeCurve.last else { return 0 }
        if angle <= first.angle { return first.reading }
        if angle >= last.angle { return last.reading }

        for (lo, hi) in zip(hingeCurve, hingeCurve.dropFirst()) where angle <= hi.angle {
            let t = (angle - lo.angle) / (hi.angle - lo.angle)
            return lo.reading + t * (hi.reading - lo.reading)
        }
        return last.reading
    }

    /// Maps a 0...1 fraction onto the shared 1...10 output scale, clamping outside 0...1.
    static func oneToTen(_ fraction: Double) -> Double {
        1 + 9 * min(max(fraction, 0), 1)
    }

    /// `NSEvent.pressure` (0...1) -> `pressure_reading` (1...10).
    static func pressure(_ pressure: Float) -> Double {
        oneToTen(Double(pressure))
    }
}
