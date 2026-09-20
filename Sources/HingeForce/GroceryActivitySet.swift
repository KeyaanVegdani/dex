import Foundation

/// Grocery Day activity set — parallel scaffold to the cake story.
///
/// **Steps**
/// 1. `GroceryLessonView` — Push the cart (blow → speed).
/// 2. `GroceryCutLessonView` — Gently squish the tomato (Force Touch).
/// 3. `GroceryPressLessonView` — Toss the tomato in the cart (hinge fold).
/// 4. `GrocerySwipeLessonView` — Swipe to pay (tilt → play swipe video) → Finish → History.
///
/// Keep the `RootView` page chain when replacing step bodies.
enum GroceryActivitySet {
    enum Step: Int, CaseIterable {
        case lesson  // Push the cart
        case cut     // Squish the tomato
        case press   // Toss into cart
        case swipe   // Swipe to pay
    }

    static let displayName = "Grocery Day"
}
