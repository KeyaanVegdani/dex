import XCTest
import SwiftUI
@testable import HingeForce

final class WashCutTests: XCTestCase {
    private let messes = Illustration.washMesses

    // MARK: Tilt -> swing

    func testShowerHangsStraightWhenTheLaptopIsLevel() {
        XCTAssertEqual(WashCut.swing(forRoll: 0), 0)
    }

    func testShowerSwingsFurtherThanTheLaptopTipsSoASmallTiltIsEnough() {
        XCTAssertEqual(WashCut.swing(forRoll: 10), 10 * WashCut.swingPerRoll * WashCut.swingDirection, accuracy: 1e-9)
        XCTAssertGreaterThan(abs(WashCut.swing(forRoll: 10)), 10)
    }

    func testSwingIsSymmetricAndClamped() {
        XCTAssertEqual(WashCut.swing(forRoll: -12), -WashCut.swing(forRoll: 12), accuracy: 1e-9)
        XCTAssertEqual(abs(WashCut.swing(forRoll: 80)), WashCut.maxSwing)
        XCTAssertEqual(abs(WashCut.swing(forRoll: -80)), WashCut.maxSwing)
    }

    func testAComfortableTiltReachesTheEdgeOfThePlate() {
        XCTAssertLessThanOrEqual(WashCut.maxSwing / WashCut.swingPerRoll, 25, "reaching the ends needs no more than about 25 degrees of tilt")
    }

    // MARK: Geometry

    func testStraightDownWaterLandsInTheMiddleOfThePlate() {
        XCTAssertEqual(WashCut.landingX(swing: 0), 232.136, accuracy: 0.01)
        XCTAssertEqual(WashCut.nozzle(swing: 0).x, 232.136, accuracy: 0.01)
    }

    func testWaterLandsFurtherRightTheMoreItSwingsRight() {
        var previous = -Double.infinity
        for swing in stride(from: -32.0, through: 32.0, by: 4) {
            let x = WashCut.landingX(swing: swing)
            XCTAssertGreaterThan(x, previous, "swing \(swing)")
            previous = x
        }
        XCTAssertEqual(WashCut.landingX(swing: 20) + WashCut.landingX(swing: -20), 2 * 232.136, accuracy: 0.01)
    }

    func testFullSwingReachesEachEdgeOfThePlateWithoutLeavingIt() {
        let right = WashCut.landingX(swing: WashCut.maxSwing)
        let left = WashCut.landingX(swing: -WashCut.maxSwing)
        XCTAssertLessThan(right, Illustration.pressPlateSize.width)
        XCTAssertGreaterThan(right, Illustration.pressPlateSize.width - 40)
        XCTAssertGreaterThan(left, 0)
        XCTAssertLessThan(left, 40)
    }

    func testEveryMessCanBeReached() {
        for mess in messes {
            let reachable = stride(from: -WashCut.maxSwing, through: WashCut.maxSwing, by: 0.5)
                .contains { WashCut.isWashing(mess, swing: $0) }
            XCTAssertTrue(reachable, "\(mess.name) can't be reached")
        }
    }

    func testNothingGetsWashedWhileTheShowerJustHangsThere() {
        for mess in messes { XCTAssertFalse(WashCut.isWashing(mess, swing: 0), "\(mess.name)") }
    }

    func testEachMessIsWashedOnlyWhenTheWaterIsOverIt() {
        let big = messes.first { $0.name == "Mess-1" }!
        // Aim at the middle of the mess, then well to the side of it.
        let onIt = stride(from: -32.0, through: 32.0, by: 0.25).first { abs(WashCut.landingX(swing: $0) - big.xRange.lowerBound - 73) < 1 }!
        XCTAssertTrue(WashCut.isWashing(big, swing: onIt))
        XCTAssertFalse(WashCut.isWashing(big, swing: 25))
    }

