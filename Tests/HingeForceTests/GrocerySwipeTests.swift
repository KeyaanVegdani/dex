import XCTest
@testable import HingeForce

final class GrocerySwipeTests: XCTestCase {
    func testTipAmountIsDistanceFromBaseline() {
        XCTAssertEqual(GrocerySwipe.tipAmount(pitchDegrees: 20, baselinePitch: 5), 15, accuracy: 1e-9)
        XCTAssertEqual(GrocerySwipe.tipAmount(pitchDegrees: -10, baselinePitch: 5), 15, accuracy: 1e-9)
    }

    func testTiltPastThresholdStartsPlayback() {
        XCTAssertFalse(GrocerySwipe.shouldStartPlayback(tipDegrees: 0))
        XCTAssertFalse(GrocerySwipe.shouldStartPlayback(tipDegrees: GrocerySwipe.playTipDegrees - 0.1))
        XCTAssertTrue(GrocerySwipe.shouldStartPlayback(tipDegrees: GrocerySwipe.playTipDegrees))
        XCTAssertTrue(GrocerySwipe.shouldStartPlayback(tipDegrees: 20))
    }

    func testCopyUsesFinishAndTilt() {
        XCTAssertEqual(GrocerySwipe.title, "Swipe to pay")
        XCTAssertTrue(GrocerySwipe.subtitle.lowercased().contains("tilt"))
        XCTAssertEqual(GrocerySwipe.finishTitle, "Finish")
    }

    func testSwipeVideoResourceIsBundled() {
        // Prefer the AVPlayer-ready mp4; webm is also shipped in Resources.
        XCTAssertNotNil(AppResources.swipeVideoURL())
        XCTAssertNotNil(AppResources.bundle.url(forResource: "swipe", withExtension: "webm"))
        XCTAssertNotNil(AppResources.bundle.url(forResource: "swipe", withExtension: "mp4"))
    }
}
