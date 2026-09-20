import XCTest
@testable import HingeForce

final class HomeMotionTests: XCTestCase {
    // MARK: Load animation

    func testEverythingIsInPlaceByTheEndOfTheIntro() {
        let t = HomeMotion.introDuration
        XCTAssertEqual(HomeMotion.burstOpacity(at: t), 1, accuracy: 1e-9)
        XCTAssertEqual(HomeMotion.titleOpacity(at: t), 1, accuracy: 1e-9)
        XCTAssertEqual(HomeMotion.bookOpacity(at: t), 1, accuracy: 1e-9)
        XCTAssertEqual(HomeMotion.bookSlide(at: t), 0, accuracy: 1e-9)
        XCTAssertEqual(HomeMotion.cakeScale(at: t), 1, accuracy: 1e-9)
        XCTAssertEqual(HomeMotion.chromeOpacity(at: t), 1, accuracy: 1e-9)
    }

    func testNothingIsShownAtTheVeryStartExceptTheBackgroundStartingToAppear() {
        XCTAssertEqual(HomeMotion.burstOpacity(at: 0), 0)
        XCTAssertEqual(HomeMotion.titleOpacity(at: 0), 0)
        XCTAssertEqual(HomeMotion.bookOpacity(at: 0), 0)
        XCTAssertEqual(HomeMotion.cakeScale(at: 0), 0)
        XCTAssertEqual(HomeMotion.chromeOpacity(at: 0), 0)
    }

    func testBookFadesAndSlidesInFromBelow() {
        XCTAssertEqual(HomeMotion.bookSlide(at: 0.25), 1, accuracy: 1e-9, "starts fully below its place")
        XCTAssertGreaterThan(HomeMotion.bookSlideDistance, 0)
        var previousSlide = 2.0, previousOpacity = -1.0
        for t in stride(from: 0.0, through: 1.2, by: 0.02) {
            let slide = HomeMotion.bookSlide(at: t), opacity = HomeMotion.bookOpacity(at: t)
            XCTAssertLessThanOrEqual(slide, previousSlide + 1e-12, "only ever moves up, t=\(t)")
            XCTAssertGreaterThanOrEqual(opacity, previousOpacity - 1e-12, "only ever fades in, t=\(t)")
            previousSlide = slide; previousOpacity = opacity
        }
        XCTAssertGreaterThan(HomeMotion.bookOpacity(at: 0.4), 0)
        XCTAssertLessThan(HomeMotion.bookOpacity(at: 0.4), 1, "still fading part way through")
    }

    func testCakeGrowsInWithAnOvershoot() {
        let scales = stride(from: 0.0, through: 2.0, by: 0.01).map { HomeMotion.cakeScale(at: $0) }
        XCTAssertGreaterThan(scales.max()!, 1.05, "a visible overshoot")
        XCTAssertLessThan(scales.max()!, 1.25, "but only a bit")
        XCTAssertGreaterThanOrEqual(scales.min()!, 0)
        XCTAssertEqual(scales.last!, 1, accuracy: 1e-9)
    }

    func testTheOrderOfTheLoadAnimation() {
        let bookVisible = stride(from: 0.0, through: 2, by: 0.01).first { HomeMotion.bookOpacity(at: $0) > 0 }!
        let burstVisible = stride(from: 0.0, through: 2, by: 0.01).first { HomeMotion.burstOpacity(at: $0) > 0 }!
        let cakeStarts = stride(from: 0.0, through: 2, by: 0.01).first { HomeMotion.cakeScale(at: $0) > 0 }!
        let chromeStarts = stride(from: 0.0, through: 2.5, by: 0.01).first { HomeMotion.chromeOpacity(at: $0) > 0 }!
        let cakeFirstFull = stride(from: 0.0, through: 2, by: 0.01).first { HomeMotion.cakeScale(at: $0) >= 1 }!

        XCTAssertLessThan(burstVisible, bookVisible, "background before the book")
        XCTAssertGreaterThanOrEqual(cakeStarts, bookVisible, "the cake grows once the book is arriving")
        XCTAssertEqual(HomeMotion.bookOpacity(at: cakeStarts), 1, accuracy: 1e-9, "and once the book is fully visible")
        XCTAssertGreaterThan(chromeStarts, cakeFirstFull, "navigation and button come in after the rest has spawned")
    }

