import XCTest
import SwiftUI
@testable import HingeForce

/// Small deterministic generator so the random-target tests are repeatable.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class HingeCutTests: XCTestCase {
    // MARK: Mapping

    func testKnifeAngleFollowsTheHingeOneToOne() {
        XCTAssertEqual(HingeCut.screenAngle(forHinge: 85), 60, accuracy: 1e-9)
        XCTAssertEqual(HingeCut.screenAngle(forHinge: 95) - HingeCut.screenAngle(forHinge: 85), 10, accuracy: 1e-9)
    }

    func testKnifeAngleIsHeldAtTheEndsOfTheRange() {
        XCTAssertEqual(HingeCut.screenAngle(forHinge: 0), HingeCut.screenAngle(forHinge: 40))
        XCTAssertEqual(HingeCut.screenAngle(forHinge: 200), HingeCut.screenAngle(forHinge: 130))
    }

    func testKnifeImageIsAlreadyPointingWhereHingeEightyFiveWantsIt() {
        // The artwork points about 60 degrees clockwise from up, so at hinge 85 it needs almost no turning.
        XCTAssertEqual(Illustration.knifeRestAngle, 59.75, accuracy: 0.05)
        XCTAssertEqual(CutScene.knifeRotation(forHinge: 85), 0, accuracy: 0.3)
        XCTAssertGreaterThan(CutScene.knifeRotation(forHinge: 100), 10)   // opening the lid turns it clockwise
    }

    // MARK: Random target

    func testTargetIsAlwaysInRangeAndAtLeastTenDegreesFromTheCurrentHinge() {
        var generator = SplitMix64(state: 1)
        for current in stride(from: 0.0, through: 200.0, by: 1.0) {
            for _ in 0..<200 {
                let target = HingeCut.randomTarget(current: current, using: &generator)
                XCTAssertTrue(HingeCut.hingeRange.contains(target), "current \(current) gave \(target)")
                XCTAssertGreaterThanOrEqual(abs(target - current), HingeCut.minTargetDistance - 1e-9,
                                            "current \(current) gave \(target)")
            }
        }
    }

    func testTargetCanLandOnEitherSideOfTheCurrentHinge() {
        var generator = SplitMix64(state: 7)
        let targets = (0..<400).map { _ in HingeCut.randomTarget(current: 85, using: &generator) }
        XCTAssertTrue(targets.contains { $0 < 75 })
        XCTAssertTrue(targets.contains { $0 > 95 })
    }

    func testTargetAtTheEdgesOfTheRangeOnlyGoesTheOnlyPossibleWay() {
        var generator = SplitMix64(state: 3)
        for _ in 0..<200 {
            XCTAssertGreaterThanOrEqual(HingeCut.randomTarget(current: 40, using: &generator), 50)
            XCTAssertLessThanOrEqual(HingeCut.randomTarget(current: 130, using: &generator), 120)
        }
    }

    func testTargetsAreSpreadAcrossTheWholeRange() {
        var generator = SplitMix64(state: 11)
        let targets = (0..<2000).map { _ in HingeCut.randomTarget(current: 85, using: &generator) }
        XCTAssertLessThan(targets.min()!, 45)
        XCTAssertGreaterThan(targets.max()!, 125)
    }

    func testSystemGeneratorOverloadStillHonoursTheRules() {
        for _ in 0..<500 {
            let target = HingeCut.randomTarget(current: 111)
            XCTAssertTrue(HingeCut.hingeRange.contains(target))
            XCTAssertGreaterThanOrEqual(abs(target - 111), 10)
        }
    }

    // MARK: On the line

    func testOnLineWithinToleranceOnly() {
        XCTAssertTrue(HingeCut.isOnLine(hinge: 74, target: 74))
        XCTAssertTrue(HingeCut.isOnLine(hinge: 74 + HingeCut.tolerance, target: 74))
        XCTAssertFalse(HingeCut.isOnLine(hinge: 74 + HingeCut.tolerance + 0.1, target: 74))
        XCTAssertFalse(HingeCut.isOnLine(hinge: 74 - HingeCut.tolerance - 0.1, target: 74))
    }

    func testToleranceIsWiderThanTheSensorsWholeDegreeSteps() {
        XCTAssertGreaterThanOrEqual(HingeCut.tolerance, 2)
    }

    // MARK: Geometry

    func testRimRadiusMatchesTheEllipseAtTheCardinalDirections() {
        XCTAssertEqual(HingeCut.rimRadius(atAngle: 0, rx: 145.5, ry: 111.8), 111.8, accuracy: 1e-6)
        XCTAssertEqual(HingeCut.rimRadius(atAngle: 180, rx: 145.5, ry: 111.8), 111.8, accuracy: 1e-6)
        XCTAssertEqual(HingeCut.rimRadius(atAngle: 90, rx: 145.5, ry: 111.8), 145.5, accuracy: 1e-6)
        XCTAssertEqual(HingeCut.rimRadius(atAngle: 270, rx: 145.5, ry: 111.8), 145.5, accuracy: 1e-6)
    }

    func testCutLineRunsFromTheCentreToJustInsideTheRimAtEveryHingeAngle() {
        let c = Illustration.cutCakeCenter
        let r = Illustration.cutCakeRadii
        for hinge in stride(from: HingeCut.hingeRange.lowerBound, through: HingeCut.hingeRange.upperBound, by: 5) {
            let end = CutScene.cutLineEnd(forHinge: hinge)
            let ellipse = pow((end.x - c.x) / r.width, 2) + pow((end.y - c.y) / r.height, 2)
            XCTAssertLessThan(ellipse, 1, "hinge \(hinge): line pokes out of the cake")
            XCTAssertGreaterThan(ellipse, 0.8, "hinge \(hinge): line stops well short of the rim")
        }
    }

    func testCutLineAndKnifeAgreeOnDirection() {
        // For every hinge angle, the cut line drawn for it points the same way the knife does when the lid is there.
        let c = Illustration.cutCakeCenter
        for hinge in stride(from: 40.0, through: 130.0, by: 10) {
            let end = CutScene.cutLineEnd(forHinge: hinge)
            let lineAngle = atan2(end.x - c.x, -(end.y - c.y)) * 180 / .pi
            XCTAssertEqual(lineAngle, HingeCut.screenAngle(forHinge: hinge), accuracy: 1e-6)
            let knifeAngle = CutScene.knifeRotation(forHinge: hinge) + Illustration.knifeRestAngle
            XCTAssertEqual(knifeAngle, HingeCut.screenAngle(forHinge: hinge), accuracy: 1e-6)
        }
    }

    func testTheKnifeIsPinnedToTheCentreOfTheCake() {
        // The image is slid so the indicator line's start lands on the centre of the cake's top face.
        let pivot = Illustration.knifePivot
        let centre = Illustration.cutCakeCenter
        XCTAssertEqual(pivot.x, 15.1422, accuracy: 1e-4)
        XCTAssertEqual(pivot.y, 163.662, accuracy: 1e-3)
        XCTAssertEqual(centre.x, Illustration.cutCakeSize.width / 2, accuracy: 1e-9)
        XCTAssertEqual(Illustration.cutCakeRadii.height, centre.y, accuracy: 1e-9)  // top face reaches the canvas top
    }

    // MARK: Colour

    func testLineStartsCakePurpleAndEndsWhite() {
        let purple = NSColor(CutScene.lineColor(alignment: 0)).usingColorSpace(.sRGB)!
        XCTAssertEqual(purple.redComponent, 0xB5 / 255.0, accuracy: 0.01)
        XCTAssertEqual(purple.greenComponent, 0x96 / 255.0, accuracy: 0.01)
        XCTAssertEqual(purple.blueComponent, 0xE5 / 255.0, accuracy: 0.01)

        let white = NSColor(CutScene.lineColor(alignment: 1)).usingColorSpace(.sRGB)!
        XCTAssertEqual(white.redComponent, 1, accuracy: 0.01)
        XCTAssertEqual(white.greenComponent, 1, accuracy: 0.01)
        XCTAssertEqual(white.blueComponent, 1, accuracy: 0.01)

        let halfway = NSColor(CutScene.lineColor(alignment: 0.5)).usingColorSpace(.sRGB)!
        XCTAssertGreaterThan(halfway.greenComponent, purple.greenComponent)
        XCTAssertLessThan(halfway.greenComponent, white.greenComponent)
    }
}

