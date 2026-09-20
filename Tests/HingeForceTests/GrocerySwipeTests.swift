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

    func testProgressFromDragProjectsOntoAxis() {
        let u = GrocerySwipe.pathUnit()
        let origin = CGPoint(x: 100, y: 100)
        let pathLen: CGFloat = 200

        // Full travel along the path → progress 1.
        let along = CGPoint(x: origin.x + u.dx * pathLen, y: origin.y + u.dy * pathLen)
        XCTAssertEqual(GrocerySwipe.progressFromDrag(from: origin, to: along, pathLength: pathLen),
                       1, accuracy: 1e-6)

        // Perpendicular motion should not advance progress.
        let perp = CGPoint(x: origin.x + u.dy * 80, y: origin.y - u.dx * 80)
        XCTAssertEqual(GrocerySwipe.progressFromDrag(from: origin, to: perp, pathLength: pathLen),
                       0, accuracy: 1e-6)

        // Half travel → ~0.5
        let half = CGPoint(x: origin.x + u.dx * pathLen * 0.5, y: origin.y + u.dy * pathLen * 0.5)
        XCTAssertEqual(GrocerySwipe.progressFromDrag(from: origin, to: half, pathLength: pathLen),
                       0.5, accuracy: 1e-6)

        // Dragging the wrong way (up the slot) clamps at 0.
        let back = CGPoint(x: origin.x - u.dx * 40, y: origin.y - u.dy * 40)
        XCTAssertEqual(GrocerySwipe.progressFromDrag(from: origin, to: back, pathLength: pathLen),
                       0, accuracy: 1e-6)
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
        XCTAssertTrue(GrocerySwipe.subtitle.lowercased().contains("drag"))
        XCTAssertGreaterThan(GrocerySwipe.successThreshold, 0.8)
        XCTAssertLessThanOrEqual(GrocerySwipe.successThreshold, 1.0)
    }
}
