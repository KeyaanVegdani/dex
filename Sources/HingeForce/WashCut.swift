import SwiftUI

/// The rules of the washing lesson: how the laptop's tilt swings the shower, where its water lands,
/// which messes it is washing, and what happens once the plate is clean. Angles are in degrees.
enum WashCut {
    // MARK: Tilt -> shower

    /// The shower swings this many degrees for each degree the laptop is rolled sideways.
    static let swingPerRoll = 1.5
    /// Furthest the shower swings either way; about where the water reaches the plate's edge.
    static let maxSwing = 32.0
    /// Set to -1 if the shower should swing the other way when the laptop is tipped.
    static let swingDirection = 1.0

    /// The shower's swing for a laptop roll: positive sends the water to the right of the screen.
    static func swing(forRoll roll: Double) -> Double {
        min(max(roll * swingPerRoll * swingDirection, -maxSwing), maxSwing)
    }

    // MARK: Geometry (plate units, (0,0) at the plate's top-left)

    /// The shower arm is fixed here, at the top of its pipe.
    static let pivot = CGPoint(x: Illustration.washHeadOrigin.x + Illustration.washHeadPivot.x,
                               y: Illustration.washHeadOrigin.y + Illustration.washHeadPivot.y)
    /// From the pivot to where the water comes out.
    static let nozzleDistance = 109.0
    /// Height on the plate's top face where the water lands (its middle).
    static let landingY = 40.0
    /// The stretch of plate that counts as washed is this far to each side of the stream's centre line. It is
    /// a little narrower than the rain drawn, and a mess has to be covered by at least `minimumOverlap`,
    /// so brushing the very tip of a mess doesn't count.
    static let streamHalfWidth = 18.0
    static let minimumOverlap = 6.0

    static func direction(swing: Double) -> CGPoint {
        let r = swing * .pi / 180
        return CGPoint(x: sin(r), y: cos(r))
    }

    static func nozzle(swing: Double) -> CGPoint {
        let d = direction(swing: swing)
        return CGPoint(x: pivot.x + d.x * nozzleDistance, y: pivot.y + d.y * nozzleDistance)
    }

    /// Where along the plate the middle of the stream lands.
    static func landingX(swing: Double) -> Double {
        let n = nozzle(swing: swing)
        let d = direction(swing: swing)
        return n.x + d.x / d.y * (landingY - n.y)
    }

    /// The stretch of plate the water covers.
    static func landingRange(swing: Double) -> ClosedRange<Double> {
        let x = landingX(swing: swing)
        return (x - streamHalfWidth)...(x + streamHalfWidth)
    }

    static func isWashing(_ mess: Illustration.Mess, swing: Double) -> Bool {
        let water = landingRange(swing: swing)
        let covered = min(water.upperBound, mess.xRange.upperBound) - max(water.lowerBound, mess.xRange.lowerBound)
        return covered >= min(minimumOverlap, Double(mess.size.width))
    }

    // MARK: Cleaning

    /// Seconds of water each mess needs to wash away.
    static let secondsToClean = 2.0

    /// How visible a mess is after `washed` seconds of water: fully there, fading steadily to gone.
    static func messOpacity(washed: Double) -> Double {
        1 - min(max(washed / secondsToClean, 0), 1)
    }

    // MARK: After the plate is clean

    /// The shower lifts away and the water stops.
    static let exitDuration = 0.6
    static let streamFadeDuration = 0.3
    /// The plate gets its shine, and drops a little lower on the screen.
    static let glossStart = 0.3
    static let glossDuration = 0.5
    static let plateDropStart = 0.25
    static let plateDropDuration = 0.9
    static let plateDrop = 60.0
    /// Stars start to sparkle, one after another.
    static let sparkleStart = 0.9
    static let sparkleStagger = 0.15
    /// When the Finish button starts to appear, in seconds after the last mess is gone.
    static let continueStart = 1.4