    func testAMessIsNotWashedByJustBrushingItsTip() {
        let mess = messes.first { $0.name == "Mess-3" }!
        // Water whose right edge only just touches the left tip of the mess.
        let centre = mess.xRange.lowerBound - WashCut.streamHalfWidth + 1
        let swing = stride(from: -32.0, through: 32.0, by: 0.05).min { abs(WashCut.landingX(swing: $0) - centre) < abs(WashCut.landingX(swing: $1) - centre) }!
        XCTAssertFalse(WashCut.isWashing(mess, swing: swing))
    }

    // MARK: Cleaning

    private let dt = 1.0 / 60.0

    private func run(_ tracker: inout WashTracker, swing: Double, seconds: Double) {
        for _ in 0..<Int((seconds / dt).rounded()) { tracker.update(swing: swing, dt: dt) }
    }

    private func swing(over mess: Illustration.Mess) -> Double {
        let middle = (mess.xRange.lowerBound + mess.xRange.upperBound) / 2
        return stride(from: -32.0, through: 32.0, by: 0.1).min { abs(WashCut.landingX(swing: $0) - middle) < abs(WashCut.landingX(swing: $1) - middle) }!
    }

    func testAMessNeedsTwoSecondsOfWaterToWashAway() {
        XCTAssertEqual(WashCut.secondsToClean, 2)
        let mess = messes[0]
        var tracker = WashTracker()
        run(&tracker, swing: swing(over: mess), seconds: 1.9)
        XCTAssertLessThan(tracker.washed[0], 2)
        XCTAssertGreaterThan(WashCut.messOpacity(washed: tracker.washed[0]), 0)
        run(&tracker, swing: swing(over: mess), seconds: 0.2)
        XCTAssertEqual(tracker.washed[0], 2, accuracy: 1e-9)
        XCTAssertEqual(WashCut.messOpacity(washed: tracker.washed[0]), 0)
    }

    func testMessFadesSteadilyRatherThanAllAtOnce() {
        XCTAssertEqual(WashCut.messOpacity(washed: 0), 1)
        XCTAssertEqual(WashCut.messOpacity(washed: 1), 0.5, accuracy: 1e-9)
        XCTAssertEqual(WashCut.messOpacity(washed: 2), 0)
        XCTAssertEqual(WashCut.messOpacity(washed: 9), 0)
        XCTAssertEqual(WashCut.messOpacity(washed: -1), 1)
    }

    func testWashedProgressIsKeptWhenTheWaterMovesOn() {
        let mess = messes[0]
        var tracker = WashTracker()
        run(&tracker, swing: swing(over: mess), seconds: 1)
        run(&tracker, swing: 30, seconds: 5)
        XCTAssertEqual(tracker.washed[0], 1, accuracy: 0.05, "dirt doesn't come back, and elsewhere doesn't wash it")
    }

    func testOnlyTheMessUnderTheWaterIsWashed() {
        let mess = messes[4]   // Mess-3, far to the right
        var tracker = WashTracker()
        run(&tracker, swing: swing(over: mess), seconds: 1)
        XCTAssertGreaterThan(tracker.washed[4], 0.9)
        XCTAssertEqual(tracker.washed[0], 0)
        XCTAssertEqual(tracker.washed[1], 0)
    }

    func testOverlappingMessesAreWashedTogether() {
        let a = messes.first { $0.name == "Mess-3-1" }!, b = messes.first { $0.name == "Mess-4" }!
        let middle = (max(a.xRange.lowerBound, b.xRange.lowerBound) + min(a.xRange.upperBound, b.xRange.upperBound)) / 2
        let aim = stride(from: -32.0, through: 32.0, by: 0.1).min { abs(WashCut.landingX(swing: $0) - middle) < abs(WashCut.landingX(swing: $1) - middle) }!
        var tracker = WashTracker()
        run(&tracker, swing: aim, seconds: 1)
        XCTAssertGreaterThan(tracker.washed[2], 0.9)
        XCTAssertGreaterThan(tracker.washed[3], 0.9)
    }

