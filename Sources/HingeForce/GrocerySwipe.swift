import CoreGraphics
import Foundation

/// Pure helpers for the Grocery Day “Swipe to pay” MacBook-tilt activity.
enum GrocerySwipe {
    /// Native reader art aspect (reader-idle / slot-front / thank-you).
    static let readerPixelSize = CGSize(width: 734, height: 570)
    static var readerAspect: CGFloat { readerPixelSize.width / readerPixelSize.height }

    /// Swipe path angle from vertical toward the left (degrees), matching the reader slot.
    static let pathDegreesFromVertical = 30.0
    /// Tip past the resting baseline ignored (avoids jitter).
    static let tipDeadzoneDegrees = 5.0
    /// Clear downward tip that maps to full swipe progress (~28° from rest — not absurd).
    static let tipCompleteDegrees = 28.0
    /// Tip rate (deg/s away from baseline) that adds a full rate boost.
    static let referenceTipRateDegPerSec = 45.0
    /// Extra progress fraction available from a fast tip (on top of angle).
    static let maxRateBoost = 0.22
    /// Fraction of path that counts as a successful swipe.
    static let successThreshold = 0.88
    static let continueStart = 0.28
    static let arrowOpacityRest = 0.5
    static let arrowOpacityFull = 1.0

    static let title = "Swipe to pay"
    static let subtitle = "Tilt your MacBook down."

    /// Unit direction along the slot: down and left.
    static func pathUnit() -> CGVector {
        let rad = pathDegreesFromVertical * .pi / 180
        return CGVector(dx: -sin(rad), dy: cos(rad))
    }

    /// Aspect-preserving reader size that fits the scene (same frame for all reader overlays).
    static func readerSize(for size: CGSize) -> CGSize {
        let maxW = min(size.width * 0.42, 420)
        let maxH = min(size.height * 0.50, 400)
        if maxW / readerAspect <= maxH {
            return CGSize(width: maxW, height: maxW / readerAspect)
        }
        return CGSize(width: maxH * readerAspect, height: maxH)
    }

    static func readerCenter(for size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height * 0.46)
    }

    /// Fixed start pose: at the top / right of the reader slot (swipe-start-ref).
    static func pathStart(readerCenter: CGPoint, readerSize: CGSize) -> CGPoint {
        CGPoint(
            x: readerCenter.x + readerSize.width * 0.34,
            y: readerCenter.y - readerSize.height * 0.16
        )
    }

    static func pathLength(readerSize: CGSize) -> CGFloat {
        readerSize.height * 0.58
    }

    /// Card center locked to the 30° path at progress `t`.
    static func cardCenter(progress t: Double, readerCenter: CGPoint, readerSize: CGSize) -> CGPoint {
        let u = pathUnit()
        let start = pathStart(readerCenter: readerCenter, readerSize: readerSize)
        let travel = pathLength(readerSize: readerSize)
        let p = min(max(t, 0), 1)
        return CGPoint(
            x: start.x + travel * u.dx * CGFloat(p),
            y: start.y + travel * u.dy * CGFloat(p)
        )
    }

    /// Degrees tipped away from the pose captured when the step started.
    static func tipAmount(pitchDegrees: Double, baselinePitch: Double) -> Double {
        abs(pitchDegrees - baselinePitch)
    }

    /// Progress 0...1 from tip angle alone (deadzone → complete).
    static func progressFromTipAmount(_ tipDegrees: Double) -> Double {
        let span = tipCompleteDegrees - tipDeadzoneDegrees
        guard span > 1e-6 else { return 0 }
        return min(max((tipDegrees - tipDeadzoneDegrees) / span, 0), 1)
    }

    /// Combines tip angle with tip rate so a clear downward tip finishes without absurd angles.
    /// `tipRateDegPerSec` is how fast tip amount is increasing (0 if leveling out).
    static func progress(tipDegrees: Double, tipRateDegPerSec: Double, previous: Double) -> Double {
        let fromAngle = progressFromTipAmount(tipDegrees)
        let rateBoost: Double
        if fromAngle > 0.02, tipRateDegPerSec > 0 {
            let intensity = min(max(tipRateDegPerSec / referenceTipRateDegPerSec, 0), 1.4)
            rateBoost = maxRateBoost * intensity
        } else {
            rateBoost = 0
        }
        let target = min(fromAngle + rateBoost, 1)
        // Monotonic: card only advances until complete (no jitter back while leveling).
        return min(max(max(previous, target), 0), 1)
    }

    static func arrowOpacity(progress: Double) -> Double {
        let t = min(max(progress, 0), 1)
        return arrowOpacityRest + (arrowOpacityFull - arrowOpacityRest) * t
    }

    /// Arrow endpoints in **local reader-frame** coordinates (top-left origin, size = readerSize).
    static func arrowEndpointsInReaderFrame(readerSize: CGSize) -> (CGPoint, CGPoint) {
        let u = pathUnit()
        let outward = CGVector(dx: u.dy, dy: -u.dx)
        let origin = CGPoint(
            x: readerSize.width * 0.78 + outward.dx * readerSize.width * 0.02,
            y: readerSize.height * 0.22 + outward.dy * readerSize.width * 0.02
        )
        let travel = readerSize.height * 0.48
        let tip = CGPoint(
            x: origin.x + u.dx * travel,
            y: origin.y + u.dy * travel
        )
        return (origin, tip)
    }
}
