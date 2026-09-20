import XCTest
@testable import HingeForce

final class GrocerySwipeTests: XCTestCase {
    func testPathIsThirtyDegreesDownAndLeft() {
        let u = GrocerySwipe.pathUnit()
        XCTAssertEqual(GrocerySwipe.pathDegreesFromVertical, 30, accuracy: 1e-9)
        XCTAssertLessThan(u.dx, 0)
        XCTAssertGreaterThan(u.dy, 0)
        XCTAssertEqual(hypot(u.dx, u.dy), 1, accuracy: 1e-9)
    }

    func testReaderSizePreservesAspect() {
        let size = GrocerySwipe.readerSize(for: CGSize(width: 1200, height: 800))
        XCTAssertEqual(size.width / size.height, GrocerySwipe.readerAspect, accuracy: 1e-6)
    }

    func testCardStaysOnPathForAnyProgress() {
        let size = CGSize(width: 1000, height: 800)
        let reader = GrocerySwipe.readerSize(for: size)
        let center = GrocerySwipe.readerCenter(for: size)
        let start = GrocerySwipe.pathStart(readerCenter: center, readerSize: reader)
        let u = GrocerySwipe.pathUnit()
        let travel = GrocerySwipe.pathLength(readerSize: reader)

        let mid = GrocerySwipe.cardCenter(progress: 0.5, readerCenter: center, readerSize: reader)
        XCTAssertEqual(mid.x, start.x + travel * u.dx * 0.5, accuracy: 0.5)
        XCTAssertEqual(mid.y, start.y + travel * u.dy * 0.5, accuracy: 0.5)
    }

    func testTipAmountIsDistanceFromBaseline() {
        XCTAssertEqual(GrocerySwipe.tipAmount(pitchDegrees: 20, baselinePitch: 5), 15, accuracy: 1e-9)
        XCTAssertEqual(GrocerySwipe.tipAmount(pitchDegrees: -10, baselinePitch: 5), 15, accuracy: 1e-9)
    }

    func testProgressFromTipUsesDeadzoneAndCompletesAroundTwentyEight() {
        XCTAssertEqual(GrocerySwipe.progressFromTipAmount(0), 0, accuracy: 1e-9)
        XCTAssertEqual(GrocerySwipe.progressFromTipAmount(GrocerySwipe.tipDeadzoneDegrees), 0, accuracy: 1e-9)
        XCTAssertEqual(GrocerySwipe.progressFromTipAmount(GrocerySwipe.tipCompleteDegrees), 1, accuracy: 1e-9)
        let midTip = (GrocerySwipe.tipDeadzoneDegrees + GrocerySwipe.tipCompleteDegrees) / 2
        XCTAssertEqual(GrocerySwipe.progressFromTipAmount(midTip), 0.5, accuracy: 1e-6)
    }

    func testProgressIsMonotonicAndRateCanBoost() {
        let slow = GrocerySwipe.progress(tipDegrees: 16, tipRateDegPerSec: 0, previous: 0)
        let fast = GrocerySwipe.progress(tipDegrees: 16, tipRateDegPerSec: 60, previous: 0)
        XCTAssertGreaterThan(fast, slow)

        let held = GrocerySwipe.progress(tipDegrees: 10, tipRateDegPerSec: 0, previous: 0.7)
        XCTAssertEqual(held, 0.7, accuracy: 1e-9)
    }

    func testArrowEndpointsStayInsideReaderFrame() {
        let reader = CGSize(width: 400, height: 400 / GrocerySwipe.readerAspect)
        let (origin, tip) = GrocerySwipe.arrowEndpointsInReaderFrame(readerSize: reader)
        for p in [origin, tip] {
            XCTAssertGreaterThanOrEqual(p.x, 0)
            XCTAssertGreaterThanOrEqual(p.y, 0)
            XCTAssertLessThanOrEqual(p.x, reader.width)
            XCTAssertLessThanOrEqual(p.y, reader.height)
        }
    }

    func testArrowOpacityMapsWithProgress() {
        XCTAssertEqual(GrocerySwipe.arrowOpacity(progress: 0), 0.5, accuracy: 1e-9)
        XCTAssertEqual(GrocerySwipe.arrowOpacity(progress: 1), 1.0, accuracy: 1e-9)
        XCTAssertEqual(GrocerySwipe.arrowOpacity(progress: 0.5), 0.75, accuracy: 1e-9)
    }

    func testCopyAndSuccessThreshold() {
        XCTAssertEqual(GrocerySwipe.title, "Swipe to pay")
        XCTAssertTrue(GrocerySwipe.subtitle.lowercased().contains("tilt"))
        XCTAssertGreaterThan(GrocerySwipe.successThreshold, 0.8)
        XCTAssertLessThanOrEqual(GrocerySwipe.successThreshold, 1.0)
    }
}