final class AlignmentTrackerTests: XCTestCase {
    private let dt = 1.0 / 60.0

    private func run(_ tracker: inout AlignmentTracker, onLine: Bool, seconds: Double) {
        for _ in 0..<Int((seconds / dt).rounded()) { tracker.update(onLine: onLine, dt: dt) }
    }

    func testLineTurnsWhiteGraduallyThenCompletes() {
        var tracker = AlignmentTracker()
        run(&tracker, onLine: true, seconds: HingeCut.holdDuration / 2)
        XCTAssertEqual(tracker.progress, 0.5, accuracy: 0.05)
        XCTAssertFalse(tracker.isComplete)

        run(&tracker, onLine: true, seconds: HingeCut.holdDuration / 2 + 0.1)
        XCTAssertEqual(tracker.progress, 1)
        XCTAssertTrue(tracker.isComplete)
    }

    func testHoldIsSlowEnoughToBeGradualButNotTedious() {
        XCTAssertGreaterThanOrEqual(HingeCut.holdDuration, 1)
        XCTAssertLessThanOrEqual(HingeCut.holdDuration, 3)
    }

    func testLineFadesBackIfTheLidDriftsOff() {
        var tracker = AlignmentTracker()
        run(&tracker, onLine: true, seconds: HingeCut.holdDuration * 0.6)
        let before = tracker.progress
        run(&tracker, onLine: false, seconds: HingeCut.holdDuration * 0.3)
        XCTAssertLessThan(tracker.progress, before)
        XCTAssertGreaterThan(tracker.progress, 0)
        run(&tracker, onLine: false, seconds: HingeCut.holdDuration)
        XCTAssertEqual(tracker.progress, 0)
        XCTAssertFalse(tracker.isComplete)
    }

    func testNeverCompletesWithoutBeingOnTheLine() {
        var tracker = AlignmentTracker()
        run(&tracker, onLine: false, seconds: 30)
        XCTAssertFalse(tracker.isComplete)
        XCTAssertEqual(tracker.progress, 0)
    }

    func testStaysCompleteOnceDone() {
        var tracker = AlignmentTracker()
        run(&tracker, onLine: true, seconds: HingeCut.holdDuration + 0.2)
        run(&tracker, onLine: false, seconds: 10)
        XCTAssertTrue(tracker.isComplete)
        XCTAssertEqual(tracker.progress, 1)
    }
}
