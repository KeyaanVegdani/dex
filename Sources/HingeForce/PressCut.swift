import SwiftUI

/// The rules of the pressing lesson: how trackpad pressure lowers the knife, when the press counts as
/// all the way down, and how the front of the cake pops away afterwards.
enum PressCut {
    /// A pressure reading (1...10) at or above this counts as "the most", leaving a little tolerance
    /// so the trackpad's very top end doesn't have to be hit exactly.
    static let threshold = 9.0
    /// How long the press has to stay at the bottom before the cut is done.
    static let holdDuration: TimeInterval = 0.3
    /// Easing off the press drains the hold this many times faster than it filled.
    static let drainRate = 3.0

    /// How far down the knife is for a pressure reading: 0 at the lightest touch, 1 at full pressure.
    static func depth(forReading reading: Double) -> Double {
        min(max((reading - 1) / 9, 0), 1)
    }

    /// The knife's top edge in scene units for a depth (0...1): raised above the cake, or pushed down.
    static func knifeY(atDepth depth: Double) -> Double {
        LessonIntro.lerp(Illustration.pressKnifeRaisedY, Illustration.pressKnifeLoweredY, min(max(depth, 0), 1))
    }

    // MARK: - After the cut

    /// The cake front waits this long after the cut is done, then pops away.
    static let popDelay = 0.15
    /// How long the whole pop-away takes once it starts.
    static let popDuration = 1.0
    /// The cake front pops up this high, in scene units, and this fast, before it starts to drop away.
    static let popHop = 34.0
    static let popHopDuration = 0.5
    /// It starts to shrink and drop a little into the hop, so the pop up is seen first.
    static let shrinkDelay = 0.1
    static let travelDelay = 0.25
    /// The knife finishes its last stretch to the bottom over this long.
    static let knifeSettleDuration = 0.35
    /// When the Continue button starts to appear, in seconds after the cut is done.
    static let continueStart = popDelay + popDuration + 0.2

    struct FrontPose: Equatable {
        var scale: Double
        var origin: CGPoint
    }

    /// Where the cake front is `elapsed` seconds after the cut is done (nil while still cutting).
    /// It pops up, shrinks to 7% and drops to the left of the plate with a small bounce.
    static func frontPose(elapsed: Double?) -> FrontPose {
        let start = Illustration.pressFrontOrigin
        guard let elapsed else { return FrontPose(scale: 1, origin: start) }

        let end = Illustration.pressFrontFinalOrigin
        let shrink = LessonIntro.spring(elapsed, start: popDelay + shrinkDelay,
                                        duration: popDuration - shrinkDelay, damping: 0.8)
        let travel = LessonIntro.spring(elapsed, start: popDelay + travelDelay,
                                        duration: popDuration - travelDelay, damping: 0.62)
        let hop = popHop * sin(.pi * LessonIntro.progress(elapsed, popDelay, popDelay + popHopDuration))

        return FrontPose(scale: LessonIntro.lerp(1, Illustration.pressFrontFinalScale, shrink),
                         origin: CGPoint(x: start.x, y: LessonIntro.lerp(start.y, end.y, travel) - hop))
    }

    /// The knife's depth after the cut: it eases from wherever it was down to the very bottom.
    static func settledDepth(from depth: Double, elapsed: Double) -> Double {
        LessonIntro.lerp(depth, 1, LessonIntro.easeOutCubic(LessonIntro.progress(elapsed, 0, knifeSettleDuration)))
    }
}

/// Tracks how long the press has been at the bottom.
struct PressTracker {
    private(set) var held: TimeInterval = 0
    private(set) var isComplete = false

    /// 0...1 progress towards the cut being done.
    var progress: Double { min(held / PressCut.holdDuration, 1) }

    mutating func update(reading: Double, dt: TimeInterval) {
        guard !isComplete else { return }
        if reading >= PressCut.threshold {
            held += dt
        } else {
            held = max(0, held - dt * PressCut.drainRate)
        }
        if held >= PressCut.holdDuration { isComplete = true }
    }
}

/// Everything the pressing scene needs to draw one frame.
struct PressSceneState: Equatable {
    /// Seconds since the page appeared.
    var time = 0.0
    /// 0...1: how far down the knife has been pushed.
    var depth = 0.0
    /// Seconds since the cut was completed, or nil while still cutting.
    var completionElapsed: Double?
}

/// The plate, the slice of cake, the knife and the front of the cake, stacked in that order (bottom to
/// top). The knife sinks behind the cake front, so it looks like it is going into the cake.
/// Positions are scene units scaled by `unit`, with the plate's top-left at the view's top-left.
struct PressScene: View {
    let state: PressSceneState
    let unit: CGFloat

    var body: some View {
        let front = PressCut.frontPose(elapsed: state.completionElapsed)

        ZStack(alignment: .topLeading) {
            // 1. Plate
            layer(Illustration.pressPlate, size: Illustration.pressPlateSize, at: .zero)
            // 2. The slice, hidden behind the cake front until it pops away
            layer(Illustration.pressSlice, size: Illustration.pressSliceSize, at: Illustration.pressSliceOrigin)
            // 3. Knife
            layer(Illustration.pressKnife, size: Illustration.pressKnifeSize,
                  at: CGPoint(x: Illustration.pressKnifeX, y: PressCut.knifeY(atDepth: state.depth)))
            // 4. The front of the cake, in front of everything
            layer(Illustration.pressFront, size: Illustration.pressFrontSize, at: front.origin,
                  scale: front.scale)
        }
        .frame(width: Illustration.pressPlateSize.width * unit,
               height: Illustration.pressPlateSize.height * unit,
               alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func layer(_ image: NSImage, size: CGSize, at origin: CGPoint, scale: Double = 1) -> some View {
        Image(nsImage: image)
            .resizable()
            .frame(width: size.width * unit, height: size.height * unit)
            .scaleEffect(scale, anchor: .topLeading)
            .offset(x: origin.x * unit, y: origin.y * unit)
    }
}
