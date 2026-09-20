import SwiftUI

/// Whole / dent / broken tomato layered for the squish lesson.
struct GroceryTomatoScene: View {
    let state: GroceryTomatoSceneState
    let side: CGFloat

    var body: some View {
        ZStack {
            if state.phase == .broken {
                Image(nsImage: AppResources.image("tomato-broken"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: side * 1.08, height: side * 0.85)
            } else {
                Image(nsImage: AppResources.image("tomato-whole"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: side, height: side)
                    .brightness(GroceryTomato.darken(depth: state.depth))

                Image(nsImage: AppResources.image("dent"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: side * 0.28, height: side * 0.32)
                    .opacity(GroceryTomato.dentOpacity(depth: state.depth))
                    // Sit on the body (slightly right of center), matching the dent mockup.
                    .offset(x: side * 0.06, y: side * 0.04)
            }
        }
        .frame(width: side * 1.1, height: side)
    }
}
