import SwiftUI

/// Reader back → credit card → slot front. Card slides on a fixed 30° path.
struct GrocerySwipeScene: View {
    let state: GrocerySwipeSceneState
    let size: CGSize
    let force: TrackpadForce

    var body: some View {
        let readerSize = GrocerySwipe.readerSize(for: size)
        let readerCenter = GrocerySwipe.readerCenter(for: size)
        let cardWidth = readerSize.width * 0.30
        let cardHeight = cardWidth * (322.0 / 236.0)
        let cardCenter = GrocerySwipe.cardCenter(progress: state.progress,
                                                 readerCenter: readerCenter,
                                                 readerSize: readerSize)
        let arrowOpacity = GrocerySwipe.arrowOpacity(progress: state.progress)
        let showThankYou = state.isComplete
        let arrowLocal = GrocerySwipe.arrowEndpointsInReaderFrame(readerSize: readerSize)

        ZStack {
            if !showThankYou {
                SwipePathArrow(from: arrowLocal.0, to: arrowLocal.1)
                    .frame(width: readerSize.width, height: readerSize.height)
                    .position(readerCenter)
                    .opacity(arrowOpacity)
                    .allowsHitTesting(false)
            }

            if showThankYou {
                Image(nsImage: AppResources.image("reader-thank-you"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: readerSize.width, height: readerSize.height)
                    .position(readerCenter)
                    .allowsHitTesting(false)
            } else {
                Image(nsImage: AppResources.image("reader-idle"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: readerSize.width, height: readerSize.height)
                    .position(readerCenter)
                    .allowsHitTesting(false)

                Image(nsImage: AppResources.image("credit-card"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: cardWidth, height: cardHeight)
                    .position(cardCenter)
                    .zIndex(1)
                    .allowsHitTesting(false)

                Image(nsImage: AppResources.image("reader-slot-front"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: readerSize.width, height: readerSize.height)
                    .position(readerCenter)
                    .zIndex(2)
                    .allowsHitTesting(false)
            }

            if !showThankYou {
                ForcePad(model: force)
                    .frame(width: size.width, height: size.height)
                    .contentShape(Rectangle())
                    .zIndex(10)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Thin light-grey arrow drawn in the reader’s local frame.
private struct SwipePathArrow: View {
    let from: CGPoint
    let to: CGPoint

    var body: some View {
        Canvas { context, _ in
            var shaft = Path()
            shaft.move(to: from)
            shaft.addLine(to: to)

            let dx = to.x - from.x
            let dy = to.y - from.y
            let len = max(hypot(dx, dy), 1)
            let ux = dx / len
            let uy = dy / len
            let head: CGFloat = 12
            let wing: CGFloat = 6
            let px = -uy
            let py = ux
            let tip = to
            let left = CGPoint(x: tip.x - ux * head + px * wing,
                               y: tip.y - uy * head + py * wing)
            let right = CGPoint(x: tip.x - ux * head - px * wing,
                                y: tip.y - uy * head - py * wing)
            var headPath = Path()
            headPath.move(to: left)
            headPath.addLine(to: tip)
            headPath.addLine(to: right)

            let color = Color(white: 0.72)
            context.stroke(shaft, with: .color(color),
                           style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            context.stroke(headPath, with: .color(color),
                           style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }
        .allowsHitTesting(false)
    }
}
