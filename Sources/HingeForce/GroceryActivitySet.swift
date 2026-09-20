import Foundation

/// Grocery Day activity set — parallel scaffold to the cake story.
///
/// **Steps**
/// 1. `GroceryLessonView` — Push the cart (blow → speed).
/// 2. `GroceryCutLessonView` — Gently squish the tomato (Force Touch).
/// 3. `GroceryPressLessonView` — placeholder; swap later.
/// 4. `GroceryWashLessonView` — placeholder; swap later → Log.
///
/// Keep the `RootView` page chain when replacing step bodies.
enum GroceryActivitySet {
    enum Step: Int, CaseIterable {
        case lesson  // Push the cart
        case cut     // Squish the tomato
        case press
        case wash
    }

    static let displayName = "Grocery Day"
}