    func testThePlateIsCleanOnlyOnceEveryMessHasHadItsTwoSeconds() {
        var tracker = WashTracker()
        for (index, mess) in messes.enumerated() {
            XCTAssertFalse(tracker.isComplete, "before \(mess.name) (\(index))")
            run(&tracker, swing: swing(over: mess), seconds: 2.1)
        }
        XCTAssertTrue(tracker.isComplete)
    }

    // MARK: Finishing

    func testShowerLiftsAwayAndTheWaterStopsWhenTheLastMessIsGone() {
        XCTAssertEqual(WashCut.showerOpacity(elapsed: nil), 1)
        XCTAssertEqual(WashCut.showerLift(elapsed: nil), 0)
        XCTAssertEqual(WashCut.streamOpacity(elapsed: nil), 1)
        XCTAssertEqual(WashCut.showerOpacity(elapsed: WashCut.exitDuration), 0, accuracy: 1e-9)
        XCTAssertGreaterThan(WashCut.showerLift(elapsed: WashCut.exitDuration), 50)
        XCTAssertEqual(WashCut.streamOpacity(elapsed: WashCut.streamFadeDuration), 0, accuracy: 1e-9)
    }

    func testPlateSwapsToItsShinyVersionAndSettlesLowerOnTheScreen() {
        XCTAssertEqual(WashCut.glossOpacity(elapsed: nil), 0)
        XCTAssertEqual(WashCut.glossOpacity(elapsed: 3), 1, accuracy: 1e-9)
        XCTAssertEqual(WashCut.plateOffset(elapsed: nil), 0)
        XCTAssertEqual(WashCut.plateOffset(elapsed: 5), WashCut.plateDrop, accuracy: 1e-9)
        XCTAssertEqual(WashCut.plateDrop, 60, "the design's clean plate sits about 60 units lower")
    }

    func testStarsSparkleOneAfterAnotherAndKeepTwinkling() {
        for i in 0..<3 { XCTAssertEqual(WashCut.sparkleScale(index: i, elapsed: nil, time: 1), 0) }
        XCTAssertEqual(WashCut.sparkleScale(index: 0, elapsed: WashCut.sparkleStart - 0.05, time: 1), 0)
        XCTAssertGreaterThan(WashCut.sparkleScale(index: 0, elapsed: WashCut.sparkleStart + 0.4, time: 1), 0.3)
        XCTAssertEqual(WashCut.sparkleScale(index: 2, elapsed: WashCut.sparkleStart + 0.2, time: 1), 0, "the third star isn't out yet")

        let scales = stride(from: 0.0, through: 4.0, by: 0.05).map { WashCut.sparkleScale(index: 0, elapsed: 3 + $0, time: 6 + $0) }
        XCTAssertGreaterThan(scales.max()! - scales.min()!, 0.3, "the star pulses")
        XCTAssertGreaterThan(scales.min()!, 0.4, "but never disappears")
        XCTAssertLessThan(scales.max()!, 1.2)
    }

    func testFinishButtonComesAfterTheSparklesHaveStarted() {
        XCTAssertGreaterThan(WashCut.continueStart, WashCut.sparkleStart)
        XCTAssertGreaterThan(WashCut.continueStart, WashCut.plateDropStart + WashCut.plateDropDuration)
    }

    func testGlossBandRunsDiagonallyAcrossThePlateTopAndStaysInsideIt() {
        let band = GlossBand.path()
        XCTAssertTrue(band.contains(CGPoint(x: 130, y: 40)), "in the middle of the band")
        XCTAssertTrue(band.contains(CGPoint(x: 245, y: 8)), "up at the far edge")
        XCTAssertFalse(band.contains(CGPoint(x: 320, y: 40)), "to the right of the band")
        XCTAssertFalse(band.contains(CGPoint(x: 20, y: 40)), "to the left of the band")
        let box = band.boundingRect
        XCTAssertGreaterThanOrEqual(box.minX, 232.136 - 210.244 - 0.5)
        XCTAssertLessThanOrEqual(box.maxX, 232.136 + 210.244 + 0.5)
        XCTAssertGreaterThanOrEqual(box.minY, -0.5)
        XCTAssertLessThanOrEqual(box.maxY, 80.6)
    }
}

