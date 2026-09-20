import XCTest
import SwiftUI
@testable import HingeForce

final class TestMotionTests: XCTestCase {
    // MARK: Hinge page

    func testTheLidStartsAtTheDefaultPoseWhichReadsFiftyPercent() {
        XCTAssertEqual(TestState().hinge, TestMotion.defaultHinge)
        XCTAssertEqual(TestMotion.lidRotation(hinge: TestState().hinge), 0, "the artwork is drawn as it is at the default")
        XCTAssertEqual(TestMotion.hingePercent(hinge: TestState().hinge), 50, accuracy: 1e-9)
    }

    func testOpeningTheHingeLeansTheLidBackAndClosingLeansItForward() {
        // Anticlockwise (negative) is leaning back, towards the left of the screen.
        XCTAssertEqual(TestMotion.lidRotation(hinge: 110), -10, accuracy: 1e-9)
        XCTAssertEqual(TestMotion.lidRotation(hinge: 90), 10, accuracy: 1e-9)
        var previous = Double.infinity
        for hinge in stride(from: 30.0, through: 150, by: 5) {
            let rotation = TestMotion.lidRotation(hinge: hinge)
            XCTAssertLessThan(rotation, previous)
            previous = rotation
        }
    }

    func testTheLidStaysOnScreenHoweverFarTheRealHingeGoes() {
        XCTAssertEqual(TestMotion.lidRotation(hinge: 0), TestMotion.lidRotation(hinge: TestMotion.hingeDrawRange.lowerBound))
        XCTAssertEqual(TestMotion.lidRotation(hinge: 360), TestMotion.lidRotation(hinge: TestMotion.hingeDrawRange.upperBound))
    }

    func testHingePercentIsTheAppsHingeReadingScale() {
        XCTAssertEqual(TestMotion.hingePercent(hinge: 40), 0, accuracy: 1e-9)
        XCTAssertEqual(TestMotion.hingePercent(hinge: 100), 50, accuracy: 1e-9)
        XCTAssertEqual(TestMotion.hingePercent(hinge: 130), 100, accuracy: 1e-9)
        XCTAssertEqual(TestMotion.hingePercent(hinge: 111), ReadingMap.hinge(angle: 111), accuracy: 1e-9)
    }

    func testTheLidsAnchorSitsExactlyOnTheCircleOnTheBase() {
        let origin = HingeScene.lidOrigin
        let pivot = TestArtwork.hingeLidPivot
        let circle = TestArtwork.hingeCircleCenter
        XCTAssertEqual(origin.x + pivot.x, circle.x, accuracy: 1e-9)
        XCTAssertEqual(origin.y + pivot.y, circle.y, accuracy: 1e-9)
        // The pivot is the bottom end of the lid image, and the circle is at the base's top-left corner.
        XCTAssertGreaterThan(pivot.x, TestArtwork.hingeLidSize.width * 0.9)
        XCTAssertGreaterThan(pivot.y, TestArtwork.hingeLidSize.height * 0.95)
        XCTAssertEqual(circle.x, 10)
        XCTAssertEqual(circle.y, 10)
    }

    // MARK: Microphone page

    func testMicLevelRunsFromSilenceToFullBlow() {
        XCTAssertEqual(TestMotion.micLevel(reading: 1), 0)
        XCTAssertEqual(TestMotion.micLevel(reading: 10), 1)
        XCTAssertEqual(TestMotion.micLevel(reading: 5.5), 0.5, accuracy: 1e-9)
        XCTAssertEqual(TestMotion.micLevel(reading: 30), 1)
        XCTAssertEqual(TestMotion.micLevel(reading: -3), 0)
    }

    func testSpeakerDotsStartAsTheDesignedBlueToCyanGradient() {
        XCTAssertEqual(MicSpeaker.color(row: 0, level: 0), RGB(hex: 0x4126EF))
        XCTAssertEqual(MicSpeaker.color(row: MicSpeaker.rows - 1, level: 0), RGB(hex: 0x38B1DD))
    }

    func testSpeakerDotsGetRedderTheLouderItGets() {
        var previousRedShare = -1.0
        for level in stride(from: 0.0, through: 1.0, by: 0.1) {
            for row in [0, 5, 11] {
                let c = MicSpeaker.color(row: row, level: level)
                XCTAssertTrue((0...1).contains(c.r) && (0...1).contains(c.g) && (0...1).contains(c.b))
            }
            let top = MicSpeaker.color(row: 0, level: level)
            let share = top.r - (top.g + top.b) / 2
            XCTAssertGreaterThan(share, previousRedShare, "level \(level)")
            previousRedShare = share
        }
        for row in 0..<MicSpeaker.rows {
            let c = MicSpeaker.color(row: row, level: 1)
            XCTAssertGreaterThan(c.r, c.b, "row \(row) is red-ish at full volume")
            XCTAssertGreaterThan(c.r, 0.85)
        }
    }

