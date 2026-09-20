import XCTest
import SwiftUI
@testable import HingeForce

final class LessonOutroTests: XCTestCase {
    func testNothingHappensWhileTheCandlesAreStillLit() {
        for candle in 0..<3 { XCTAssertEqual(LessonOutro.smokeProgress(candle: candle, elapsed: nil), 0) }
        XCTAssertEqual(LessonOutro.captionOpacity(elapsed: nil), 1)
        XCTAssertEqual(LessonOutro.barCompletion(elapsed: nil), 0)
        XCTAssertEqual(LessonOutro.continueRise(elapsed: nil), 0)
        XCTAssertEqual(LessonOutro.continueOpacity(elapsed: nil), 0)
        XCTAssertFalse(LessonOutro.isContinueEnabled(elapsed: nil))
    }

    func testSmokeIsDrawnInFullAndKeepsGrowingLeftToRight() {
        for candle in 0..<3 {
            XCTAssertEqual(LessonOutro.smokeProgress(candle: candle, elapsed: 0), 0)
            XCTAssertEqual(LessonOutro.smokeProgress(candle: candle, elapsed: 5), 1)
            var previous = 0.0
            for e in stride(from: 0.0, through: 1.5, by: 0.02) {
                let value = LessonOutro.smokeProgress(candle: candle, elapsed: e)
                XCTAssertGreaterThanOrEqual(value, previous, "candle \(candle) went backwards at \(e)")
                previous = value
            }
        }
        XCTAssertGreaterThan(LessonOutro.smokeProgress(candle: 0, elapsed: 0.5),
                             LessonOutro.smokeProgress(candle: 2, elapsed: 0.5))
    }

    func testSmokeStartsOnlyAfterTheFlameIsMostlyGone() {
        // The flame has faded fully by 0.35s + stagger; smoke shouldn't be visibly drawn before that's well under way.
        XCTAssertLessThan(LessonOutro.smokeProgress(candle: 0, elapsed: 0.3), 0.1)
    }

    func testCaptionFadesOutAndBarTurnsGreen() {
        XCTAssertEqual(LessonOutro.captionOpacity(elapsed: 0.3), 0)
        XCTAssertEqual(LessonOutro.captionOpacity(elapsed: 3), 0)
        XCTAssertEqual(LessonOutro.barCompletion(elapsed: 0.6), 1, accuracy: 1e-9)
        XCTAssertEqual(LessonOutro.barCompletion(elapsed: 3), 1, accuracy: 1e-9)
    }

    func testContinuePopsUpAfterTheSmokeHasBeenDrawnAndBecomesPressable() {
        // Smoke is fully drawn for every candle before the button starts to appear.
        for candle in 0..<3 {
            XCTAssertEqual(LessonOutro.smokeProgress(candle: candle, elapsed: LessonOutro.continueStart), 1, accuracy: 0.02)
        }
        XCTAssertEqual(LessonOutro.continueOpacity(elapsed: LessonOutro.continueStart), 0)
        XCTAssertEqual(LessonOutro.continueRise(elapsed: LessonOutro.continueStart), 0)
        XCTAssertEqual(LessonOutro.continueOpacity(elapsed: 3), 1)
        XCTAssertEqual(LessonOutro.continueRise(elapsed: 3), 1)

        XCTAssertFalse(LessonOutro.isContinueEnabled(elapsed: LessonOutro.continueStart))
        XCTAssertTrue(LessonOutro.isContinueEnabled(elapsed: LessonOutro.continueStart + 0.5))
    }

    func testContinuePopsWithASmallOvershootRatherThanJustSliding() {
        let peak = stride(from: LessonOutro.continueStart, through: 2.5, by: 0.01)
            .map { LessonOutro.continueRise(elapsed: $0) }.max()!
        XCTAssertGreaterThan(peak, 1.02)
        XCTAssertLessThan(peak, 1.15)
    }

    func testSmokePathIsDrawnFromTheBottomUp() {
        let rect = CGRect(x: 0, y: 0, width: Illustration.smokeSize.width, height: Illustration.smokeSize.height)
        let full = SmokeWisp().path(in: rect)
        let start = SmokeWisp().trim(from: 0, to: 0.05).path(in: rect).boundingRect
        let partial = SmokeWisp().trim(from: 0, to: 0.4).path(in: rect).boundingRect

        // The path begins at the bottom (36.5 of 40) ...
        XCTAssertEqual(start.midY, 36.5, accuracy: 2)
        // ... and a partly drawn wisp has not reached the top yet, while the full one has.
        XCTAssertGreaterThan(partial.minY, full.boundingRect.minY + 5)
        XCTAssertEqual(partial.maxY, full.boundingRect.maxY, accuracy: 1.5)
        XCTAssertEqual(full.boundingRect.minY, 3, accuracy: 1)
    }
}
