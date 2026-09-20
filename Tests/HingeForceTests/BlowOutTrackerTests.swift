import XCTest
@testable import HingeForce

final class BlowOutTrackerTests: XCTestCase {
    private let dt = 1.0 / 60.0

    private func run(_ tracker: inout BlowOutTracker, reading: Double, seconds: Double) {
        for _ in 0..<Int((seconds / dt).rounded()) { tracker.update(reading: reading, dt: dt) }
    }

    private var hold: Double { BlowOutTracker.holdDuration }

    func testBlowsOutOnceTheBlowHasBeenHeldForTheHoldDuration() {
        var tracker = BlowOutTracker()
        run(&tracker, reading: 10, seconds: hold - 0.1)
        XCTAssertFalse(tracker.isBlownOut)
        run(&tracker, reading: 10, seconds: 0.2)
        XCTAssertTrue(tracker.isBlownOut)
    }

    func testAHardBlowPutsTheCandlesOutInUnderASecond() {
        XCTAssertLessThanOrEqual(BlowOutTracker.holdDuration, 1.0)
        var tracker = BlowOutTracker()
        run(&tracker, reading: BlowOutTracker.threshold, seconds: 1.0)
        XCTAssertTrue(tracker.isBlownOut)
    }

    func testReadingBelowThresholdNeverBlowsOut() {
        var tracker = BlowOutTracker()
        run(&tracker, reading: BlowOutTracker.threshold - 0.5, seconds: 10)
        XCTAssertFalse(tracker.isBlownOut)
        XCTAssertEqual(tracker.progress, 0)
    }

    func testProgressBuildsWhileHolding() {
        var tracker = BlowOutTracker()
        run(&tracker, reading: 10, seconds: hold / 2)
        XCTAssertEqual(tracker.progress, 0.5, accuracy: 0.05)
    }

    func testBriefDipIsForgivenButStoppingIsNot() {
        var tracker = BlowOutTracker()
        run(&tracker, reading: 10, seconds: hold * 0.6)
        run(&tracker, reading: 6, seconds: 0.05)          // brief wobble
        run(&tracker, reading: 10, seconds: hold * 0.6)
        XCTAssertTrue(tracker.isBlownOut)

        var stopped = BlowOutTracker()
        run(&stopped, reading: 10, seconds: hold * 0.6)
        run(&stopped, reading: 1, seconds: hold)          // stops blowing
        XCTAssertEqual(stopped.progress, 0)
        run(&stopped, reading: 10, seconds: hold * 0.6)
        XCTAssertFalse(stopped.isBlownOut)
    }

    func testStaysBlownOut() {
        var tracker = BlowOutTracker()
        run(&tracker, reading: 10, seconds: 2)
        XCTAssertTrue(tracker.isBlownOut)
        run(&tracker, reading: 1, seconds: 5)
        XCTAssertTrue(tracker.isBlownOut)
        tracker.reset()
        XCTAssertFalse(tracker.isBlownOut)
    }
}