    func testSpeakerDotsStayAGradientFromTopToBottomAtEveryLevel() {
        for level in [0.0, 0.5, 1.0] {
            XCTAssertNotEqual(MicSpeaker.color(row: 0, level: level), MicSpeaker.color(row: 11, level: level))
        }
    }

    func testSpeakerDotGridMatchesTheArtwork() {
        XCTAssertEqual(MicSpeaker.columnX.count, MicSpeaker.columns)
        XCTAssertEqual(MicSpeaker.y(row: 0), 42)
        XCTAssertEqual(MicSpeaker.y(row: 11), 229)
        XCTAssertEqual(MicSpeaker.columnX.first, 22)
        XCTAssertEqual(MicSpeaker.columnX.last ?? 0, 68.8, accuracy: 1e-9)
        XCTAssertLessThan(MicSpeaker.y(row: 11) + MicSpeaker.dotRadius, TestArtwork.laptopSize.height)
    }

    // MARK: Trackpad page

    func testTrackpadCentreDarkensToTheDesignedColourAtFullPress() {
        XCTAssertEqual(TestMotion.trackpadTint(depth: 0), RGB(hex: 0xDAE3E6))
        XCTAssertEqual(TestMotion.trackpadTint(depth: 1), RGB(hex: 0xBECBD0))
        XCTAssertEqual(TestMotion.trackpadTint(depth: 7), RGB(hex: 0xBECBD0), "no darker than #BECBD0")
        XCTAssertEqual(TestMotion.trackpadTint(depth: -1), RGB(hex: 0xDAE3E6))
    }

    func testTrackpadGetsSteadilyDarkerWithPressure() {
        var previous = TestMotion.trackpadTint(depth: 0)
        for depth in stride(from: 0.1, through: 1.0, by: 0.1) {
            let tint = TestMotion.trackpadTint(depth: depth)
            XCTAssertLessThan(tint.r, previous.r)
            XCTAssertLessThan(tint.g, previous.g)
            XCTAssertLessThan(tint.b, previous.b)
            previous = tint
        }
    }

    // MARK: Rotate page

    func testRotationMirrorsTheAccelerometersRoll() {
        XCTAssertEqual(TestMotion.rotation(forRoll: 0), 0)
        XCTAssertEqual(TestMotion.rotation(forRoll: 25), 25 * TestMotion.rotationDirection, accuracy: 1e-9)
        XCTAssertEqual(TestMotion.rotation(forRoll: -25), -TestMotion.rotation(forRoll: 25), accuracy: 1e-9)
        XCTAssertEqual(abs(TestMotion.rotation(forRoll: 170)), 90, "never more than a quarter turn")
    }

    func testRotationPercentGrowsWithTiltEitherWayAndCapsAtOneHundred() {
        XCTAssertEqual(TestMotion.rotatePercent(roll: 0), 0)
        XCTAssertEqual(TestMotion.rotatePercent(roll: 22.5), 50, accuracy: 1e-9)
        XCTAssertEqual(TestMotion.rotatePercent(roll: -22.5), 50, accuracy: 1e-9)
        XCTAssertEqual(TestMotion.rotatePercent(roll: TestMotion.fullTilt), 100, accuracy: 1e-9)
        XCTAssertEqual(TestMotion.rotatePercent(roll: 80), 100)
    }

    func testRGBMixing() {
        let a = RGB(0, 0.2, 1), b = RGB(1, 0.6, 0)
        XCTAssertEqual(a.mixed(with: b, 0), a)
        XCTAssertEqual(a.mixed(with: b, 1), b)
        XCTAssertEqual(a.mixed(with: b, 0.5), RGB(0.5, 0.4, 0.5))
        XCTAssertEqual(a.mixed(with: b, 9), b)
        XCTAssertEqual(RGB(hex: 0xFF8000).g, 128.0 / 255, accuracy: 1e-9)
    }
}

