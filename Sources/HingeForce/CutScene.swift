import SwiftUI

/// Everything the cutting scene needs to draw one frame.
struct CutSceneState: Equatable {
    /// Seconds since the page appeared; drives the entrance.
    var time = 0.0
    /// The (smoothed) current hinge angle, or nil until the sensor has reported.
    var hinge: Double?
    /// The hinge angle the cut line is drawn at.
    var target: Double?
    /// 0...1: how far the line has turned white.
    var alignment = 0.0
    /// Seconds since the cut was completed, or nil while still cutting.
    var completionElapsed: Double?
}

/// The cake with a dashed cut line, the swept slice highlighted, and the knife, which turns around the centre of the cake's top.
/// The cake is drawn `width` points wide; the knife may extend beyond the frame.
struct CutScene: View {
    let state: CutSceneState
    let width: CGFloat

    private var unit: CGFloat { width / Illustration.cutCakeSize.width }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: Illustration.cutCake)
                .resizable()
                .frame(width: width, height: Illustration.cutCakeSize.height * unit)

            if let hinge = state.hinge {
                sliceHighlight(hinge: hinge)
                knife(hinge: hinge)
            }
            if let target = state.target { cutLine(target: target) }
        }
        .frame(width: width, height: Illustration.cutCakeSize.height * unit, alignment: .topLeading)
    }

    // MARK: - Knife

    /// Angle to turn the knife image by so it points where `hinge` says.
    static func knifeRotation(forHinge hinge: Double) -> Double {
        HingeCut.screenAngle(forHinge: hinge) - Illustration.knifeRestAngle
    }

    /// The indicator line turns exactly with the lid. The knife on the end of it bounces gently along the
    /// line, towards and away from the cake, and settles once the cut is done.
    private func knife(hinge: Double) -> some View {
        let pivot = Illustration.knifePivot
        let center = Illustration.cutCakeCenter
        let rotation = Angle.degrees(Self.knifeRotation(forHinge: hinge))
        let anchor = UnitPoint(x: pivot.x / Illustration.knifeSize.width, y: pivot.y / Illustration.knifeSize.height)
        let size = CGSize(width: Illustration.knifeSize.width * unit, height: Illustration.knifeSize.height * unit)

        // Along the line, pointing away from the cake's centre, in screen terms.
        let radians = HingeCut.screenAngle(forHinge: hinge) * .pi / 180
        let bounce = KnifeBounce.offset(at: state.time, completionElapsed: state.completionElapsed)

        return ZStack(alignment: .topLeading) {
            Image(nsImage: Illustration.knifeLine)
                .resizable()
                .frame(width: size.width, height: size.height)
                .rotationEffect(rotation, anchor: anchor)

            Image(nsImage: Illustration.knifeBlade)
                .resizable()
                .frame(width: size.width, height: size.height)
                .rotationEffect(rotation, anchor: anchor)
                .offset(x: sin(radians) * bounce * unit, y: -cos(radians) * bounce * unit)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        // Slide the images so the line's start sits on the cake's centre.
        .offset(x: (center.x - pivot.x) * unit, y: (center.y - pivot.y) * unit)
        .opacity(LessonIntro.progress(state.time, 0.15, 0.5))
    }

    // MARK: - Slice highlight

    /// The part of the cake's top that the knife has swept: from the start line clockwise to the knife.
    private func sliceHighlight(hinge: Double) -> some View {
        SliceHighlight(toAngle: HingeCut.screenAngle(forHinge: hinge))
            .fill(Theme.sliceHighlight)
            .frame(width: Illustration.cutCakeSize.width * unit, height: Illustration.cutCakeSize.height * unit)
            .opacity(LessonIntro.progress(state.time, 0.15, 0.5))
    }

    // MARK: - Cut line

    /// The end of the cut line for a hinge angle, in cake units: from the centre out to just inside the rim.
    static func cutLineEnd(forHinge hinge: Double) -> CGPoint {
        let angle = HingeCut.screenAngle(forHinge: hinge)
        let radians = angle * .pi / 180
        let radii = Illustration.cutCakeRadii
        let length = HingeCut.rimRadius(atAngle: angle, rx: radii.width, ry: radii.height) - HingeCut.rimInset
        let center = Illustration.cutCakeCenter
        return CGPoint(x: center.x + sin(radians) * length, y: center.y - cos(radians) * length)
    }

    private func cutLine(target: Double) -> some View {
        let center = Illustration.cutCakeCenter
        let end = Self.cutLineEnd(forHinge: target)
        var line = Path()
        line.move(to: CGPoint(x: center.x * unit, y: center.y * unit))
        line.addLine(to: CGPoint(x: end.x * unit, y: end.y * unit))

        return line
            // Drawn outward from the centre as the page appears.
            .trim(from: 0, to: LessonIntro.easeOutCubic(LessonIntro.progress(state.time, 0.5, 1.0)))
            .stroke(Self.lineColor(alignment: state.alignment),
                    style: StrokeStyle(lineWidth: Self.lineWidth(alignment: state.alignment) * unit,
                                       lineCap: .round, dash: [Self.dashLength * unit, Self.dashGap * unit]))
    }

    /// The dashes of the cut line, in cake units: a 6-unit dash plus its round caps, then a gap.
    static let dashLength = 6.0
    static let dashGap = 12.0
    static var dashPeriod: Double { dashLength + dashGap }

    /// The line's thickness in cake units: it swells as the lid is held on the line, until the dashes nearly touch.
    static func lineWidth(alignment: Double) -> Double {
        let t = min(max(alignment, 0), 1)
        return baseLineWidth * (1 + (maxLineWidthFactor - 1) * t)
    }

    static let baseLineWidth = 4.0
    static let maxLineWidthFactor = 2.25

    /// The cut line's colour: the cake's purple, turning to white as `alignment` goes from 0 to 1.
    static func lineColor(alignment: Double) -> Color {
        let t = min(max(alignment, 0), 1)
        let base = Theme.cutLine
        return Color(red: base.red + (1 - base.red) * t,
                     green: base.green + (1 - base.green) * t,
                     blue: base.blue + (1 - base.blue) * t)
    }
}

