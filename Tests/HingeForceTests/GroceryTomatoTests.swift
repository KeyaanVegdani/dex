import XCTest
@testable import HingeForce

final class GroceryTomatoTests: XCTestCase {
    func testDepthAndDentGrowWithPressure() {
        XCTAssertEqual(GroceryTomato.depth(forReading: 1), 0, accuracy: 1e-9)
        XCTAssertEqual(GroceryTomato.depth(forReading: 10), 1, accuracy: 1e-9)
        XCTAssertGreaterThan(GroceryTomato.dentOpacity(depth: 0.8), GroceryTomato.dentOpacity(depth: 0.2))
        XCTAssertLessThan(GroceryTomato.darken(depth: 0.9), GroceryTomato.darken(depth: 0.1))
    }

    func testBreakThresholdIsAboveSuccessBand() {
        XCTAssertLessThan(GroceryTomato.successMax, GroceryTomato.breakThreshold)
        XCTAssertTrue(GroceryTomato.isBroken(reading: GroceryTomato.breakThreshold))
        XCTAssertFalse(GroceryTomato.isBroken(reading: GroceryTomato.successMax))
        XCTAssertTrue(GroceryTomato.isInSuccessBand(reading: 6.0))
        XCTAssertFalse(GroceryTomato.isInSuccessBand(reading: 9.0))
    }

    func testGentleHoldCompletesWithoutBreaking() {
        var tracker = TomatoSquishTracker()
        for _ in 0..<40 {
            tracker.update(reading: 6.0, dt: 0.02)
        }
        XCTAssertTrue(tracker.isComplete)

        var hard = TomatoSquishTracker()
        hard.update(reading: 9.0, dt: 0.1)
        XCTAssertFalse(hard.isComplete)
        XCTAssertEqual(hard.held, 0, accuracy: 1e-9)
    }
}
