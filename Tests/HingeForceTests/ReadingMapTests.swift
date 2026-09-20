import XCTest
@testable import HingeForce

final class ReadingMapTests: XCTestCase {
    func testHingeBelowFortyIsZero() {
        for angle in [0.0, 10, 39.9, 40] {
            XCTAssertEqual(ReadingMap.hinge(angle: angle), 0, accuracy: 1e-9, "angle \(angle)")
        }
    }

    func testHingeAnchors() {
        XCTAssertEqual(ReadingMap.hinge(angle: 100), 50, accuracy: 1e-9)
        XCTAssertEqual(ReadingMap.hinge(angle: 130), 100, accuracy: 1e-9)
    }

    func testHingeInterpolatesLinearlyBetweenAnchors() {
        XCTAssertEqual(ReadingMap.hinge(angle: 70), 25, accuracy: 1e-9)
        XCTAssertEqual(ReadingMap.hinge(angle: 115), 75, accuracy: 1e-9)
        XCTAssertEqual(ReadingMap.hinge(angle: 111), 50 + 11.0 / 30 * 50, accuracy: 1e-9)
    }

    func testHingeAboveOneThirtyStaysAtHundred() {
        for angle in [130.5, 180, 360] {
            XCTAssertEqual(ReadingMap.hinge(angle: angle), 100, accuracy: 1e-9, "angle \(angle)")
        }
    }

    func testPressureMapsToOneThroughTen() {
        XCTAssertEqual(ReadingMap.pressure(0), 1, accuracy: 1e-9)
        XCTAssertEqual(ReadingMap.pressure(0.5), 5.5, accuracy: 1e-9)
        XCTAssertEqual(ReadingMap.pressure(1), 10, accuracy: 1e-9)
    }

    func testPressureIsClamped() {
        XCTAssertEqual(ReadingMap.pressure(-0.3), 1, accuracy: 1e-9)
        XCTAssertEqual(ReadingMap.pressure(2), 10, accuracy: 1e-9)
    }
}