    static func showerOpacity(elapsed: Double?) -> Double {
        guard let elapsed else { return 1 }
        return 1 - LessonIntro.progress(elapsed, 0, exitDuration)
    }

    /// How far (plate units) the shower has lifted away.
    static func showerLift(elapsed: Double?) -> Double {
        guard let elapsed else { return 0 }
        return 90 * LessonIntro.easeInOut(LessonIntro.progress(elapsed, 0, exitDuration))
    }

    static func streamOpacity(elapsed: Double?) -> Double {
        guard let elapsed else { return 1 }
        return 1 - LessonIntro.progress(elapsed, 0, streamFadeDuration)
    }

    static func glossOpacity(elapsed: Double?) -> Double {
        guard let elapsed else { return 0 }
        return LessonIntro.easeOutCubic(LessonIntro.progress(elapsed, glossStart, glossStart + glossDuration))
    }

    /// How far the plate has dropped down the screen, in plate units.
    static func plateOffset(elapsed: Double?) -> Double {
        guard let elapsed else { return 0 }
        return plateDrop * LessonIntro.spring(elapsed, start: plateDropStart, duration: plateDropDuration, damping: 0.8)
    }

    struct Sparkle: Equatable {
        let center: CGPoint    // plate units, on the plate
        let radius: Double     // tip distance from the middle
        let phase: Double
    }

    /// Three stars on the front left of the plate, as in the design.
    static let sparkles: [Sparkle] = [
        Sparkle(center: CGPoint(x: 20.4, y: 59.7), radius: 11.5, phase: 0),
        Sparkle(center: CGPoint(x: 37.4, y: 70.0), radius: 5.5, phase: 0.35),
        Sparkle(center: CGPoint(x: 87.0, y: 80.0), radius: 4.8, phase: 0.7),
    ]

    /// Size multiplier for a star: it pops in, then keeps twinkling. Zero before it appears.
    static func sparkleScale(index: Int, elapsed: Double?, time: Double) -> Double {
        guard let elapsed else { return 0 }
        let start = sparkleStart + sparkleStagger * Double(index)
        let pop = LessonIntro.spring(elapsed, start: start, duration: 0.5, damping: 0.55)
        let twinkle = 0.75 + 0.25 * sin(2 * .pi * (0.9 * time + sparkles[index].phase))
        return pop * twinkle
    }
}

/// Tracks how long the water has been on each mess. Washing carries on until all are clean; dirt never comes back.
struct WashTracker {
    private(set) var washed: [Double]

    init(messCount: Int = Illustration.washMesses.count) {
        washed = Array(repeating: 0, count: messCount)
    }

    var isComplete: Bool { washed.allSatisfy { $0 >= WashCut.secondsToClean } }

    mutating func update(swing: Double, dt: TimeInterval) {
        for (index, mess) in Illustration.washMesses.enumerated() where WashCut.isWashing(mess, swing: swing) {
            washed[index] = min(washed[index] + dt, WashCut.secondsToClean)
        }
    }
}

// MARK: - Rain

/// The endless rain from the shower head: capsules that fall along the stream and fade as they reach the plate.
enum Rain {
    struct Drop: Equatable {
        var position: CGPoint    // plate units, the drop's middle
        var opacity: Double
    }

    static let laneOffsets: [Double] = [-21, -12.6, -4.2, 4.2, 12.6, 21]
    /// Distance between drops in a lane, and how fast they fall (plate units per second).
    static let spacing = 26.0
    static let speed = 300.0
    /// Drops reach the plate at a random depth in this band, and fade over the last few units.
    static let landingDepth: ClosedRange<Double> = 14...62
    static let fadeDistance = 12.0

    /// A fixed pseudo-random number in 0...1 for a lane and the n-th drop that lane has released.
    static func random(lane: Int, drop: Int) -> Double {
        var z = UInt64(bitPattern: Int64(lane &* 7919 &+ drop &* 104_729)) &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }

