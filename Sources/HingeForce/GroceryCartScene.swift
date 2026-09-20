import SwiftUI

/// Draws the cart on its diagonal path with speed-line trails whose length follows blow intensity.
/// Trails are stroked under the cart with round caps, stop short of the frame, and use room on the
/// top-left so long lines aren’t clipped by a tight local frame.
struct GroceryCartScene: View {
    let state: GroceryCartSceneState
    let size: CGSize

    /// Exact trail color Jane requested.
    private static let trailColor = Color(red: 0xEE / 255, green: 0xEE / 255, blue: 0xEE / 255)

    var body: some View {
        let cartSide = min(size.width, size.height) * 0.28
        let start = CGPoint(x: size.width * 0.16, y: size.height * 0.22)
        let end = CGPoint(x: size.width * 0.78, y: size.height * 0.62)
        let t = state.progress
        let center = CGPoint(x: start.x + (end.x - start.x) * t,
                             y: start.y + (end.y - start.y) * t)
        let trailLength = GroceryCart.trailLength(intensity: state.intensity)

        ZStack {
            // Trails first → always behind the cart artwork.
            if trailLength > 0.01 {
                SpeedTrailLines(
                    cartCenter: center,
                    cartSide: cartSide,
                    length: trailLength,
                    color: Self.trailColor
                )
            }

            Image(nsImage: AppResources.image("cart"))
                .resizable()
                .scaledToFit()
                .frame(width: cartSide, height: cartSide)
                .position(center)
        }
        .frame(width: size.width, height: size.height)
        // Allow long trails to extend into the padded top-left without a hard clip.
        .compositingGroup()
        .allowsHitTesting(false)
    }
}

/// Three parallel diagonal strokes in scene space: round caps, thin `#EEEEEE`, anchored with a gap
/// before the cart handle so they never paint over the basket/wheels.
private struct SpeedTrailLines: View {
    let cartCenter: CGPoint
    let cartSide: CGFloat
    /// 0...1 visible fraction of each stroke’s full length.
    let length: Double
    let color: Color

    private var direction: CGVector {
        let dx: CGFloat = 0.62
        let dy: CGFloat = 0.40
        let mag = sqrt(dx * dx + dy * dy)
        return CGVector(dx: dx / mag, dy: dy / mag)
    }

    var body: some View {
        Canvas { context, canvasSize in
            let dir = direction
            let perp = CGVector(dx: -dir.dy, dy: dir.dx)

            // Thinner than the earlier build; still readable on white.
            let stroke = max(cartSide * 0.028, 2.0)
            let gap = cartSide * 0.085
            // Clear air between trail ends and the cart handle/frame.
            let clearOfCart = cartSide * 0.42
            let pad: CGFloat = max(cartSide * 0.35, 48)

            // Handle side of the cart is toward top-left (opposite motion).
            let handle = CGPoint(
                x: cartCenter.x - dir.dx * clearOfCart,
                y: cartCenter.y - dir.dy * clearOfCart
            )

            // How far we can grow toward top-left before hitting padded bounds.
            let roomX = max(handle.x - pad, 0)
            let roomY = max(handle.y - pad, 0)
            // Project available room onto the trail axis.
            let room = min(
                roomX / max(dir.dx, 0.001),
                roomY / max(dir.dy, 0.001)
            )
            let maxLen = min(cartSide * 1.55, room)

            // Top longest, bottom shortest (matches the no-overlap reference).
            let lines: [(lengthScale: CGFloat, offset: CGFloat, stagger: CGFloat)] = [
                (1.00, -gap, 0.02),
                (0.88, 0, 0),
                (0.72, gap, 0.05),
            ]

            for line in lines {
                let full = maxLen * line.lengthScale
                let visible = full * length
                guard visible > stroke else { continue }

                let base = CGPoint(
                    x: handle.x + perp.dx * line.offset - dir.dx * full * line.stagger,
                    y: handle.y + perp.dy * line.offset - dir.dy * full * line.stagger
                )
                let tip = CGPoint(x: base.x - dir.dx * visible, y: base.y - dir.dy * visible)

                var path = Path()
                path.move(to: tip)
                path.addLine(to: base)
                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round)
                )
            }
        }
        // Full lesson canvas so long trails aren’t trapped in a small local frame.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
