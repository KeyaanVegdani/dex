import XCTest
@testable import HingeForce

final class ProgressTrackerTests: XCTestCase {
    func testMilestonesAreTomatoCakeThenNextUp() {
        XCTAssertEqual(ProgressMilestone.allCases.map(\.imageName), ["tomato", "cake", "next-up"])
    }

    func testCardTitlesMatchBakedInArt() {
        XCTAssertEqual(ProgressMilestone.tomato.title, "Grocery Day")
        XCTAssertEqual(ProgressMilestone.cake.title, "It’s Celebratin’ Time")
        XCTAssertEqual(ProgressMilestone.nextUp.title, "Unlock Tomorrow")
    }

    func testAccessibilityLabelsIncludeTitleAndDate() {
        XCTAssertEqual(ProgressMilestone.tomato.accessibilityLabel, "Grocery Day, Sep 19")
        XCTAssertEqual(ProgressMilestone.cake.accessibilityLabel, "It’s Celebratin’ Time, Sep 20")
        XCTAssertEqual(ProgressMilestone.nextUp.accessibilityLabel, "Unlock Tomorrow, Sep 21")
    }
}
