import Foundation

/// Rules for the Grocery Day tomato-squish step (Force Touch).
enum GroceryTomato {
    /// Below this peak on release → too soft (bursts).
    static let firmMin = 5.5
    /// At or above this while pressing → too hard (bursts).
    static let hardMax = 8.0
    /// Continue timing after a good squish.
    static let continueStart = 0.3

    static let titleSquish = "Gently squish the tomato"
    static let subtitleSquish = "Tap the tomato with one finger."
    static let titleTooSoft = "Too soft — this tomato’s no good"
    static let titleGood = "That’s a good tomato"
    static let titleGoodEnough = "That’s good enough"
    static let titleTooHard = "Oops, you broke it"
    static let getAnotherTitle = "Get another tomato"

    /// 0...1 press depth from a 1...10 reading.
    static func depth(forReading reading: Double) -> Double {
        min(max((reading - 1) / 9, 0), 1)
    }

    /// Dent visibility grows with press (full by hardMax).
    static func dentOpacity(depth: Double) -> Double {
        let full = Self.depth(forReading: hardMax)
        return min(max(depth / max(full, 0.001), 0), 1)
    }

    /// Dent-only darkening: mild in the firm band, much darker near/at hard.
    static func dentBrightness(depth: Double) -> Double {
        let firm = Self.depth(forReading: firmMin)
        let hard = Self.depth(forReading: hardMax)
        if depth <= firm {
            return -0.12 * (depth / max(firm, 0.001))
        }
        let t = min(max((depth - firm) / max(hard - firm, 0.001), 0), 1)
        return LessonIntro.lerp(-0.12, -0.55, t)
    }

    static func isTooHard(reading: Double) -> Bool {
        reading >= hardMax
    }

    static func isFirm(reading: Double) -> Bool {
        reading >= firmMin && reading < hardMax
    }
}

enum GroceryTomatoPhase: Equatable {
    case squishing
    case tooSoft
    case good
    case tooHard

    var isBurst: Bool {
        self == .tooSoft || self == .tooHard
    }
}
