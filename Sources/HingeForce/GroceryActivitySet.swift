import Foundation

/// Grocery Day activity set — parallel scaffold to the cake story (blow → cut → press → wash).
///
/// **Where to plug new activities later**
/// Replace the body/content of each `Grocery*LessonView` (and its page if needed). Keep the
/// `RootView` page cases (`groceryLesson` → `groceryCut` → `groceryPress` → `groceryWash` → Log)
/// and the `onContinue` / `onFinish` callbacks so navigation stays intact.
///
/// For now each step reuses the cake lesson’s models, scenes, Theme, and PillButton chrome.
enum GroceryActivitySet {
    /// Ordered steps Jane can swap one-by-one.
    enum Step: Int, CaseIterable {
        case lesson  // currently: mic blow-out (cake placeholder)
        case cut     // currently: hinge cut (cake placeholder)
        case press   // currently: trackpad press (cake placeholder)
        case wash    // currently: accelerometer wash (cake placeholder)
    }

    static let displayName = "Grocery Day"
}
