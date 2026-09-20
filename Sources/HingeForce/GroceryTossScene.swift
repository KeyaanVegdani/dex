import SwiftUI

/// Cart back → tomato → cart front. Tomato arcs from above the basket into the floor.
struct GroceryTossScene: View {
    let state: GroceryTossSceneState
    let size: CGSize

    var body: some View {
        let cartSide = min(size.width * 0.42, size.height * 0.48, 420)
        let tomatoSide = cartSide * 0.38
        let cartOrigin = CGPoint(x: size.width / 2, y: size.height * 0.48)
        let t = state.progress
        let tomatoCenter = tomatoPosition(progress: t, cartCenter: cartOrigin, cartSide: cartSide)
        // Shrink slightly as it settles into the basket.
        let tomatoScale = GroceryToss.lerp(1.0, 0.78, t)

        ZStack {
            Image(nsImage: AppResources.image("cart-back"))
                .resizable()
                .scaledToFit()
                .frame(width: cartSide, height: cartSide)
                .position(cartOrigin)

            Image(nsImage: AppResources.image("tomato-whole"))
                .resizable()
                .scaledToFit()
                .frame(width: tomatoSide * tomatoScale, height: tomatoSide * tomatoScale)
                .position(tomatoCenter)
                .zIndex(1)

            Image(nsImage: AppResources.image("cart-front"))
                .resizable()
                .scaledToFit()
                .frame(width: cartSide, height: cartSide)
                .position(cartOrigin)
                .zIndex(2)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    /// Start: floating above basket center. End: bottom-right of basket floor (through front grid).
    private func tomatoPosition(progress t: Double, cartCenter: CGPoint, cartSide: CGFloat) -> CGPoint {
        let start = CGPoint(x: cartCenter.x, y: cartCenter.y - cartSide * 0.42)
        let end = CGPoint(x: cartCenter.x + cartSide * 0.12, y: cartCenter.y + cartSide * 0.06)
        // Ease downward so early fold moves it into the mouth, then settles.
        let easeY = t * t
        return CGPoint(
            x: GroceryToss.lerp(start.x, end.x, t),
            y: GroceryToss.lerp(start.y, end.y, easeY)
        )
    }
}
