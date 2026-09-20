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

    func testProgressProjectsOntoPath() {
        let size = CGSize(width: 1000, height: 800)
        let side = GrocerySwipe.readerSide(for: size)
        let center = GrocerySwipe.readerCenter(for: size)
        let start = GrocerySwipe.pathStart(readerCenter: center, readerSide: side)
        XCTAssertEqual(GrocerySwipe.progress(for: start, readerCenter: center, readerSide: side),
                       0, accuracy: 1e-6)

        let end = GrocerySwipe.cardCenter(progress: 1, readerCenter: center, readerSide: side)
        XCTAssertEqual(GrocerySwipe.progress(for: end, readerCenter: center, readerSide: side),
                       1, accuracy: 1e-6)

        let mid = GrocerySwipe.cardCenter(progress: 0.5, readerCenter: center, readerSide: side)
        XCTAssertEqual(GrocerySwipe.progress(for: mid, readerCenter: center, readerSide: side),
                       0.5, accuracy: 1e-6)
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
