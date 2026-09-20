import SwiftUI

/// Whole / dent / broken tomato. Dent intensifies with pressure; the tomato body color stays fixed.
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

                Image(nsImage: AppResources.image("dent"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: side * 0.28, height: side * 0.32)
                    .opacity(GroceryTomato.dentOpacity(depth: state.depth))
                    .brightness(GroceryTomato.dentBrightness(depth: state.depth))
                    .offset(x: side * 0.06, y: side * 0.04)
            }
        }
        .frame(width: side * 1.1, height: side)
    }
}