final class RainTests: XCTestCase {
    func testTheRainIsAlwaysFalling() {
        for t in stride(from: 0.0, through: 3.0, by: 0.1) {
            XCTAssertGreaterThan(Rain.drops(at: t, swing: 0).count, 25, "t=\(t)")
        }
    }

    func testTheRainIsTheSameEveryTimeItIsAskedFor() {
        XCTAssertEqual(Rain.drops(at: 1.234, swing: 12), Rain.drops(at: 1.234, swing: 12))
    }

    func testDropsFallDownwardsOverTime() {
        let before = Rain.drops(at: 1.0, swing: 0)
        let after = Rain.drops(at: 1.0 + 0.02, swing: 0)
        // A drop in the middle of its fall moves down by speed * dt, so each drop in `before` has a partner further down.
        let moved = before.filter { drop in
            after.contains { abs($0.position.x - drop.position.x) < 0.01 && abs(Double($0.position.y - drop.position.y) - Rain.speed * 0.02) < 0.5 }
        }
        XCTAssertGreaterThan(moved.count, before.count / 2)
    }

    func testDropsStartBelowTheNozzleAndAreGoneByTheTimeTheyReachTheBottomOfThePlate() {
        for swing in [-30.0, 0, 30] {
            let nozzle = WashCut.nozzle(swing: swing)
            for t in stride(from: 0.0, through: 2.0, by: 0.13) {
                for drop in Rain.drops(at: t, swing: swing) {
                    // The nozzle is a flange that tilts with the shower, so its outer lanes start a little higher.
                    let flangeTilt = Rain.laneOffsets.map(abs).max()! * abs(sin(swing * .pi / 180))
                    XCTAssertGreaterThanOrEqual(drop.position.y, nozzle.y - flangeTilt - 0.01)
                    XCTAssertLessThanOrEqual(drop.position.y, Rain.landingDepth.upperBound + 0.01)
                    XCTAssertGreaterThan(drop.opacity, 0)
                    XCTAssertLessThanOrEqual(drop.opacity, 1)
                }
            }
        }
    }

    func testDropsFadeAwayAsTheyHitThePlate() {
        var drops: [Rain.Drop] = []
        for t in stride(from: 0.0, through: 3.0, by: 0.07) { drops += Rain.drops(at: t, swing: 0) }
        let high = drops.filter { $0.position.y < -100 }
        // Anything within the fade distance of the deepest landing spot is in the middle of fading away.
        let landing = drops.filter { $0.position.y > Rain.landingDepth.upperBound - Rain.fadeDistance + 1 }
        XCTAssertFalse(high.isEmpty)
        XCTAssertFalse(landing.isEmpty)
        XCTAssertTrue(high.allSatisfy { $0.opacity == 1 }, "high up they are solid")
        XCTAssertTrue(landing.allSatisfy { $0.opacity < 1 }, "at the plate they are fading")
    }

    func testStreamFollowsTheShowerSoTheWaterLandsWhereTheStreamPoints() {
        for swing in [-25.0, 0, 25] {
            let landed = Rain.drops(at: 1.7, swing: swing).filter { $0.position.y > 20 }
            XCTAssertFalse(landed.isEmpty)
            let averageX = landed.map { Double($0.position.x) }.reduce(0, +) / Double(landed.count)
            XCTAssertEqual(averageX, WashCut.landingX(swing: swing), accuracy: 30, "swing \(swing)")
        }
    }

    func testDropsStayWithinTheStreamsWidth() {
        for swing in [-20.0, 0, 20] {
            let n = WashCut.nozzle(swing: swing), d = WashCut.direction(swing: swing)
            for drop in Rain.drops(at: 0.9, swing: swing) {
                let across = Double(drop.position.x - n.x) * Double(d.y) - Double(drop.position.y - n.y) * Double(d.x)
                XCTAssertLessThanOrEqual(abs(across), 21.01, "swing \(swing)")
            }
        }
    }