final class HangTightMotionTests: XCTestCase {
    func testTextHopsUpAndLandsLikeABallNeverGoingBelowItsPlace() {
        let lifts = stride(from: 0.0, through: 6.0, by: 0.01).map { HangTightMotion.lift(at: $0) }
        XCTAssertGreaterThanOrEqual(lifts.min()!, 0)
        XCTAssertEqual(lifts.max()!, HangTightMotion.hopHeight, accuracy: 0.05)
        XCTAssertEqual(HangTightMotion.lift(at: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(HangTightMotion.lift(at: 1 / HangTightMotion.hopsPerSecond), 0, accuracy: 1e-9, "each hop lands at rest")
    }

    func testTheBounceIsSmallAndGentle() {
        XCTAssertLessThanOrEqual(HangTightMotion.hopHeight, 12)
        XCTAssertLessThanOrEqual(HangTightMotion.hopsPerSecond, 1.5)
    }

    func testSubtitleFollowsTheTitleByABeat() {
        XCTAssertEqual(HangTightMotion.lift(at: HangTightMotion.subtitleDelay / 2, delay: HangTightMotion.subtitleDelay), 0)
        XCTAssertGreaterThan(HangTightMotion.lift(at: 0.2), HangTightMotion.lift(at: 0.2, delay: HangTightMotion.subtitleDelay))
    }

    func testTextPopsInWithASmallOvershoot() {
        XCTAssertEqual(HangTightMotion.entrance(at: 0), 0)
        XCTAssertEqual(HangTightMotion.entrance(at: 3), 1)
        let peak = stride(from: 0.0, through: 1.0, by: 0.01).map { HangTightMotion.entrance(at: $0) }.max()!
        XCTAssertGreaterThan(peak, 1.02)
        XCTAssertLessThan(peak, 1.3)
    }
}

final class TestLayoutTests: XCTestCase {
    func testItMatchesTheDesignAtTheDesignsSize() {
        let layout = TestLayout(size: CGSize(width: 2000, height: 1290))
        XCTAssertEqual(layout.unit, 1.32, accuracy: 0.01)
        XCTAssertEqual(layout.illustrationCenter.y, 587, accuracy: 6)
        XCTAssertEqual(layout.readoutY, 978, accuracy: 6)
        XCTAssertEqual(layout.subtitleY, 1035, accuracy: 6)
        XCTAssertEqual(layout.buttonCenter.y, 1134, accuracy: 6)
        XCTAssertEqual(layout.buttonSize.width, 280, accuracy: 6)
        XCTAssertEqual(layout.hangTightTitleY, 620, accuracy: 6)
    }

    func testReadoutSubtitleAndButtonStackInOrderBelowTheIllustrationAtEverySize() {
        for size in [CGSize(width: 2000, height: 1290), CGSize(width: 1800, height: 1051), CGSize(width: 1100, height: 700), CGSize(width: 900, height: 600)] {
            let layout = TestLayout(size: size)
            let laptopHalfHeight = TestArtwork.laptopSize.height * layout.unit / 2
            XCTAssertLessThan(layout.illustrationCenter.y + laptopHalfHeight, layout.readoutY - layout.percentFont / 2, "\(size)")
            XCTAssertLessThan(layout.readoutY, layout.subtitleY)
            XCTAssertLessThan(layout.subtitleY, layout.buttonCenter.y - layout.buttonSize.height / 2)
            XCTAssertLessThanOrEqual(layout.buttonCenter.y + layout.buttonSize.height / 2, size.height)
        }
    }

    func testTheHingePageFitsInTheWindowWhenTheLidIsLeanedFurthestBack() {
        for size in [CGSize(width: 2000, height: 1290), CGSize(width: 1800, height: 1051), CGSize(width: 1100, height: 700), CGSize(width: 900, height: 600)] {
            let layout = TestLayout(size: size)
            let base = TestArtwork.hingeBaseSize
            let rest = HingeScene.restCenter

            // Where the circle (the lid's pivot) lands on screen, from how the page positions the scene.
            let baseCentreX = size.width / 2 + (base.width / 2 - rest.x) * layout.unit
            let baseCentreY = size.height * 0.433 + (base.height / 2 - rest.y) * layout.unit
            let pivot = CGPoint(x: baseCentreX + (TestArtwork.hingeCircleCenter.x - base.width / 2) * layout.unit,
                                y: baseCentreY + (TestArtwork.hingeCircleCenter.y - base.height / 2) * layout.unit)

            // The lid is about 464 units long. Its direction from the pivot is measured from straight up, positive to
            // the right: -31.5 degrees as drawn in the artwork (leaning left), plus however far it is turned clockwise.
            let length = 464 * layout.unit
            func tip(hinge: Double) -> CGPoint {
                let angle = (-31.5 + TestMotion.lidRotation(hinge: hinge)) * .pi / 180
                return CGPoint(x: pivot.x + length * sin(angle), y: pivot.y - length * cos(angle))
            }

            XCTAssertLessThan(tip(hinge: TestMotion.defaultHinge).x, pivot.x, "leans back at the default")
            XCTAssertGreaterThan(tip(hinge: 40).x, pivot.x, "leans forward, over the keyboard, when nearly closed")
            for hinge in [TestMotion.hingeDrawRange.lowerBound, TestMotion.defaultHinge, TestMotion.hingeDrawRange.upperBound] {
                let end = tip(hinge: hinge)
                XCTAssertGreaterThan(end.x, 0, "lid runs off the left at hinge \(hinge), \(size)")
                XCTAssertLessThan(end.x, size.width, "lid runs off the right at hinge \(hinge), \(size)")
                XCTAssertGreaterThan(end.y, 0, "lid runs off the top at hinge \(hinge), \(size)")
            }
            XCTAssertLessThan(pivot.x + base.width * layout.unit, size.width, "base runs off the right, \(size)")
        }
    }
}
