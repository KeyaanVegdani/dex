import XCTest
@testable import HingeForce

final class LessonIntroTests: XCTestCase {
    /// Every animated value of the entrance at time `t`, each scaled to roughly 0...1.
    private func snapshot(at t: Double) -> [Double] {
        let c = LessonIntro.cake(at: t)
        return [c.groupScale, c.groupOpacity, c.bodyLift / 220, c.bodyTilt / 14]
            + c.sticks.flatMap { [$0.lift / 90, $0.angle / 16, $0.scale, $0.opacity] }
            + c.flameScale
            + [LessonIntro.barExpansion(at: t), LessonIntro.textReveal(at: t)]
    }

    func testStartsSmallAndSeparatedThenSettlesIntoTheFinishedCake() {
        let start = LessonIntro.cake(at: 0)
        XCTAssertLessThan(start.groupScale, 0.3)
        XCTAssertEqual(start.groupOpacity, 0)
        XCTAssertGreaterThan(start.bodyLift, 150)
        XCTAssertEqual(start.sticks.map(\.opacity), [0, 0, 0])
        XCTAssertEqual(start.flameScale, [0, 0, 0])

        let end = LessonIntro.cake(at: LessonIntro.duration)
        XCTAssertEqual(end.groupScale, 1)
        XCTAssertEqual(end.groupOpacity, 1)
        XCTAssertEqual(end.bodyLift, 0)
        XCTAssertEqual(end.bodyTilt, 0)
        for stick in end.sticks {
            XCTAssertEqual(stick.lift, 0)
            XCTAssertEqual(stick.angle, 0)
            XCTAssertEqual(stick.scale, 1)
            XCTAssertEqual(stick.opacity, 1)
        }
        XCTAssertEqual(end.flameScale, [1, 1, 1])
    }

    func testSomethingIsAlwaysMovingUntilTheEnd() {
        // No beat where every part stands still before the animation is over.
        var previous = snapshot(at: 0)
        var t = 0.01
        while t < LessonIntro.duration - 0.1 {
            let current = snapshot(at: t)
            let movement = zip(current, previous).map { abs($0 - $1) }.reduce(0, +)
            XCTAssertGreaterThan(movement, 0.002, "stalled at t=\(t)")
            previous = current
            t += 0.01
        }
    }

    func testCandlesArriveWhileTheCakeIsMidwayThroughScalingUp() {
        // The first moment any candle is visible.
        let t = stride(from: 0.0, to: 1.0, by: 0.005).first { LessonIntro.cake(at: $0).sticks[0].opacity > 0 }!
        let scale = LessonIntro.cake(at: t).groupScale
        XCTAssertGreaterThan(scale, 0.5)
        XCTAssertLessThan(scale, 0.75)
        // The cake body is still in the air: the parts overlap rather than taking turns.
        XCTAssertGreaterThan(LessonIntro.cake(at: t).bodyLift, 50)
    }

    func testFlamesLightWhileCandlesAreStillSettling() {
        let t = stride(from: 0.0, to: 1.2, by: 0.005).first { LessonIntro.cake(at: $0).flameScale[0] > 0 }!
        let cake = LessonIntro.cake(at: t)
        XCTAssertGreaterThan(cake.sticks[2].lift, 5)       // still dropping in, so the parts overlap
        XCTAssertLessThan(cake.sticks[0].lift, 15)         // but not lit on candles that are still high up
    }

    func testCandlesHoverSplayedOutwardAndStraightenAsTheyFall() {
        let early = LessonIntro.cake(at: 0.3).sticks
        XCTAssertLessThan(early[0].angle, -8)              // left leans left
        XCTAssertEqual(early[1].angle, 0, accuracy: 1e-9)
        XCTAssertGreaterThan(early[2].angle, 8)            // right leans right

        let late = LessonIntro.cake(at: 0.9).sticks
        for side in [0, 2] { XCTAssertLessThan(abs(late[side].angle), abs(early[side].angle)) }
    }

    func testBodyTiltsCounterClockwiseAndLevelsOutAsItLands() {
        XCTAssertLessThan(LessonIntro.cake(at: 0.2).bodyTilt, -6)
        XCTAssertEqual(LessonIntro.cake(at: 1.0).bodyTilt, 0, accuracy: 0.05)
    }

    func testMotionStaysSmoothWithOnlyASmallOvershoot() {
        var t = 0.0
        while t <= LessonIntro.duration {
            let c = LessonIntro.cake(at: t)
            XCTAssertLessThan(c.groupScale, 1.02, "t=\(t)")
            XCTAssertGreaterThan(c.bodyLift, -4, "body sank into the plate at t=\(t)")
            for stick in c.sticks { XCTAssertGreaterThan(stick.lift, -3, "t=\(t)") }
            for flame in c.flameScale { XCTAssertLessThan(flame, 1.2, "t=\(t)") }
            t += 0.01
        }
    }

    func testBarExpandsAndCaptionRevealsQuickly() {
        XCTAssertEqual(LessonIntro.barExpansion(at: 0), 0)
        XCTAssertEqual(LessonIntro.barExpansion(at: 1), 1)
        XCTAssertEqual(LessonIntro.textReveal(at: 0.3), 0)
        XCTAssertEqual(LessonIntro.textReveal(at: 1.0), 1, accuracy: 1e-9)
        // Caption starts once the cake is well under way, and the slide-up takes under half a second.
        XCTAssertGreaterThan(LessonIntro.cake(at: 0.4).groupScale, 0.8)
        XCTAssertGreaterThan(LessonIntro.textReveal(at: 0.4 + 0.5), 0.99)
    }

    func testSpringHitsItsEndpointsExactlyAndNeverJumps() {
        XCTAssertEqual(LessonIntro.spring(-1, start: 0, duration: 1), 0)
        XCTAssertEqual(LessonIntro.spring(0, start: 0, duration: 1), 0)
        XCTAssertEqual(LessonIntro.spring(1, start: 0, duration: 1), 1)
        XCTAssertEqual(LessonIntro.spring(9, start: 0, duration: 1), 1)

        var previous = 0.0
        var t = 0.0
        while t <= 1.0 {
            let value = LessonIntro.spring(t, start: 0, duration: 1)
            XCTAssertLessThan(abs(value - previous), 0.06, "jump at t=\(t)")
            previous = value
            t += 0.005
        }
    }
}
