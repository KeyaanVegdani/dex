import XCTest
@testable import HingeForce

final class PageTransitionTests: XCTestCase {
    func testOutgoingArtworkStartsNormalAndStretchesToThePeak() {
        XCTAssertEqual(PageTransition.outgoingStretch(at: 0), 1)
        XCTAssertEqual(PageTransition.outgoingStretch(at: PageTransition.outDuration), PageTransition.peakStretch, accuracy: 1e-9)
        XCTAssertEqual(PageTransition.outgoingStretch(at: 5), PageTransition.peakStretch, accuracy: 1e-9)
    }

    func testIncomingArtworkStartsAtThePeakAndSettlesToNormal() {
        XCTAssertEqual(PageTransition.incomingStretch(at: 0), PageTransition.peakStretch, accuracy: 1e-9)
        XCTAssertEqual(PageTransition.incomingStretch(at: PageTransition.inDuration), 1, accuracy: 1e-9)
        XCTAssertEqual(PageTransition.incomingStretch(at: 5), 1, accuracy: 1e-9)
    }

    func testTheSwapIsSeamlessBecauseBothSidesAreEquallyStretched() {
        XCTAssertEqual(PageTransition.outgoingStretch(at: PageTransition.outDuration),
                       PageTransition.incomingStretch(at: 0), accuracy: 1e-9)
    }

    func testOutgoingEasesInAndIncomingEasesOut() {
        let peak = PageTransition.peakStretch
        // Ease-in: a quarter of the way through the time, well under a quarter of the way there.
        let outQuarter = (PageTransition.outgoingStretch(at: PageTransition.outDuration / 4) - 1) / (peak - 1)
        XCTAssertLessThan(outQuarter, 0.1)
        // Ease-out: a quarter of the way through the time, well over a quarter of the way back.
        let inQuarter = (peak - PageTransition.incomingStretch(at: PageTransition.inDuration / 4)) / (peak - 1)
        XCTAssertGreaterThan(inQuarter, 0.5)
    }

    func testStretchOnlyEverMovesOneWayEachSideOfTheSwap() {
        var previous = PageTransition.outgoingStretch(at: 0)
        for t in stride(from: 0.0, through: PageTransition.outDuration, by: 0.005) {
            let value = PageTransition.outgoingStretch(at: t)
            XCTAssertGreaterThanOrEqual(value, previous - 1e-12)
            previous = value
        }
        previous = PageTransition.incomingStretch(at: 0)
        for t in stride(from: 0.0, through: PageTransition.inDuration, by: 0.005) {
            let value = PageTransition.incomingStretch(at: t)
            XCTAssertLessThanOrEqual(value, previous + 1e-12)
            previous = value
        }
    }

    func testOutgoingCaptionAndButtonFadeQuicklyAtTheStart() {
        XCTAssertEqual(PageTransition.outgoingChromeOpacity(at: 0), 1)
        XCTAssertEqual(PageTransition.outgoingChromeOpacity(at: PageTransition.chromeFadeDuration), 0, accuracy: 1e-9)
        XCTAssertLessThan(PageTransition.chromeFadeDuration, PageTransition.outDuration)
    }

    func testTheWholeTransitionIsQuick() {
        XCTAssertLessThanOrEqual(PageTransition.outDuration + PageTransition.inDuration, 0.7)
    }

    func testTheStretchIsSubtle() {
        XCTAssertEqual(PageTransition.peakStretch, 1.06, accuracy: 1e-9)
        for t in stride(from: 0.0, through: PageTransition.outDuration, by: 0.01) {
            XCTAssertLessThanOrEqual(PageTransition.outgoingStretch(at: t), 1.06 + 1e-9)
        }
    }
}

final class CutLineThicknessTests: XCTestCase {
    func testDottedLineStartsAtTheDesignedWidthAndGrowsWhileHeld() {
        XCTAssertEqual(CutScene.lineWidth(alignment: 0), 4, accuracy: 1e-9)
        var previous = CutScene.lineWidth(alignment: 0)
        for a in stride(from: 0.05, through: 1.0, by: 0.05) {
            let width = CutScene.lineWidth(alignment: a)
            XCTAssertGreaterThan(width, previous)
            previous = width
        }
        XCTAssertEqual(CutScene.lineWidth(alignment: 1), 4 * CutScene.maxLineWidthFactor, accuracy: 1e-9)
    }

    func testThickeningStaysInStepWithTheLineTurningWhite() {
        // Both are driven by the same 0...1 hold progress, so they finish together.
        XCTAssertEqual(CutScene.lineWidth(alignment: 2), CutScene.lineWidth(alignment: 1))
        XCTAssertEqual(CutScene.lineWidth(alignment: -1), CutScene.lineWidth(alignment: 0))
    }

    func testDashesSwellUntilTheyNearlyTouchButDoNotJoin() {
        // A dash with round caps is as long as its length plus the line's width.
        let visibleGap = CutScene.dashPeriod - CutScene.dashLength - CutScene.lineWidth(alignment: 1)
        XCTAssertGreaterThan(visibleGap, 0)
        XCTAssertLessThan(visibleGap, 5)
    }

    func testDashesMatchTheReferenceAtRest() {
        // Roughly 10 units long including caps, with about 8 units between them.
        XCTAssertEqual(CutScene.dashLength + CutScene.lineWidth(alignment: 0), 10, accuracy: 0.5)
        XCTAssertEqual(CutScene.dashPeriod - CutScene.dashLength - CutScene.lineWidth(alignment: 0), 8, accuracy: 0.5)
    }
}