    func testChromeFadesInQuicklyAndAllTogether() {
        XCTAssertLessThan(HomeMotion.introDuration - 1.6, 0.6)
        XCTAssertEqual(HomeMotion.chromeOpacity(at: 1.8), 0.5, accuracy: 0.01)
    }

    // MARK: Sway

    func testSwayStartsAtRestAndBothCentresPassThroughZeroTogether() {
        XCTAssertEqual(HomeMotion.burstAngle(activeTime: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(HomeMotion.bookAngle(activeTime: 0), 0, accuracy: 1e-9)
        let half = HomeMotion.swingPeriod / 2
        XCTAssertEqual(HomeMotion.burstAngle(activeTime: half), 0, accuracy: 1e-9)
        XCTAssertEqual(HomeMotion.bookAngle(activeTime: half), 0, accuracy: 1e-9)
    }

    func testBurstAndBookAlwaysLeanOppositeWays() {
        for t in stride(from: 0.0, through: 20, by: 0.05) {
            let burst = HomeMotion.burstAngle(activeTime: t), book = HomeMotion.bookAngle(activeTime: t)
            XCTAssertLessThanOrEqual(burst * book, 1e-12, "t=\(t)")
        }
        let quarter = HomeMotion.swingPeriod / 4
        XCTAssertGreaterThan(HomeMotion.burstAngle(activeTime: quarter), 0)
        XCTAssertLessThan(HomeMotion.bookAngle(activeTime: quarter), 0)
    }

    func testSwayIsSubtleAndRepeats() {
        XCTAssertLessThanOrEqual(HomeMotion.burstSwing, 3)
        XCTAssertLessThanOrEqual(HomeMotion.bookSwing, HomeMotion.burstSwing, "the book moves more gently")
        for t in stride(from: 0.0, through: 30, by: 0.1) {
            XCTAssertLessThanOrEqual(abs(HomeMotion.burstAngle(activeTime: t)), HomeMotion.burstSwing + 1e-9)
            XCTAssertLessThanOrEqual(abs(HomeMotion.bookAngle(activeTime: t)), HomeMotion.bookSwing + 1e-9)
        }
        XCTAssertEqual(HomeMotion.burstAngle(activeTime: 1.3), HomeMotion.burstAngle(activeTime: 1.3 + HomeMotion.swingPeriod), accuracy: 1e-9)
    }

    // MARK: Hover pauses the sway

    func testHoverPausesTheSwayButNotTheLoadAnimation() {
        var clock = HomeClock()
        for _ in 0..<60 { clock.advance(by: 1.0 / 60, paused: false) }
        let swayBefore = HomeMotion.burstAngle(activeTime: clock.activeTime)
        XCTAssertEqual(clock.activeTime, 1, accuracy: 1e-9)

        for _ in 0..<120 { clock.advance(by: 1.0 / 60, paused: true) }
        XCTAssertEqual(clock.activeTime, 1, accuracy: 1e-9, "the sway stood still while hovering")
        XCTAssertEqual(HomeMotion.burstAngle(activeTime: clock.activeTime), swayBefore, accuracy: 1e-12)
        XCTAssertEqual(clock.elapsed, 3, accuracy: 1e-9, "but real time kept running")
    }

    func testSwayResumesFromWhereItStoppedWithoutAJump() {
        var clock = HomeClock()
        for _ in 0..<45 { clock.advance(by: 1.0 / 60, paused: false) }
        let stopped = HomeMotion.bookAngle(activeTime: clock.activeTime)
        for _ in 0..<300 { clock.advance(by: 1.0 / 60, paused: true) }
        clock.advance(by: 1.0 / 60, paused: false)
        XCTAssertEqual(HomeMotion.bookAngle(activeTime: clock.activeTime), stopped, accuracy: 0.05)
    }

    func testHoverGrowsTheBookASmallAmountAndLiftsIt() {
        XCTAssertGreaterThan(HomeMotion.hoverScale, 1.02)
        XCTAssertLessThan(HomeMotion.hoverScale, 1.1)
        XCTAssertGreaterThan(HomeMotion.hoverLift, 0)
    }
}

final class HomeLayoutTests: XCTestCase {
    private let sizes = [CGSize(width: 2000, height: 1300), CGSize(width: 1800, height: 1051),
                         CGSize(width: 1440, height: 900), CGSize(width: 1100, height: 700), CGSize(width: 900, height: 600)]

    func testItMatchesTheDesignAtTheDesignsSize() {
        let layout = HomeLayout(size: CGSize(width: 2000, height: 1300))
        XCTAssertEqual(layout.bookRect.width, 590, accuracy: 20, "the book is about 590 px wide in the 2000 px design")
        XCTAssertEqual(layout.bookCenter.x, 1000, accuracy: 1)
        XCTAssertEqual(layout.buttonSize.width, 353, accuracy: 10)
        XCTAssertEqual(layout.buttonCenter.y, 1162, accuracy: 6)
        XCTAssertEqual(layout.titleCenterY, 280, accuracy: 6)
    }

    func testTitleSitsAboveTheBookAndTheBookAboveTheButtonAtEverySize() {
        for size in sizes {
            let layout = HomeLayout(size: size)
            let titleBottom = layout.titleCenterY + layout.titleFont * 1.15
            XCTAssertLessThan(titleBottom, layout.bookRect.minY, "title overlaps the book at \(size)")
            XCTAssertLessThan(layout.bookRect.maxY, layout.buttonCenter.y - layout.buttonSize.height / 2, "book overlaps the button at \(size)")
        }
    }

    func testEverythingStaysInsideTheWindowAndTheBookIsCentred() {
        for size in sizes {
            let layout = HomeLayout(size: size)
            XCTAssertEqual(layout.bookRect.midX, size.width / 2, accuracy: 0.5)
            XCTAssertGreaterThanOrEqual(layout.bookRect.minX, 0)
            XCTAssertLessThanOrEqual(layout.bookRect.maxX, size.width)
            XCTAssertGreaterThanOrEqual(layout.bookRect.minY, 0)
            XCTAssertLessThanOrEqual(layout.buttonCenter.y + layout.buttonSize.height / 2, size.height)
        }
    }

    func testBurstIsCentredBehindTheBookAndBiggerThanIt() {
        for size in sizes {
            let layout = HomeLayout(size: size)
            let burstWidth = HomeArtwork.burstSize.width * layout.unit
            XCTAssertEqual(layout.burstOrigin.x + burstWidth / 2, size.width / 2, accuracy: 0.03 * size.width)
            XCTAssertLessThan(layout.burstOrigin.x, layout.bookRect.minX)
            XCTAssertLessThan(layout.burstOrigin.y, layout.bookRect.minY)
        }
    }

    func testArtworkScalesDownWithASmallerWindow() {
        let large = HomeLayout(size: CGSize(width: 2000, height: 1300)).unit
        let small = HomeLayout(size: CGSize(width: 900, height: 600)).unit
        XCTAssertLessThan(small, large)
        XCTAssertGreaterThan(small, 0)
    }

    func testArtworkGeometryMatchesTheSourceFiles() {
        XCTAssertEqual(HomeArtwork.bookSize, CGSize(width: 451, height: 449))
        XCTAssertEqual(HomeArtwork.burstSize, CGSize(width: 825, height: 728))
        XCTAssertEqual(HomeArtwork.logoSize, CGSize(width: 40, height: 36))
        XCTAssertGreaterThan(HomeArtwork.cakeCenter.x, 100)
        XCTAssertLessThan(HomeArtwork.cakeCenter.x, HomeArtwork.bookSize.width - 100)
    }
}