/// The wedge of the cake's top face between the start line (straight up) and a direction, going clockwise.
struct SliceHighlight: Shape {
    /// Degrees clockwise from 12 o'clock.
    var toAngle: Double

    var animatableData: Double {
        get { toAngle }
        set { toAngle = newValue }
    }

    /// The wedge in cake units, clipped to the top face's ellipse.
    static func path(toAngle: Double) -> Path {
        let center = Illustration.cutCakeCenter
        let radii = Illustration.cutCakeRadii

        func point(_ degrees: Double, reach: Double) -> CGPoint {
            let radians = degrees * .pi / 180
            let r = HingeCut.rimRadius(atAngle: degrees, rx: radii.width, ry: radii.height) * reach
            return CGPoint(x: center.x + sin(radians) * r, y: center.y - cos(radians) * r)
        }

        // Walk the sweep in small steps, reaching past the rim so the ellipse does the trimming.
        var wedge = Path()
        wedge.move(to: center)
        var angle = 0.0
        while angle < toAngle {
            wedge.addLine(to: point(angle, reach: 1.3))
            angle += 2
        }
        wedge.addLine(to: point(toAngle, reach: 1.3))
        wedge.closeSubpath()

        let face = Path(ellipseIn: CGRect(x: center.x - radii.width, y: center.y - radii.height,
                                          width: radii.width * 2, height: radii.height * 2))
        return wedge.intersection(face)
    }

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / Illustration.cutCakeSize.width
        return Self.path(toAngle: toAngle)
            .applying(CGAffineTransform(scaleX: scale, y: scale))
            .offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// The knife's gentle bounce: it hops away from the cake along the indicator line and drops back,
/// like a ball bouncing, and comes to rest once the cut is complete.
enum KnifeBounce {
    /// How far the knife rises above its resting place, in cake units.
    static let height = 5.0
    /// Bounces per second.
    static let rate = 1.5
    /// How long the bounce takes to die away after the cut is completed.
    static let settleDuration = 0.4

    /// Distance from the resting place along the line, away from the cake (never negative).
    static func offset(at time: Double, completionElapsed: Double? = nil) -> Double {
        let bounce = height * abs(sin(.pi * rate * time))
        guard let completionElapsed else { return bounce }
        return bounce * (1 - LessonIntro.progress(completionElapsed, 0, settleDuration))
    }
}
