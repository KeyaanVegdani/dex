import XCTest
@testable import HingeForce

final class PressCutTests: XCTestCase {
    // MARK: Pressure -> knife

    func testKnifeIsRaisedAtTheLightestTouchAndFullyDownAtFullPressure() {
        XCTAssertEqual(PressCut.depth(forReading: 1), 0)
        XCTAssertEqual(PressCut.depth(forReading: 10), 1)
        XCTAssertEqual(PressCut.knifeY(atDepth: 0), Illustration.pressKnifeRaisedY)
        XCTAssertEqual(PressCut.knifeY(atDepth: 1), Illustration.pressKnifeLoweredY)
    }

    func testTheHarderYouPressTheLowerTheKnifeGoes() {
        var previous = PressCut.knifeY(atDepth: PressCut.depth(forReading: 1))
        for reading in stride(from: 1.5, through: 10.0, by: 0.5) {
            let y = PressCut.knifeY(atDepth: PressCut.depth(forReading: reading))
            XCTAssertGreaterThan(y, previous, "reading \(reading)")   // larger y is lower on screen
            previous = y
        }
    }

    func testDepthIsClampedForReadingsOutsideTheScale() {
        XCTAssertEqual(PressCut.depth(forReading: -5), 0)
        XCTAssertEqual(PressCut.depth(forReading: 40), 1)
        XCTAssertEqual(PressCut.knifeY(atDepth: 3), Illustration.pressKnifeLoweredY)
    }

    // MARK: Completing

    private let dt = 1.0 / 60.0

    private func run(_ tracker: inout PressTracker, reading: Double, seconds: Double) {
        for _ in 0..<Int((seconds / dt).rounded()) { tracker.update(reading: reading, dt: dt) }
    }

    func testCompletesOnceThePressIsAtTheMostForAMoment() {
        var tracker = PressTracker()
        run(&tracker, reading: 10, seconds: PressCut.holdDuration - 0.1)
        XCTAssertFalse(tracker.isComplete)
        run(&tracker, reading: 10, seconds: 0.2)
        XCTAssertTrue(tracker.isComplete)
    }

    func testThereIsToleranceBelowTheAbsoluteMaximum() {
        XCTAssertLessThan(PressCut.threshold, 10)
        XCTAssertGreaterThanOrEqual(PressCut.threshold, 8)
        var tracker = PressTracker()
        run(&tracker, reading: PressCut.threshold, seconds: PressCut.holdDuration + 0.1)
        XCTAssertTrue(tracker.isComplete)
    }

    func testAPressJustShortOfTheToleranceNeverCompletes() {
        var tracker = PressTracker()
        run(&tracker, reading: PressCut.threshold - 0.3, seconds: 30)
        XCTAssertFalse(tracker.isComplete)
        XCTAssertEqual(tracker.progress, 0)
    }

    func testEasingOffLosesProgressSoAQuickBrushAtTheTopDoesNotCount() {
        var tracker = PressTracker()
        run(&tracker, reading: 10, seconds: PressCut.holdDuration * 0.6)
        run(&tracker, reading: 5, seconds: PressCut.holdDuration)
        XCTAssertEqual(tracker.progress, 0)
        run(&tracker, reading: 10, seconds: PressCut.holdDuration * 0.6)
        XCTAssertFalse(tracker.isComplete)
    }

    func testStaysCompleteEvenIfYouLetGo() {
        var tracker = PressTracker()
        run(&tracker, reading: 10, seconds: 1)
        run(&tracker, reading: 1, seconds: 5)
        XCTAssertTrue(tracker.isComplete)
    }

    // MARK: Layout of the artwork

    func testTheCakeIsCentredOnThePlate() {
        let frontCentre = Illustration.pressFrontOrigin.x + 193.258
        XCTAssertEqual(frontCentre, 232.136, accuracy: 0.01)
        XCTAssertEqual(232.136, Illustration.pressPlateSize.width / 2, accuracy: 0.5)
    }

    func testTheSliceIsTuckedInsideTheRightHalfOfTheCakeFront() {
        // The slice artwork has a fraction of a unit of empty margin inside its canvas; measure what is drawn.
        let front = Illustration.pressFrontOrigin
        let slice = Illustration.pressSliceOrigin
        let squeeze = Illustration.pressSliceSize.width / 194
        let drawnLeft = slice.x + 0.258 * squeeze
        let drawnRight = slice.x + 193.516 * squeeze
        let frontCentre = front.x + 193.258
        let frontRight = front.x + 386.516

        XCTAssertGreaterThanOrEqual(drawnLeft, frontCentre, "no further left than the cake's centre line")
        XCTAssertLessThan(drawnLeft - frontCentre, 1, "but only just")
        XCTAssertLessThanOrEqual(drawnRight, frontRight, "no further right than the cake's edge")
        XCTAssertLessThan(frontRight - drawnRight, 1, "but only just")
        XCTAssertEqual(slice.y, front.y, "tops line up")
    }

