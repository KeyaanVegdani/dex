import Foundation

/// Pure helpers for the Grocery Day “Swipe to pay” MacBook-tilt + video step.
enum GrocerySwipe {
    /// Tip past the resting baseline that starts the swipe video.
    static let playTipDegrees = 8.0
    static let continueStart = 0.28
    static let finishTitle = "Finish"

    static let title = "Swipe to pay"
    static let subtitle = "Tilt your MacBook down."

    /// Degrees tipped away from the pose captured when the step started.
    static func tipAmount(pitchDegrees: Double, baselinePitch: Double) -> Double {
        abs(pitchDegrees - baselinePitch)
    }

    /// Whether tip is far enough to start playing the swipe video.
    static func shouldStartPlayback(tipDegrees: Double) -> Bool {
        tipDegrees >= playTipDegrees
    }
}