    /// Every drop in the air at `time`, for a stream swung to `swing` degrees.
    static func drops(at time: Double, swing: Double) -> [Drop] {
        let nozzle = WashCut.nozzle(swing: swing)
        let d = WashCut.direction(swing: swing)
        let sideways = CGPoint(x: d.y, y: -d.x)   // across the stream
        let pathLength = (landingDepth.upperBound - Double(nozzle.y)) / d.y

        var drops: [Drop] = []
        for (lane, offset) in laneOffsets.enumerated() {
            let travelled = speed * time + Double(lane) * spacing * 0.618
            let firstGap = travelled.truncatingRemainder(dividingBy: spacing)
            let released = Int((travelled / spacing).rounded(.down))

            var slot = 0
            while true {
                let along = firstGap + Double(slot) * spacing
                if along > pathLength { break }
                let point = CGPoint(x: Double(nozzle.x) + Double(d.x) * along + Double(sideways.x) * offset,
                                    y: Double(nozzle.y) + Double(d.y) * along + Double(sideways.y) * offset)
                let landsAt = landingDepth.lowerBound + (landingDepth.upperBound - landingDepth.lowerBound)
                    * random(lane: lane, drop: released - slot)
                let opacity = min(max((landsAt - Double(point.y)) / fadeDistance, 0), 1)
                if opacity > 0 { drops.append(Drop(position: point, opacity: opacity)) }
                slot += 1
            }
        }
        return drops
    }
}

// MARK: - Scene

/// Everything the washing scene needs to draw one frame.
struct WashSceneState: Equatable {
    /// Seconds since the page appeared; drives the rain.
    var time = 0.0
    /// The shower's swing, degrees, positive to the right.
    var swing = 0.0
    /// Seconds of water each mess has had.
    var washed = [Double](repeating: 0, count: Illustration.washMesses.count)
    /// Seconds since the last mess was gone, or nil while still washing.
    var completionElapsed: Double?
}

/// The plate with its messes, the falling water, and the swinging shower head above.
/// Positions are plate units scaled by `unit`, with the plate's top-left at the view's top-left.
struct WashScene: View {
    let state: WashSceneState
    let unit: CGFloat

    private static let canvasTop = -340.0   // the rain canvas covers everything above the plate too
    private static let dropColor = Color(red: 0xA9 / 255, green: 0xDD / 255, blue: 0xF5 / 255)

