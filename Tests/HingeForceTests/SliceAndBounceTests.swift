import XCTest
import SwiftUI
@testable import HingeForce

final class SliceHighlightTests: XCTestCase {
    private let center = Illustration.cutCakeCenter
    private let radii = Illustration.cutCakeRadii

    /// A point `distance` cake units from the centre, `degrees` clockwise from straight up.
    private func point(_ degrees: Double, _ distance: Double = 60) -> CGPoint {
        let r = degrees * .pi / 180
        return CGPoint(x: center.x + sin(r) * distance, y: center.y - cos(r) * distance)
    }

    func testHighlightRunsFromTheStartLineClockwiseToTheKnife() {
        let wedge = SliceHighlight.path(toAngle: 60)
        XCTAssertTrue(wedge.contains(point(1)), "just clockwise of the start line is inside")
        XCTAssertTrue(wedge.contains(point(30)))
        XCTAssertTrue(wedge.contains(point(59)), "up to the knife is inside")
        XCTAssertFalse(wedge.contains(point(62)), "past the knife is not")
        XCTAssertFalse(wedge.contains(point(-1)), "the other side of the start line is not")
        XCTAssertFalse(wedge.contains(point(-30)))
        XCTAssertFalse(wedge.contains(point(180)))
    }

    func testHighlightGrowsAsTheKnifeMovesOn() {
        var previous = 0.0
        for angle in stride(from: 15.0, through: 105.0, by: 10) {
            let box = SliceHighlight.path(toAngle: angle).boundingRect
            let area = Double(box.width * box.height)
            XCTAssertGreaterThan(area, previous, "angle \(angle)")
            previous = area
        }
    }

    func testHighlightStaysOnTheTopFaceAndNeverSpillsPastTheRim() {
        for angle in stride(from: 15.0, through: 180.0, by: 15) {
            let box = SliceHighlight.path(toAngle: angle).boundingRect
            XCTAssertGreaterThanOrEqual(box.minX, center.x - 0.5, "angle \(angle)")
            XCTAssertLessThanOrEqual(box.maxX, center.x + radii.width + 0.5, "angle \(angle)")
            XCTAssertGreaterThanOrEqual(box.minY, center.y - radii.height - 0.5, "angle \(angle)")
            XCTAssertLessThanOrEqual(box.maxY, center.y + radii.height + 0.5, "angle \(angle)")
        }
    }

    func testAHalfCakeSliceFillsTheWholeRightHalfOfTheTopFace() {
        let wedge = SliceHighlight.path(toAngle: 180)
        XCTAssertTrue(wedge.contains(point(90, 100)))
        XCTAssertTrue(wedge.contains(point(45, 80)))
        XCTAssertTrue(wedge.contains(point(135, 70)))
        XCTAssertFalse(wedge.contains(point(270, 100)))
    }

    func testHighlightIsClippedToTheEllipseRatherThanRunningToTheEdgeOfTheImage() {
        // Straight out to the right, 10 units beyond the rim, is well outside the top face.
        let wedge = SliceHighlight.path(toAngle: 100)
        XCTAssertFalse(wedge.contains(point(90, radii.width + 10)))
        XCTAssertTrue(wedge.contains(point(90, radii.width - 10)))
    }

    func testShapeScalesToTheRectItIsDrawnIn() {
        let scaled = SliceHighlight(toAngle: 60).path(in: CGRect(x: 0, y: 0, width: 674, height: 736))   // 2x the artwork
        let plain = SliceHighlight.path(toAngle: 60).boundingRect
        XCTAssertEqual(scaled.boundingRect.width, plain.width * 2, accuracy: 1)
        XCTAssertEqual(scaled.boundingRect.height, plain.height * 2, accuracy: 1)
    }
}

final class KnifeBounceTests: XCTestCase {
    func testBounceStaysWithinASlightHeightAndNeverGoesTowardsTheCake() {
        for t in stride(from: 0.0, through: 6.0, by: 0.01) {
            let offset = KnifeBounce.offset(at: t)
            XCTAssertGreaterThanOrEqual(offset, 0)
            XCTAssertLessThanOrEqual(offset, KnifeBounce.height + 1e-9)
        }
        XCTAssertLessThanOrEqual(KnifeBounce.height, 6, "slight")
    }

    func testBounceActuallyMovesAndReachesItsHeight() {
        let offsets = stride(from: 0.0, through: 2.0, by: 0.005).map { KnifeBounce.offset(at: $0) }
        XCTAssertEqual(offsets.max()!, KnifeBounce.height, accuracy: 0.05)
        XCTAssertEqual(offsets.min()!, 0, accuracy: 0.05)
    }

    func testEachBounceHitsTheRestingPositionLikeABall() {
        // One bounce lasts 1/rate seconds and starts and ends at rest.
        let period = 1 / KnifeBounce.rate
        XCTAssertEqual(KnifeBounce.offset(at: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(KnifeBounce.offset(at: period), 0, accuracy: 1e-9)
        XCTAssertEqual(KnifeBounce.offset(at: 3 * period), 0, accuracy: 1e-9)
        XCTAssertEqual(KnifeBounce.offset(at: period / 2), KnifeBounce.height, accuracy: 1e-9)
    }

    func testBounceIsGentleNotFrantic() {
        XCTAssertLessThanOrEqual(KnifeBounce.rate, 2)
    }

    func testBounceSettlesOnceTheCutIsComplete() {
        let t = 0.3   // mid-bounce
        XCTAssertGreaterThan(KnifeBounce.offset(at: t), 1)
        XCTAssertEqual(KnifeBounce.offset(at: t, completionElapsed: 0), KnifeBounce.offset(at: t), accuracy: 1e-9)
        XCTAssertEqual(KnifeBounce.offset(at: t, completionElapsed: KnifeBounce.settleDuration), 0, accuracy: 1e-9)
        XCTAssertEqual(KnifeBounce.offset(at: 7.3, completionElapsed: 5), 0, accuracy: 1e-9)
    }
}
