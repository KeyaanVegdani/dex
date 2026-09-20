import SwiftUI

/// Everything the candle scene needs to draw one frame.
struct CandleSceneState: Equatable {
    /// Seconds since the lesson appeared; drives the entrance animation and idle flicker.
    var time: Double = 0
    /// How hard the candles are being blown, 0...1 (blow reading 1...10).
    var bend: Double = 0
    /// Progress toward blowing out, 0...1. The flames shrink and flutter as it builds.
    var holdProgress: Double = 0
    /// Seconds since the candles were blown out, or nil while they are still lit.
    var blowOutElapsed: Double?
}

/// Per-flame transform for a frame.
struct FlameMotion: Equatable {
    var angle: Double      // degrees, positive leans right
    var scaleX: Double
    var scaleY: Double
    var opacity: Double
}

/// The cake with three flames: animates in, then the flames idle, lean with the blow, and blow out.
/// The cake is drawn `width` points wide; flames may extend above the frame.
struct CandleScene: View {
    let state: CandleSceneState
    let width: CGFloat

    static let maxBendDegrees = 55.0
    static let flameScale: CGFloat = 1.25
    /// How far the flame's bottom tip tucks into the candle top, in cake units.
    static let flameOverlap: CGFloat = 4
    static let blowOutDuration = 0.35
    /// Left-to-right stagger so the wind seems to sweep across the candles.
    static let blowOutStagger = 0.09

    private var unit: CGFloat { width / Illustration.cakeSize.width }

    var body: some View {
        let intro = LessonIntro.cake(at: state.time)
        let height = Illustration.cakeSize.height * unit

        ZStack(alignment: .topLeading) {
            layer(Illustration.plate)

            layer(Illustration.body)
                .rotationEffect(.degrees(intro.bodyTilt),
                                anchor: UnitPoint(x: Illustration.bodyCenter.x / Illustration.cakeSize.width,
                                                  y: Illustration.bodyCenter.y / Illustration.cakeSize.height))
                .offset(y: -intro.bodyLift * unit)

            ForEach(Illustration.candleTops.indices, id: \.self) { index in
                stick(index, intro.sticks[index])
            }

            ForEach(Illustration.candleTops.indices, id: \.self) { index in
                flame(index)
                smoke(index)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .scaleEffect(intro.groupScale)
        .opacity(intro.groupOpacity)
    }

    private func layer(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .frame(width: width, height: Illustration.cakeSize.height * unit)
    }

    private func stick(_ index: Int, _ intro: LessonIntro.Stick) -> some View {
        let top = Illustration.candleTops[index]
        return Image(nsImage: Illustration.stick)
            .resizable()
            .frame(width: Illustration.stickSize.width * unit, height: Illustration.stickSize.height * unit)
            .scaleEffect(intro.scale)
            .rotationEffect(.degrees(intro.angle))
            .opacity(intro.opacity)
            .position(x: top.x * unit,
                      y: (top.y + Illustration.stickSize.height / 2 - intro.lift) * unit)
    }

    // MARK: - Flame

    private func flame(_ index: Int) -> some View {
        let motion = Self.motion(forCandle: index, state: state)
        let size = CGSize(width: Illustration.flameSize.width * Self.flameScale * unit,
                          height: Illustration.flameSize.height * Self.flameScale * unit)
        let top = Illustration.candleTops[index]
        // A flame rides its candle, so it never floats free while the candle is still dropping in.
        let candleLift = LessonIntro.cake(at: state.time).sticks[index].lift

        return Image(nsImage: Illustration.flame)
            .resizable()
            .frame(width: size.width, height: size.height)
            // Both transforms pivot on the bottom tip so the flame sways from its base.
            .scaleEffect(x: motion.scaleX, y: motion.scaleY, anchor: .bottom)
            .rotationEffect(.degrees(motion.angle), anchor: .bottom)
            .opacity(motion.opacity)
            .position(x: top.x * unit, y: (top.y + Self.flameOverlap - candleLift) * unit - size.height / 2)
    }

    /// Idle flicker plus the effect of the blow and the blow-out, for one flame.
    static func motion(forCandle index: Int, state: CandleSceneState) -> FlameMotion {
        let phase = Double(index) * 2.1
        let t = state.time
        let bend = state.bend
        let hold = state.holdProgress

        // Blowing makes the flame livelier as well as leaning it.
        let liveliness = 1 + 1.5 * bend + 1.0 * hold
        let sway = (2.5 * sin(2 * .pi * 1.3 * t + phase) + 1.2 * sin(2 * .pi * 3.1 * t + 1.7 * phase)) * liveliness
        let flicker = 0.045 * sin(2 * .pi * 2.4 * t + phase) + 0.025 * sin(2 * .pi * 5.3 * t + 2 * phase)

        // Flames pop on at the end of the entrance animation.
        let lighting = LessonIntro.cake(at: t).flameScale[index]

        var angle = sway + bend * maxBendDegrees
        var scaleY = (1 + flicker) * (1 - 0.18 * bend) * (1 - 0.30 * hold) * lighting
        var scaleX = (1 - 0.6 * flicker) * (1 + 0.08 * bend) * (1 - 0.15 * hold) * lighting
        var opacity = 1.0

        if let elapsed = state.blowOutElapsed {
            let u = min(max((elapsed - Double(index) * blowOutStagger) / blowOutDuration, 0), 1)
            let eased = u * u
            angle = angle * (1 - u) + (bend * maxBendDegrees + 28 * eased) * u
            scaleY *= 1 - eased
            scaleX *= 1 - 0.5 * eased
            opacity = 1 - u
        }
        return FlameMotion(angle: angle, scaleX: scaleX, scaleY: scaleY, opacity: opacity)
    }

    // MARK: - Smoke

    /// The wisp that curls up from a candle once its flame is out, drawn from the bottom up.
    @ViewBuilder
    private func smoke(_ index: Int) -> some View {
        let progress = LessonOutro.smokeProgress(candle: index, elapsed: state.blowOutElapsed)
        if progress > 0 {
            let top = Illustration.candleTops[index]
            SmokeWisp()
                .trim(from: 0, to: progress)
                .stroke(Theme.smoke, style: StrokeStyle(lineWidth: Illustration.smokeStroke * unit, lineCap: .round, lineJoin: .round))
                .frame(width: Illustration.smokeSize.width * unit, height: Illustration.smokeSize.height * unit)
                .position(x: top.x * unit,
                          y: (top.y - Illustration.smokeGap - Illustration.smokeSize.height / 2) * unit)
        }
    }
}

/// The centre line of smoke.svg. The path starts at the bottom, so trimming it from 0 draws it upward.
struct SmokeWisp: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / Illustration.smokeSize.width
        let sy = rect.height / Illustration.smokeSize.height
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        var path = Path()
        path.move(to: point(8.82138, 36.5))
        path.addCurve(to: point(10.8214, 20.5), control1: point(8.82138, 36.5), control2: point(26.8213, 25.5))
        path.addCurve(to: point(16.3214, 3), control1: point(-5.17855, 15.5), control2: point(6.8214, 6))
        return path
    }
}