    func testRandomLandingDepthsAreSpreadOut() {
        let values = (0..<200).map { Rain.random(lane: $0 % 6, drop: $0) }
        XCTAssertGreaterThan(values.min()!, -0.0001)
        XCTAssertLessThan(values.max()!, 1)
        XCTAssertGreaterThan(values.max()! - values.min()!, 0.8)
    }
}

final class AccelerometerMathTests: XCTestCase {
    /// A real report from this MacBook lying flat on a desk.
    private let flatReport: [UInt8] = [0x59, 0x99, 0, 0, 0, 0, 0x87, 0, 0, 0, 0x6d, 1, 0, 0, 0x82, 0xfc, 0xfe, 0xff, 0, 0x33, 0x21, 0]

    func testDecodesARealReportAsAboutOneGOnTheZAxis() throws {
        let g = try XCTUnwrap(AccelerometerMath.gravity(fromReport: flatReport))
        XCTAssertEqual(g.x, 135.0 / 65536, accuracy: 1e-9)
        XCTAssertEqual(g.y, 365.0 / 65536, accuracy: 1e-9)
        XCTAssertEqual(g.z, -66430.0 / 65536, accuracy: 1e-9)   // bytes 82 fc fe ff = 0xFFFEFC82 = -66430
        XCTAssertEqual(g.z, -1, accuracy: 0.02)
    }

    func testRejectsReportsThatAreTooShort() {
        XCTAssertNil(AccelerometerMath.gravity(fromReport: [1, 2, 3]))
        XCTAssertNil(AccelerometerMath.gravity(fromReport: []))
    }

    func testLevelLaptopHasNoRoll() {
        XCTAssertEqual(AccelerometerMath.rollDegrees(x: 0, y: 0, z: -1), 0, accuracy: 1e-9)
        let g = AccelerometerMath.gravity(fromReport: flatReport)!
        XCTAssertEqual(AccelerometerMath.rollDegrees(x: g.x, y: g.y, z: g.z), 0, accuracy: 0.5)
    }

    func testRollFollowsTheSidewaysTiltInBothDirections() {
        for degrees in [5.0, 15, 30, 45] {
            let r = degrees * .pi / 180
            XCTAssertEqual(AccelerometerMath.rollDegrees(x: sin(r), y: 0, z: -cos(r)), degrees, accuracy: 1e-6)
            XCTAssertEqual(AccelerometerMath.rollDegrees(x: -sin(r), y: 0, z: -cos(r)), -degrees, accuracy: 1e-6)
        }
    }

    func testTippingTheLaptopForwardsOrBackwardsDoesNotCountAsRoll() {
        for degrees in [10.0, 25, 40] {
            let r = degrees * .pi / 180
            XCTAssertEqual(AccelerometerMath.rollDegrees(x: 0, y: sin(r), z: -cos(r)), 0, accuracy: 1e-9)
        }
    }

    func testLevelLaptopHasNoPitch() {
        XCTAssertEqual(AccelerometerMath.pitchDegrees(x: 0, y: 0, z: -1), 0, accuracy: 1e-9)
        let g = AccelerometerMath.gravity(fromReport: flatReport)!
        XCTAssertEqual(AccelerometerMath.pitchDegrees(x: g.x, y: g.y, z: g.z), 0, accuracy: 0.5)
    }

    func testPitchFollowsForwardBackTilt() {
        for degrees in [5.0, 15, 30, 45] {
            let r = degrees * .pi / 180
            XCTAssertEqual(AccelerometerMath.pitchDegrees(x: 0, y: sin(r), z: -cos(r)), degrees, accuracy: 1e-6)
            XCTAssertEqual(AccelerometerMath.pitchDegrees(x: 0, y: -sin(r), z: -cos(r)), -degrees, accuracy: 1e-6)
        }
    }

    func testRollingSidewaysDoesNotCountAsPitch() {
        for degrees in [10.0, 25, 40] {
            let r = degrees * .pi / 180
            XCTAssertEqual(AccelerometerMath.pitchDegrees(x: sin(r), y: 0, z: -cos(r)), 0, accuracy: 1e-9)
        }
    }
}
