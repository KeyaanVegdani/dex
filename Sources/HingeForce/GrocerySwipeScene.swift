import SwiftUI

/// Reader back → credit card → slot front. Arrow under the reader along the swipe path.
struct GrocerySwipeScene: View {
    let state: GrocerySwipeSceneState
    let size: CGSize
    let force: TrackpadForce

    var body: some View {
        let readerSide = GrocerySwipe.readerSide(for: size)
        let readerCenter = GrocerySwipe.readerCenter(for: size)
        let cardWidth = readerSide * 0.30
        let cardHeight = cardWidth * (322.0 / 236.0)
        let cardCenter = GrocerySwipe.cardCenter(progress: state.progress,
                                                 readerCenter: readerCenter,
                                                 readerSide: readerSide)
        let arrow = GrocerySwipe.arrowEndpoints(readerCenter: readerCenter, readerSide: readerSide)
        let arrowOpacity = GrocerySwipe.arrowOpacity(progress: state.progress)
        let showThankYou = state.isComplete

        ZStack {
            // Full-scene drag pad — click-and-drag drives the card.
            if !showThankYou {
                ForcePad(model: force)
                    .frame(width: size.width, height: size.height)
                    .contentShape(Rectangle())
            }

            // Arrow beneath the reader, along the slot path.
            if !showThankYou {
                SwipePathArrow(from: arrow.0, to: arrow.1)
                    .opacity(arrowOpacity)
                    .allowsHitTesting(false)
            }

            if showThankYou {
                Image(nsImage: AppResources.image("reader-thank-you"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: readerSide, height: readerSide)
                    .position(readerCenter)
                    .allowsHitTesting(false)
            } else {
                Image(nsImage: AppResources.image("reader-idle"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: readerSide, height: readerSide)
                    .position(readerCenter)
                    .allowsHitTesting(false)

                Image(nsImage: AppResources.image("credit-card"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: cardWidth, height: cardHeight)
                    .position(cardCenter)
                    .zIndex(1)
                    .allowsHitTesting(false)

                // Same canvas as the reader — lip sits over the slot so the card reads “in” it.
                Image(nsImage: AppResources.image("reader-slot-front"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: readerSide, height: readerSide)
                    .position(readerCenter)
                    .zIndex(2)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Thin light-grey arrow at the swipe angle (~30° from vertical).
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
            let head: CGFloat = 14
            let wing: CGFloat = 7
            // Perpendicular for the arrowhead wings.
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
                           style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            context.stroke(headPath, with: .color(color),
                           style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
        }
        .allowsHitTesting(false)
    }
}
