import XCTest
@testable import HingeForce

final class GroceryTomatoTests: XCTestCase {
    func testBandsAreOrdered() {
        XCTAssertLessThan(GroceryTomato.firmMin, GroceryTomato.hardMax)
        XCTAssertTrue(GroceryTomato.isFirm(reading: 6.5))
        XCTAssertFalse(GroceryTomato.isFirm(reading: 4.0))
        XCTAssertTrue(GroceryTomato.isTooHard(reading: GroceryTomato.hardMax))
        XCTAssertFalse(GroceryTomato.isTooHard(reading: GroceryTomato.firmMin))
    }

    func testDentIntensifiesWithoutRelyingOnBodyDarken() {
        XCTAssertGreaterThan(GroceryTomato.dentOpacity(depth: 0.7), GroceryTomato.dentOpacity(depth: 0.2))
        XCTAssertLessThan(GroceryTomato.dentBrightness(depth: 0.9), GroceryTomato.dentBrightness(depth: 0.3))
        let firmDepth = GroceryTomato.depth(forReading: GroceryTomato.firmMin)
        let hardDepth = GroceryTomato.depth(forReading: GroceryTomato.hardMax)
        XCTAssertGreaterThan(GroceryTomato.dentBrightness(depth: firmDepth),
                             GroceryTomato.dentBrightness(depth: hardDepth))
    }

    func testCopyStrings() {
        XCTAssertEqual(GroceryTomato.getAnotherTitle, "Get another tomato")
        XCTAssertEqual(GroceryTomato.titleTooHard, "Oops, you broke it")
        XCTAssertTrue(GroceryTomato.titleTooSoft.lowercased().contains("no good"))
        XCTAssertTrue(GroceryTomato.titleGood.lowercased().contains("good"))
        XCTAssertTrue(GroceryTomato.titleGoodEnough.lowercased().contains("good enough"))
    }

    func testSoftReplacementOnlyOnceThenGoodEnough() {
        XCTAssertEqual(GroceryTomatoRetry.softOutcome(alreadyReplacedOnce: false), .tooSoft)
        XCTAssertEqual(GroceryTomatoRetry.softOutcome(alreadyReplacedOnce: true), .good)

        XCTAssertTrue(GroceryTomatoRetry.shouldOfferGetAnother(phase: .tooSoft, alreadyReplacedOnce: false))
        XCTAssertFalse(GroceryTomatoRetry.shouldOfferGetAnother(phase: .tooSoft, alreadyReplacedOnce: true))
        XCTAssertTrue(GroceryTomatoRetry.shouldOfferGetAnother(phase: .tooHard, alreadyReplacedOnce: true))
        XCTAssertTrue(GroceryTomatoRetry.shouldOfferGetAnother(phase: .tooHard, alreadyReplacedOnce: false))
        XCTAssertFalse(GroceryTomatoRetry.shouldOfferGetAnother(phase: .good, alreadyReplacedOnce: false))
    }
}
