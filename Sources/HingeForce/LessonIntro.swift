import Foundation

/// The lesson's entrance animation, as pure functions of the seconds since the page appeared.
///
/// Every part moves on the same spring curve and each starts while the one before it is still
/// moving, so there is never a beat where everything is standing still:
/// - The plate and cake body scale up together. The body starts floating above the plate and
///   tilted, and drops and rocks level in one continuous motion.
/// - The candles start partway through that scale-up, splayed outward above the cake, and
///   fall straight into it.
/// - The flames pop on as the candles are still settling.
/// The progress bar expands from its centre alongside, and the caption slides up and fades in.
enum LessonIntro {
    /// Time by which every part has settled.
    static let duration = 1.25

    struct Stick: Equatable {
        var lift: Double      // cake units above its resting place
        var angle: Double     // degrees, positive is clockwise
        var scale: Double
        var opacity: Double
    }

    struct Cake: Equatable {
        var groupScale: Double
        var groupOpacity: Double
        var bodyLift: Double  // cake units above its resting place
        var bodyTilt: Double  // degrees
        var sticks: [Stick]
        var flameScale: [Double]
    }

    // MARK: - Timeline

    static func cake(at t: Double) -> Cake {
        let grow = spring(t, start: 0, duration: 1.0)
        let drop = spring(t, start: 0, duration: 0.95)

        let hoverLift = [90.0, 105.0, 90.0]
        let hoverAngle = [-16.0, 0.0, 16.0]
        let sticks = (0..<3).map { i -> Stick in
            let start = 0.2 + 0.05 * Double(i)
            let fall = spring(t, start: start, duration: 0.8)
            return Stick(lift: hoverLift[i] * (1 - fall),
                         angle: hoverAngle[i] * (1 - fall),
                         scale: lerp(0.6, 1, fall),
                         opacity: progress(t, start, start + 0.15))
        }

        return Cake(
            groupScale: lerp(0.25, 1, grow),
            groupOpacity: progress(t, 0, 0.2),
            bodyLift: 220 * (1 - drop),
            bodyTilt: -14 * (1 - drop),
            sticks: sticks,
            flameScale: (0..<3).map { spring(t, start: 0.6 + 0.06 * Double($0), duration: 0.5, damping: 0.6) }
        )
    }

    /// 0...1 (with a slight overshoot): how far the progress bar has expanded outwards.
    static func barExpansion(at t: Double) -> Double {
        spring(t, start: 0, duration: 0.7, damping: 0.8)
    }

    /// 0...1: how far the caption has slid up and faded in.
    static func textReveal(at t: Double) -> Double {
        easeOutCubic(progress(t, 0.4, 0.85))
    }

    // MARK: - Easing

    static func progress(_ t: Double, _ start: Double, _ end: Double) -> Double {
        min(max((t - start) / (end - start), 0), 1)
    }

    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    static func easeOutCubic(_ x: Double) -> Double { 1 - pow(1 - x, 3) }

    static func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }

    /// A damped spring from 0 to 1 over `duration` seconds, starting from rest at `start`.
    /// It may overshoot 1 slightly before settling; `damping` below 1 is springy, and lower bounces more
    /// (0.8 overshoots by about 1.5%, 0.6 by about 10%).
    /// Returns exactly 0 before `start` and exactly 1 from `start + duration`.
    static func spring(_ t: Double, start: Double, duration: Double, damping: Double = 0.8) -> Double {
        let elapsed = t - start
        if elapsed <= 0 { return 0 }
        if elapsed >= duration { return 1 }

        // Decay rate chosen so the oscillation has faded to under 1% by `duration`.
        let omega = 5 / (damping * duration)
        let omegaD = omega * (1 - damping * damping).squareRoot()
        let k = damping * omega / omegaD

        func position(_ tau: Double) -> Double {
            1 - exp(-damping * omega * tau) * (cos(omegaD * tau) + k * sin(omegaD * tau))
        }
        // Blend out the small leftover so the curve lands exactly on 1 without a visible snap.
        let leftover = 1 - position(duration)
        let p = elapsed / duration
        return position(elapsed) + leftover * (p * p * (3 - 2 * p))
    }
}
