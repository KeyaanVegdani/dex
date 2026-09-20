import XCTest
@testable import HingeForce

final class GroceryCartTests: XCTestCase {
    func testIntensityMapsBlowReadingOneToTen() {
        XCTAssertEqual(GroceryCart.intensity(reading: 1), 0, accuracy: 1e-9)
        XCTAssertEqual(GroceryCart.intensity(reading: 10), 1, accuracy: 1e-9)
        XCTAssertEqual(GroceryCart.intensity(reading: 5.5), 0.5, accuracy: 1e-9)
        XCTAssertEqual(GroceryCart.intensity(reading: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(GroceryCart.intensity(reading: 12), 1, accuracy: 1e-9)
    }

    func testHarderBlowAdvancesFartherPerTick() {
        let soft = GroceryCart.progressDelta(intensity: 0.2, dt: 0.1)
        let hard = GroceryCart.progressDelta(intensity: 0.9, dt: 0.1)
        XCTAssertGreaterThan(hard, soft)
        XCTAssertEqual(GroceryCart.progressDelta(intensity: 0, dt: 0.1), 0, accuracy: 1e-9)
    }

    func testTrailLengthGrowsWithIntensityWithoutShowingWhenIdle() {
        XCTAssertEqual(GroceryCart.trailLength(intensity: 0), 0, accuracy: 1e-9)
        XCTAssertGreaterThan(GroceryCart.trailLength(intensity: 0.5), GroceryCart.trailLength(intensity: 0.2))
        XCTAssertLessThanOrEqual(GroceryCart.trailLength(intensity: 1), 1)
    }
}
