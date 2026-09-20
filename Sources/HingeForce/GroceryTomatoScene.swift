import SwiftUI

/// Whole / dent / broken tomato. Dent follows the press point and darkens with pressure;
/// the tomato body color stays fixed.
struct GroceryTomatoScene: View {
    let state: GroceryTomatoSceneState
    let side: CGFloat

    var body: some View {
        ZStack {
            if state.phase.isBurst {
                Image(nsImage: AppResources.image("tomato-broken"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: side * 1.08, height: side * 0.85)
            } else {
                Image(nsImage: AppResources.image("tomato-whole"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: side, height: side)

                if state.depth > 0.02, let norm = state.dentNorm {
                    Image(nsImage: AppResources.image("dent"))
                        .resizable()
                        .scaledToFit()
                        .frame(width: dentSize.width, height: dentSize.height)
                        .opacity(GroceryTomato.dentOpacity(depth: state.depth))
                        .brightness(GroceryTomato.dentBrightness(depth: state.depth))
                        .position(clampedDentCenter(norm: norm))
                }
            }
        }
        .frame(width: side, height: side)
    }

    private var dentSize: CGSize {
        CGSize(width: side * 0.28, height: side * 0.32)
    }

    /// Map unit press point into the tomato frame, inset so the dent stays inside the body.
    private func clampedDentCenter(norm: CGPoint) -> CGPoint {
        let insetX = dentSize.width * 0.55
        let insetY = dentSize.height * 0.55
        let minX = insetX
        let maxX = side - insetX
        let minY = insetY + side * 0.08 // keep out of the stem a bit
        let maxY = side - insetY
        let x = minX + (maxX - minX) * norm.x
        let y = minY + (maxY - minY) * norm.y
        return CGPoint(x: x, y: y)
    }
}
