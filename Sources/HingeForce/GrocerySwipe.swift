import CoreGraphics
import Foundation

/// Pure helpers for the Grocery Day “Swipe to pay” trackpad drag.
enum GrocerySwipe {
    /// Native reader art aspect (reader-idle / slot-front / thank-you).
    static let readerPixelSize = CGSize(width: 734, height: 570)
    static var readerAspect: CGFloat { readerPixelSize.width / readerPixelSize.height }

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

    /// Progress from press origin → current point, projected onto the 30° axis (drag distance only).
    static func progressFromDrag(from origin: CGPoint, to current: CGPoint, pathLength: CGFloat) -> Double {
        guard pathLength > 1e-6 else { return 0 }
        let u = pathUnit()
        let dx = Double(current.x - origin.x)
        let dy = Double(current.y - origin.y)
        let along = dx * u.dx + dy * u.dy
        return min(max(along / Double(pathLength), 0), 1)
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
