import XCTest
@testable import HingeForce

final class CandleSceneTests: XCTestCase {
    private func state(bend: Double = 0, hold: Double = 0, out: Double? = nil, t: Double = 0) -> CandleSceneState {
        CandleSceneState(time: t, bend: bend, holdProgress: hold, blowOutElapsed: out)
    }

    /// Average angle over a couple of seconds, which cancels out the idle sway.
    private func meanAngle(candle: Int, bend: Double) -> Double {
        let samples = stride(from: 0.0, to: 20.0, by: 0.01).map {
            CandleScene.motion(forCandle: candle, state: state(bend: bend, t: $0)).angle
        }
        return samples.reduce(0, +) / Double(samples.count)
    }

    func testIdleFlamesOnlySwayGently() {
        for candle in 0..<3 {
            for t in stride(from: 0.0, to: 10.0, by: 0.05) {
                let m = CandleScene.motion(forCandle: candle, state: state(t: t))
                XCTAssertLessThan(abs(m.angle), 4, "candle \(candle) t=\(t)")
                XCTAssertEqual(m.opacity, 1)
            }
        }
    }

    func testCandlesDoNotSwayInUnison() {
        let angles = (0..<3).map { CandleScene.motion(forCandle: $0, state: state(t: 0.4)).angle }
        XCTAssertNotEqual(angles[0], angles[1])
        XCTAssertNotEqual(angles[1], angles[2])
    }

    func testFlamesLeanRightMoreAsBlowIncreases() {
        let means = [0.0, 0.25, 0.5, 0.75, 1.0].map { meanAngle(candle: 1, bend: $0) }
        XCTAssertEqual(means[0], 0, accuracy: 0.5)
        XCTAssertEqual(means[4], CandleScene.maxBendDegrees, accuracy: 1)
        for (a, b) in zip(means, means.dropFirst()) { XCTAssertLessThan(a, b) }
    }

    func testFlamesShrinkAsBlowOutApproaches() {
        let calm = CandleScene.motion(forCandle: 0, state: state(bend: 1, hold: 0, t: 5))
        let strained = CandleScene.motion(forCandle: 0, state: state(bend: 1, hold: 1, t: 5))
        XCTAssertLessThan(strained.scaleY, calm.scaleY)
    }

    func testBlowOutFadesEveryFlameAndSweepsLeftToRight() {
        let full = { (candle: Int, elapsed: Double) in
            CandleScene.motion(forCandle: candle, state: self.state(bend: 1, hold: 1, out: elapsed)).opacity
        }
        // Mid-way, the left flame is further gone than the right.
        XCTAssertLessThan(full(0, 0.2), full(2, 0.2))
        // Everything is out well before the smoke finishes.
        for candle in 0..<3 { XCTAssertEqual(full(candle, 0.8), 0, accuracy: 1e-9) }
        // And nothing is dimmed before the blow-out starts.
        XCTAssertEqual(CandleScene.motion(forCandle: 0, state: state(bend: 1, hold: 1)).opacity, 1)
    }
}
