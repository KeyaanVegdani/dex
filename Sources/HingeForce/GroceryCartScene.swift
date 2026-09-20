import SwiftUI

/// Draws the cart on its diagonal path with speed-line trails whose length follows blow intensity
/// (masked — not uniformly scaled — so stroke angle stays fixed).
struct GroceryCartScene: View {
    let state: GroceryCartSceneState
    let size: CGSize

    var body: some View {
        let cartSide = min(size.width, size.height) * 0.28
        let trailSize = CGSize(width: cartSide * 1.15, height: cartSide * 0.66)
        let start = CGPoint(x: size.width * 0.16, y: size.height * 0.22)
        let end = CGPoint(x: size.width * 0.78, y: size.height * 0.62)
        let t = state.progress
        let center = CGPoint(x: start.x + (end.x - start.x) * t,
                             y: start.y + (end.y - start.y) * t)
        let trailLength = GroceryCart.trailLength(intensity: state.intensity)

        ZStack {
            if trailLength > 0.01 {
                speedTrail(size: trailSize, length: trailLength)
                    // Sit behind the handle (toward top-left of the cart).
                    .position(x: center.x - cartSide * 0.42, y: center.y - cartSide * 0.28)
            }

            Image(nsImage: AppResources.image("cart"))
                .resizable()
                .scaledToFit()
                .frame(width: cartSide, height: cartSide)
                .position(center)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    /// Reveals the speed-lines art from the cart-adjacent (trailing) end only, growing length
    /// toward the top-left without changing stroke width or angle.
    private func speedTrail(size: CGSize, length: Double) -> some View {
        let lines = Image(nsImage: AppResources.image("speed-lines"))
            .resizable()
            .interpolation(.high)
            .frame(width: size.width, height: size.height)

        // White strokes on a dark plate → use as a mask so trails read light grey on white.
        return Color(white: 0.78)
            .frame(width: size.width, height: size.height)
            .mask {
                lines
                    .mask {
                        HStack(spacing: 0) {
                            Color.clear.frame(width: size.width * (1 - length))
                            Color.white.frame(width: size.width * length)
                        }
                    }
            }
            .opacity(0.55 + 0.45 * length)
    }
}
