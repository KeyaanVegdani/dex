import XCTest
@testable import HingeForce

final class GroceryTossTests: XCTestCase {
    func testFoldSpeedIsPositiveOnlyWhenClosing() {
        XCTAssertEqual(GroceryToss.foldSpeed(previous: 100, current: 80, dt: 0.2), 100, accuracy: 1e-9)
        XCTAssertEqual(GroceryToss.foldSpeed(previous: 80, current: 100, dt: 0.2), 0, accuracy: 1e-9)
        XCTAssertEqual(GroceryToss.foldSpeed(previous: 90, current: 90, dt: 0.1), 0, accuracy: 1e-9)
    }

    func testLaunchGateIsAboutFortyFiveDegrees() {
        XCTAssertEqual(GroceryToss.launchAngleMax, 45, accuracy: 1e-9)
        XCTAssertTrue(GroceryToss.canLaunch(angle: 45))
        XCTAssertTrue(GroceryToss.canLaunch(angle: 30))
        XCTAssertFalse(GroceryToss.canLaunch(angle: 46))
        XCTAssertFalse(GroceryToss.canLaunch(angle: 90))
    }

    func testImpulseOnlyAccumulatesWhileGatedAndClosing() {
        let gated = GroceryToss.impulseDelta(foldSpeed: 40, angle: 40, dt: 0.1)
        XCTAssertEqual(gated, 4, accuracy: 1e-9)
        XCTAssertEqual(GroceryToss.impulseDelta(foldSpeed: 40, angle: 60, dt: 0.1), 0, accuracy: 1e-9)
        XCTAssertEqual(GroceryToss.impulseDelta(foldSpeed: 0, angle: 30, dt: 0.1), 0, accuracy: 1e-9)
    }

    func testStrongerImpulseCoastsFaster() {
        let soft = GroceryToss.coastSpeed(fromImpulse: GroceryToss.launchImpulseDegrees)
        let hard = GroceryToss.coastSpeed(fromImpulse: GroceryToss.launchImpulseDegrees * 3)
        XCTAssertGreaterThan(hard, soft)
        XCTAssertGreaterThanOrEqual(soft, GroceryToss.minCoastPerSec)
        XCTAssertLessThanOrEqual(hard, GroceryToss.maxCoastPerSec)
    }

    func testCoastAdvancesWithoutFurtherFoldInput() {
        let speed = GroceryToss.referenceCoastPerSec
        let step = GroceryToss.coastProgressDelta(coastSpeed: speed, progress: 0.2, dt: 0.1)
        XCTAssertGreaterThan(step, 0)
        // Mid-arc momentum factor is higher than the start.
        let early = GroceryToss.coastProgressDelta(coastSpeed: speed, progress: 0.05, dt: 0.1)
        let mid = GroceryToss.coastProgressDelta(coastSpeed: speed, progress: 0.5, dt: 0.1)
        XCTAssertGreaterThan(mid, early)
    }

    func testParabolaArcsAboveChordAndLandsAtCartCenter() {
        let cart = CGPoint(x: 400, y: 300)
        let side: CGFloat = 200
        let start = GroceryToss.tomatoPosition(progress: 0, cartCenter: cart, cartSide: side)
        let mid = GroceryToss.tomatoPosition(progress: 0.5, cartCenter: cart, cartSide: side)
        let end = GroceryToss.tomatoPosition(progress: 1, cartCenter: cart, cartSide: side)

        // Start is right of center so the landing can sit in the basket middle.
        XCTAssertGreaterThan(start.x, cart.x)
        XCTAssertEqual(end.x, cart.x, accuracy: 0.5)
        // Apex sits above the straight chord between start and end.
        let chordMidY = (start.y + end.y) / 2
        XCTAssertLessThan(mid.y, chordMidY)
    }
}
