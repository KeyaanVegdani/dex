import SwiftUI

/// The lesson's segment indicator: finished segments are solid green dots, the current one is a
/// striped pill, and upcoming ones are grey dots.
struct LessonProgressBar: View {
    let segments: Int
    /// Zero-based index of the segment in progress.
    let current: Int
    /// 0 = collapsed at the centre, 1 = fully expanded (may overshoot slightly).
    var expansion: Double = 1
    /// 0...1: how far the in-progress segment has turned solid green to show it is done.
    var completion: Double = 0

    private let dot: CGFloat = 26

    var body: some View {
        HStack(spacing: 8 * expansion - dot * 1.6 * (1 - expansion)) {
            ForEach(0..<segments, id: \.self) { index in
                if index < current {
                    Circle().fill(Theme.green).frame(width: dot, height: dot)
                } else if index == current {
                    StripedCapsule()
                        .overlay(Capsule().fill(Theme.green).opacity(completion))
                        .frame(width: dot * 2.3, height: dot)
                } else {
                    Circle().fill(Theme.track).frame(width: dot, height: dot)
                }
            }
        }
        .scaleEffect(0.6 + 0.4 * expansion)
        .opacity(min(expansion * 2, 1))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: current)
    }
}

private struct StripedCapsule: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 12
            var x = -size.height
            while x < size.width {
                var stripe = Path()
                stripe.move(to: CGPoint(x: x, y: size.height))
                stripe.addLine(to: CGPoint(x: x + size.height, y: 0))
                context.stroke(stripe, with: .color(.white.opacity(0.3)), lineWidth: 5)
                x += step
            }
        }
        .background(Theme.yellow)
        .clipShape(Capsule())
    }
}