    func testTheKnifeStartsAboveTheCakeAndEndsOnThePlate() {
        let cakeTop = Illustration.pressFrontOrigin.y
        XCTAssertLessThan(Illustration.pressKnifeRaisedY + Illustration.pressKnifeSize.height, cakeTop, "raised knife clears the cake")
        let plateBottom = Illustration.pressPlateSize.height
        XCTAssertLessThan(Illustration.pressKnifeLoweredY + Illustration.pressKnifeSize.height, plateBottom, "lowered knife rests on the plate")
        XCTAssertGreaterThan(Illustration.pressKnifeLoweredY, cakeTop, "and is down inside the cake's height")
    }

    // MARK: Cake front pops away

    func testCakeFrontStartsWholeAndInPlace() {
        let pose = PressCut.frontPose(elapsed: nil)
        XCTAssertEqual(pose.scale, 1)
        XCTAssertEqual(pose.origin, Illustration.pressFrontOrigin)
        XCTAssertEqual(PressCut.frontPose(elapsed: 0), pose, "and waits a beat after the cut is done")
        XCTAssertEqual(PressCut.frontPose(elapsed: PressCut.popDelay), pose)
    }

    func testCakeFrontEndsSmallAtTheLeftOfThePlateAsInTheDesign() {
        let end = PressCut.frontPose(elapsed: PressCut.popDelay + PressCut.popDuration)
        XCTAssertEqual(end.scale, Illustration.pressFrontFinalScale, accuracy: 1e-9)
        XCTAssertEqual(end.scale, 0.07, accuracy: 0.001)
        XCTAssertEqual(end.origin.x, Illustration.pressFrontOrigin.x, "shrinks towards its left edge")
        XCTAssertEqual(end.origin.y, Illustration.pressFrontFinalOrigin.y, accuracy: 1e-9)
        XCTAssertEqual(PressCut.frontPose(elapsed: 10), end)
    }

    func testCakeFrontHopsUpBeforeDroppingAway() {
        let startY = Illustration.pressFrontOrigin.y
        let earlyMin = stride(from: PressCut.popDelay, through: PressCut.popDelay + 0.3, by: 0.01)
            .map { PressCut.frontPose(elapsed: $0).origin.y }.min()!
        XCTAssertLessThan(earlyMin, startY - 20, "it visibly pops up before it falls")
    }

    func testCakeFrontLandsWithASmallBounceThatStaysOnThePlate() {
        let finalY = Illustration.pressFrontFinalOrigin.y
        let ys = stride(from: 0.0, through: 2.0, by: 0.005).map { PressCut.frontPose(elapsed: $0).origin.y }
        let lowest = ys.max()!
        XCTAssertGreaterThan(lowest, finalY + 1, "overshoots a little — the bounce")
        XCTAssertLessThan(lowest, Illustration.pressPlateSize.height - 20, "but never off the plate")
    }

    func testCakeFrontNeverFlipsOrGoesNegativeWhileShrinking() {
        for t in stride(from: 0.0, through: 2.0, by: 0.005) {
            let scale = PressCut.frontPose(elapsed: t).scale
            XCTAssertGreaterThan(scale, 0, "t=\(t)")
            XCTAssertLessThanOrEqual(scale, 1 + 1e-9)
        }
    }

    func testKnifeFinishesItsLastStretchToTheBottom() {
        XCTAssertEqual(PressCut.settledDepth(from: 0.88, elapsed: 0), 0.88, accuracy: 1e-9)
        XCTAssertEqual(PressCut.settledDepth(from: 0.88, elapsed: PressCut.knifeSettleDuration), 1, accuracy: 1e-9)
        XCTAssertGreaterThan(PressCut.settledDepth(from: 0.88, elapsed: 0.1), 0.88)
    }

    func testContinueAppearsAfterTheCakeHasLanded() {
        XCTAssertGreaterThanOrEqual(PressCut.continueStart, PressCut.popDelay + PressCut.popDuration)
    }
}
