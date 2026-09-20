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

    func testProgressProjectsOntoPath() {
        let size = CGSize(width: 1000, height: 800)
        let reader = GrocerySwipe.readerSize(for: size)
        let center = GrocerySwipe.readerCenter(for: size)
        let start = GrocerySwipe.pathStart(readerCenter: center, readerSize: reader)
        XCTAssertEqual(GrocerySwipe.progress(for: start, readerCenter: center, readerSize: reader),
                       0, accuracy: 1e-6)

        let end = GrocerySwipe.cardCenter(progress: 1, readerCenter: center, readerSize: reader)
        XCTAssertEqual(GrocerySwipe.progress(for: end, readerCenter: center, readerSize: reader),
                       1, accuracy: 1e-6)

        let mid = GrocerySwipe.cardCenter(progress: 0.5, readerCenter: center, readerSize: reader)
        XCTAssertEqual(GrocerySwipe.progress(for: mid, readerCenter: center, readerSize: reader),
                       0.5, accuracy: 1e-6)
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
