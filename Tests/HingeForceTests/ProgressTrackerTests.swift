import XCTest
@testable import HingeForce

final class ProgressTrackerTests: XCTestCase {
    func testMilestonesAreTomatoCakeThenNextUp() {
        XCTAssertEqual(ProgressMilestone.allCases.map(\.imageName), ["tomato", "cake", "next-up"])
    }

    func testCakeDateIsSeptember20() {
        XCTAssertEqual(ProgressMilestone.cake.dateLabel, "September 20")
    }

    func testTomatoIsDayBeforeCake() {
        XCTAssertEqual(ProgressMilestone.tomato.dateLabel, "September 19")
    }

    func testNextUpUsesUnlockTomorrow() {
        XCTAssertEqual(ProgressMilestone.nextUp.dateLabel, "Unlock tomorrow")
    }
}
