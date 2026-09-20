import XCTest
@testable import HingeForce

final class GroceryTossTests: XCTestCase {
    func testFoldSpeedIsPositiveOnlyWhenClosing() {
        XCTAssertEqual(GroceryToss.foldSpeed(previous: 100, current: 80, dt: 0.2), 100, accuracy: 1e-9)
        XCTAssertEqual(GroceryToss.foldSpeed(previous: 80, current: 100, dt: 0.2), 0, accuracy: 1e-9)
        XCTAssertEqual(GroceryToss.foldSpeed(previous: 90, current: 90, dt: 0.1), 0, accuracy: 1e-9)
    }

    func testFasterFoldAdvancesTomatoFarther() {
        let slow = GroceryToss.progressDelta(foldSpeed: 10, dt: 0.1)
        let fast = GroceryToss.progressDelta(foldSpeed: 45, dt: 0.1)
        XCTAssertGreaterThan(fast, slow)
        XCTAssertEqual(GroceryToss.progressDelta(foldSpeed: 0, dt: 0.1), 0, accuracy: 1e-9)
    }
}
