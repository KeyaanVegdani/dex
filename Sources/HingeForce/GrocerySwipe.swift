import CoreGraphics
import Foundation

/// Pure helpers for the Grocery Day “Swipe to pay” trackpad drag.
enum GrocerySwipe {
    /// Swipe path angle from vertical toward the left (degrees), matching the reader slot.
    static let pathDegreesFromVertical = 30.0
    /// Fraction of path that counts as a successful swipe on release.
    static let successThreshold = 0.88
    static let continueStart = 0.28
    static let arrowOpacityRest = 0.5
    static let arrowOpacityFull = 1.0

    static let title = "Swipe to pay"
    static let subtitle = "Click and drag on your mousepad."

    /// Unit direction along the slot: down and left.
    static func pathUnit() -> CGVector {
        let rad = pathDegreesFromVertical * .pi / 180
        return CGVector(dx: -sin(rad), dy: cos(rad))
    }

    static func readerSide(for size: CGSize) -> CGFloat {
        min(size.width * 0.38, size.height * 0.46, 380)
    }

    static func readerCenter(for size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height * 0.46)
    }

    /// Top of the slot — card start (storyboards 1–2).
    static func pathStart(readerCenter: CGPoint, readerSide: CGFloat) -> CGPoint {
        CGPoint(
            x: readerCenter.x + readerSide * 0.30,
            y: readerCenter.y - readerSide * 0.20
        )
    }

    static func pathLength(readerSide: CGFloat) -> CGFloat {
        readerSide * 0.58
    }

    static func cardCenter(progress t: Double, readerCenter: CGPoint, readerSide: CGFloat) -> CGPoint {
        let u = pathUnit()
        let start = pathStart(readerCenter: readerCenter, readerSide: readerSide)
        let travel = pathLength(readerSide: readerSide)
        let p = min(max(t, 0), 1)
        return CGPoint(
            x: start.x + travel * u.dx * CGFloat(p),
            y: start.y + travel * u.dy * CGFloat(p)
        )
    }

    /// Project a scene point onto the swipe path as 0...1 progress.
    static func progress(for point: CGPoint, readerCenter: CGPoint, readerSide: CGFloat) -> Double {
        let u = pathUnit()
        let start = pathStart(readerCenter: readerCenter, readerSide: readerSide)
        let travel = Double(pathLength(readerSide: readerSide))
        guard travel > 1e-6 else { return 0 }
        let vx = Double(point.x - start.x)
        let vy = Double(point.y - start.y)
        let along = vx * u.dx + vy * u.dy
        return min(max(along / travel, 0), 1)
    }

    static func arrowOpacity(progress: Double) -> Double {
        let t = min(max(progress, 0), 1)
        return arrowOpacityRest + (arrowOpacityFull - arrowOpacityRest) * t
    }

    /// Arrow sits just outside the slot, parallel to the path.
    static func arrowEndpoints(readerCenter: CGPoint, readerSide: CGFloat) -> (CGPoint, CGPoint) {
        let u = pathUnit()
        // Perpendicular pointing further right/out from the reader.
        let outward = CGVector(dx: u.dy, dy: -u.dx)
        let inset = readerSide * 0.06
        let start = pathStart(readerCenter: readerCenter, readerSide: readerSide)
        let travel = pathLength(readerSide: readerSide)
        let origin = CGPoint(
            x: start.x + outward.dx * readerSide * 0.14 + u.dx * inset,
            y: start.y + outward.dy * readerSide * 0.14 + u.dy * inset
        )
        let tip = CGPoint(
            x: origin.x + u.dx * (travel - inset * 2),
            y: origin.y + u.dy * (travel - inset * 2)
        )
        return (origin, tip)
    }
}