    var body: some View {
        let done = state.completionElapsed
        let plateSize = Illustration.pressPlateSize

        ZStack(alignment: .topLeading) {
            Image(nsImage: Illustration.pressPlate)
                .resizable()
                .frame(width: plateSize.width * unit, height: plateSize.height * unit)

            GlossBand()
                .fill(Color(red: 0xE7 / 255, green: 0xED / 255, blue: 0xEF / 255))
                .frame(width: plateSize.width * unit, height: plateSize.height * unit)
                .opacity(WashCut.glossOpacity(elapsed: done))

            ForEach(Illustration.washMesses.indices, id: \.self) { index in
                let mess = Illustration.washMesses[index]
                Image(nsImage: Illustration.washMessImages[index])
                    .resizable()
                    .frame(width: mess.size.width * unit, height: mess.size.height * unit)
                    .opacity(WashCut.messOpacity(washed: state.washed[index]))
                    .offset(x: mess.origin.x * unit, y: mess.origin.y * unit)
            }

            rain
            shower

            ForEach(WashCut.sparkles.indices, id: \.self) { index in
                let sparkle = WashCut.sparkles[index]
                let scale = WashCut.sparkleScale(index: index, elapsed: done, time: state.time)
                SparkleShape()
                    .fill(Color.white)
                    .frame(width: sparkle.radius * 2 * unit, height: sparkle.radius * 2 * unit)
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(12 * sin(2 * .pi * (0.9 * state.time + sparkle.phase))))
                    .offset(x: (sparkle.center.x - sparkle.radius) * unit, y: (sparkle.center.y - sparkle.radius) * unit)
            }
        }
        .frame(width: plateSize.width * unit, height: plateSize.height * unit, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var rain: some View {
        let opacity = WashCut.streamOpacity(elapsed: state.completionElapsed)
        let drops = opacity > 0 ? Rain.drops(at: state.time, swing: state.swing) : []
        let size = Illustration.washDropSize

        return Canvas { context, _ in
            for drop in drops {
                var layer = context
                layer.translateBy(x: drop.position.x * unit, y: (drop.position.y - Self.canvasTop) * unit)
                layer.rotate(by: .degrees(-state.swing))
                let rect = CGRect(x: -size.width / 2 * unit, y: -size.height / 2 * unit, width: size.width * unit, height: size.height * unit)
                layer.fill(Path(roundedRect: rect, cornerRadius: size.width / 2 * unit), with: .color(Self.dropColor.opacity(drop.opacity * opacity)))
            }
        }
        .frame(width: Illustration.pressPlateSize.width * unit, height: (Illustration.pressPlateSize.height - Self.canvasTop) * unit)
        .offset(y: Self.canvasTop * unit)
    }

    private var shower: some View {
        let size = Illustration.washHeadSize
        let pivot = Illustration.washHeadPivot
        let origin = Illustration.washHeadOrigin
        let lift = WashCut.showerLift(elapsed: state.completionElapsed)

        return Image(nsImage: Illustration.washHead)
            .resizable()
            .frame(width: size.width * unit, height: size.height * unit)
            // The arm swings about the top of its pipe; positive swing sends the water to the right.
            .rotationEffect(.degrees(-state.swing), anchor: UnitPoint(x: pivot.x / size.width, y: pivot.y / size.height))
            .opacity(WashCut.showerOpacity(elapsed: state.completionElapsed))
            .offset(x: origin.x * unit, y: (origin.y - lift) * unit)
    }
}

/// The shine across the clean plate: the design's slanted band, clipped to the plate's top face.
struct GlossBand: Shape {
    /// The band's two straight edges, measured from the design's clean plate.
    static func path() -> Path {
        var band = Path()
        band.move(to: CGPoint(x: 266, y: -10))
        band.addLine(to: CGPoint(x: 314.8, y: -10))
        band.addLine(to: CGPoint(x: 31, y: 95))
        band.addLine(to: CGPoint(x: -108.7, y: 95))
        band.closeSubpath()

        let face = Path(ellipseIn: CGRect(x: 232.136 - 210.244, y: 40.0105 - 40.0105, width: 420.488, height: 80.021))
        return band.intersection(face)
    }

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / Illustration.pressPlateSize.width
        return Self.path().applying(CGAffineTransform(scaleX: scale, y: scale)).offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// A four-pointed sparkle with concave sides, filling its frame.
struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2, ry = rect.height / 2
        let pull = 0.12   // how close to the middle the sides are drawn: smaller is a sharper star

        var star = Path()
        star.move(to: CGPoint(x: c.x, y: c.y - ry))
        star.addQuadCurve(to: CGPoint(x: c.x + rx, y: c.y), control: CGPoint(x: c.x + rx * pull, y: c.y - ry * pull))
        star.addQuadCurve(to: CGPoint(x: c.x, y: c.y + ry), control: CGPoint(x: c.x + rx * pull, y: c.y + ry * pull))
        star.addQuadCurve(to: CGPoint(x: c.x - rx, y: c.y), control: CGPoint(x: c.x - rx * pull, y: c.y + ry * pull))
        star.addQuadCurve(to: CGPoint(x: c.x, y: c.y - ry), control: CGPoint(x: c.x - rx * pull, y: c.y - ry * pull))
        star.closeSubpath()
        return star
    }
}
