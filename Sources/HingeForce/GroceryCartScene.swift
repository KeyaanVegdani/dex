import SwiftUI

/// Draws the cart on its diagonal path with speed-line trails whose length follows blow intensity.
/// Trails are stroked with round caps (not a cropped bitmap) so ends stay pill-shaped.
struct GroceryCartScene: View {
    let state: GroceryCartSceneState
    let size: CGSize

    var body: some View {
        let cartSide = min(size.width, size.height) * 0.28
        let trailSize = CGSize(width: cartSide * 1.35, height: cartSide * 0.72)
        let start = CGPoint(x: size.width * 0.16, y: size.height * 0.22)
        let end = CGPoint(x: size.width * 0.78, y: size.height * 0.62)
        let t = state.progress
        let center = CGPoint(x: start.x + (end.x - start.x) * t,
                             y: start.y + (end.y - start.y) * t)
        let trailLength = GroceryCart.trailLength(intensity: state.intensity)

        ZStack {
            if trailLength > 0.01 {
                SpeedTrailLines(size: trailSize, length: trailLength)
                    // Sit behind the handle (toward top-left of the cart).
                    .frame(width: trailSize.width, height: trailSize.height)
                    .position(x: center.x - cartSide * 0.48, y: center.y - cartSide * 0.32)
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
}

/// Three parallel diagonal strokes matching the speed-lines asset: round caps, fixed angle/weight,
/// length grows from the cart-adjacent end toward the top-left.
private struct SpeedTrailLines: View {
    let size: CGSize
    /// 0...1 visible fraction of each stroke’s full length.
    let length: Double

    /// Same diagonal as the cart path (top-left → bottom-right).
    private var direction: CGVector {
        let dx: CGFloat = 0.62
        let dy: CGFloat = 0.40
        let mag = sqrt(dx * dx + dy * dy)
        return CGVector(dx: dx / mag, dy: dy / mag)
    }

    var body: some View {
        Canvas { context, canvasSize in
            let dir = direction
            // Perpendicular for parallel spacing (rotate 90°).
            let perp = CGVector(dx: -dir.dy, dy: dir.dx)
            let stroke = max(canvasSize.height * 0.09, 4)
            let gap = canvasSize.height * 0.22
            let maxLen = canvasSize.width * 0.92

            // Relative lengths & lateral offsets inspired by the speed-lines PNG
            // (middle longest; top shortest; slight stagger).
            let lines: [(lengthScale: CGFloat, offset: CGFloat, stagger: CGFloat)] = [
                (0.72, -gap, 0.08),
                (1.00, 0, 0),
                (0.85, gap, 0.04),
            ]

            // Anchor at the cart-adjacent (bottom-right) end of the trail box.
            let anchor = CGPoint(x: canvasSize.width * 0.92, y: canvasSize.height * 0.72)

            for line in lines {
                let full = maxLen * line.lengthScale
                let visible = full * length
                guard visible > stroke * 0.5 else { continue }

                let base = CGPoint(
                    x: anchor.x + perp.dx * line.offset - dir.dx * full * line.stagger,
                    y: anchor.y + perp.dy * line.offset - dir.dy * full * line.stagger
                )
                // Grow toward top-left (opposite the motion direction).
                let tip = CGPoint(x: base.x - dir.dx * visible, y: base.y - dir.dy * visible)

                var path = Path()
                path.move(to: tip)
                path.addLine(to: base)
                context.stroke(
                    path,
                    with: .color(Color(white: 0.78).opacity(0.55 + 0.45 * length)),
                    style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}
