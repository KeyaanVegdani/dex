import SwiftUI

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .modifier(PressSound(isPressed: configuration.isPressed))
    }
}

/// A Test System page: an illustration, then the icon and percentage, a hint, and a button.
struct TestPageFrame<Content: View>: View {
    let icon: NSImage
    let percent: Double
    let subtitle: String
    let buttonTitle: String
    /// Whether the illustration can receive clicks; the trackpad page listens for them.
    var contentAllowsHits = false
    let onButton: () -> Void
    @ViewBuilder let content: (TestLayout) -> Content

    var body: some View {
        GeometryReader { geo in
            let layout = TestLayout(size: geo.size)

            ZStack {
                Theme.background

                content(layout)
                    .allowsHitTesting(contentAllowsHits)

                HStack(spacing: 14 * layout.unit) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: TestArtwork.iconSize.width * layout.unit, height: TestArtwork.iconSize.height * layout.unit)
                    Text("\(Int(percent.rounded()))%")
                        .font(.system(size: layout.percentFont, weight: .bold))
                        .foregroundStyle(Color.black)
                        .monospacedDigit()
                }
                .position(x: geo.size.width / 2, y: layout.readoutY)
                .allowsHitTesting(false)

                Text(subtitle)
                    .font(.system(size: layout.subtitleFont))
                    .foregroundStyle(Theme.subtitle)
                    .position(x: geo.size.width / 2, y: layout.subtitleY)
                    .allowsHitTesting(false)

                Button(action: onButton) {
                    Text(buttonTitle)
                        .font(.system(size: layout.buttonFont, weight: .semibold))
                        .foregroundStyle(Theme.pillText)
                        .frame(width: layout.buttonSize.width, height: layout.buttonSize.height)
                        .background(Theme.pill, in: Capsule())
                }
                .buttonStyle(PressScaleButtonStyle())
                .position(layout.buttonCenter)
            }
        }
    }
}

// MARK: - Scenes

/// The laptop from the side: the lid turns about the circle at the corner of the base.
struct HingeScene: View {
    let hinge: Double
    let unit: CGFloat

    /// Where the lid artwork's top-left sits relative to the base's, so its bottom end is on the circle.
    static var lidOrigin: CGPoint {
        CGPoint(x: TestArtwork.hingeCircleCenter.x - TestArtwork.hingeLidPivot.x,
                y: TestArtwork.hingeCircleCenter.y - TestArtwork.hingeLidPivot.y)
    }

    /// The centre of the base and lid together, in the base's own units. The page centres this, at rest.
    static var restCenter: CGPoint {
        let base = TestArtwork.hingeBaseSize
        let lid = lidOrigin
        return CGPoint(x: (lid.x + base.width) / 2, y: (lid.y + base.height) / 2)
    }

    var body: some View {
        let base = TestArtwork.hingeBaseSize, lid = TestArtwork.hingeLidSize, pivot = TestArtwork.hingeLidPivot

        ZStack(alignment: .topLeading) {
            Image(nsImage: TestArtwork.hingeLid)
                .resizable()
                .frame(width: lid.width * unit, height: lid.height * unit)
                .rotationEffect(.degrees(TestMotion.lidRotation(hinge: hinge)),
                                anchor: UnitPoint(x: pivot.x / lid.width, y: pivot.y / lid.height))
                .offset(x: Self.lidOrigin.x * unit, y: Self.lidOrigin.y * unit)

            // The base, with the circle the lid turns on, is in front of the lid.
            Image(nsImage: TestArtwork.hingeBase)
                .resizable()
                .frame(width: base.width * unit, height: base.height * unit)
        }
        .frame(width: base.width * unit, height: base.height * unit, alignment: .topLeading)
    }
}

/// The laptop from above with the left speaker's dots, which shift towards red as the microphone gets louder.
struct MicScene: View {
    let level: Double
    let unit: CGFloat

    var body: some View {
        let size = TestArtwork.laptopSize

        ZStack(alignment: .topLeading) {
            Image(nsImage: TestArtwork.laptopTop)
                .resizable()
                .frame(width: size.width * unit, height: size.height * unit)

            Canvas { context, _ in
                let r = MicSpeaker.dotRadius
                for row in 0..<MicSpeaker.rows {
                    let colour = MicSpeaker.color(row: row, level: level).color
                    for x in MicSpeaker.columnX {
                        let rect = CGRect(x: (x - r) * unit, y: (MicSpeaker.y(row: row) - r) * unit, width: 2 * r * unit, height: 2 * r * unit)
                        context.fill(Path(ellipseIn: rect), with: .color(colour))
                    }
                }
            }
            .frame(width: size.width * unit, height: size.height * unit)
        }
        .frame(width: size.width * unit, height: size.height * unit, alignment: .topLeading)
    }
}

/// The trackpad from above; its middle darkens the harder you press.
struct TrackpadScene: View {
    let depth: Double
    let unit: CGFloat

    static let size = CGSize(width: 687, height: 370)

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 23 * unit)
                .fill(Color(red: 0xE7 / 255, green: 0xED / 255, blue: 0xEF / 255))
                .frame(width: Self.size.width * unit, height: Self.size.height * unit)

            RoundedRectangle(cornerRadius: 24 * unit)
                .fill(TestMotion.trackpadTint(depth: depth).color)
                .frame(width: 655 * unit, height: 335 * unit)
                .offset(x: 16 * unit, y: 16 * unit)
        }
        .frame(width: Self.size.width * unit, height: Self.size.height * unit, alignment: .topLeading)
    }
}

/// The laptop from the front, turning as the real one is tipped.
struct RotateScene: View {
    let roll: Double
    let unit: CGFloat

    var body: some View {
        let size = TestArtwork.rotateSize
        Image(nsImage: TestArtwork.rotateLaptop)
            .resizable()
            .frame(width: size.width * unit, height: size.height * unit)
            .rotationEffect(.degrees(TestMotion.rotation(forRoll: roll)))
    }
}

// MARK: - Pages

struct HingeTestPage: View {
    let state: TestState
    let onNext: () -> Void

    var body: some View {
        TestPageFrame(icon: TestArtwork.hingeIcon,
                      percent: TestMotion.hingePercent(hinge: state.hinge),
                      subtitle: "Try Moving Your Laptop’s Hinge",
                      buttonTitle: "Looks Good",
                      onButton: onNext) { layout in
            let base = TestArtwork.hingeBaseSize
            let rest = HingeScene.restCenter
            // The lid and base together are centred, and stay put while the lid turns.
            HingeScene(hinge: state.hinge, unit: layout.unit)
                .position(x: layout.size.width / 2 + (base.width / 2 - rest.x) * layout.unit,
                          y: layout.size.height * 0.433 + (base.height / 2 - rest.y) * layout.unit)
        }
    }
}

struct MicTestPage: View {
    let state: TestState
    let onNext: () -> Void

    var body: some View {
        TestPageFrame(icon: TestArtwork.micIcon,
                      percent: state.micLevel * 100,
                      subtitle: "Blow Onto the Left Speaker",
                      buttonTitle: "Looks Good",
                      onButton: onNext) { layout in
            MicScene(level: state.micLevel, unit: layout.unit)
                .position(layout.illustrationCenter)
        }
    }
}

struct TrackpadTestPage: View {
    let state: TestState
    /// Catches the trackpad press; nil when only drawing.
    var force: TrackpadForce?
    let onNext: () -> Void

    var body: some View {
        TestPageFrame(icon: TestArtwork.trackpadIcon,
                      percent: state.pressDepth * 100,
                      subtitle: "Press Down on the Trackpad",
                      buttonTitle: "Looks Good",
                      contentAllowsHits: true,
                      onButton: onNext) { layout in
            ZStack {
                // The whole window listens for the press; the drawing above it ignores the pointer.
                if let force { ForcePad(model: force) }
                TrackpadScene(depth: state.pressDepth, unit: layout.unit)
                    .allowsHitTesting(false)
                    .position(layout.illustrationCenter)
            }
        }
    }
}

struct RotateTestPage: View {
    let state: TestState
    let onFinish: () -> Void

    var body: some View {
        TestPageFrame(icon: TestArtwork.rotateIcon,
                      percent: TestMotion.rotatePercent(roll: state.roll),
                      subtitle: "Pick Up and Rotate Your Laptop",
                      buttonTitle: "Back Home",
                      onButton: onFinish) { layout in
            RotateScene(roll: state.roll, unit: layout.unit)
                .position(layout.illustrationCenter)
        }
    }
}

/// Shown while the microphone learns the room's background noise. The text hops a little to show it is working.
struct HangTightPage: View {
    let time: Double
    /// A problem to show in place of the usual hint, such as no microphone access.
    var problem: String?
    var onSkip: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            let layout = TestLayout(size: geo.size)
            let entrance = HangTightMotion.entrance(at: time)

            ZStack {
                Theme.background

                Text("Hang Tight…")
                    .font(.system(size: 35 * layout.unit, weight: .bold))
                    .foregroundStyle(Color.black)
                    .scaleEffect(0.85 + 0.15 * entrance)
                    .opacity(min(entrance * 2, 1))
                    .offset(y: -HangTightMotion.lift(at: time) * layout.unit)
                    .position(x: geo.size.width / 2, y: layout.hangTightTitleY)

                Text(problem ?? "We’re Calibrating Your Mic")
                    .font(.system(size: layout.subtitleFont))
                    .foregroundStyle(problem == nil ? Theme.subtitle : Color.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600 * layout.unit)
                    .scaleEffect(0.85 + 0.15 * entrance)
                    .opacity(min(entrance * 2, 1))
                    .offset(y: -HangTightMotion.lift(at: time, delay: HangTightMotion.subtitleDelay) * layout.unit)
                    .position(x: geo.size.width / 2, y: layout.hangTightSubtitleY)

                if problem != nil {
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.system(size: layout.buttonFont, weight: .semibold))
                            .foregroundStyle(Theme.pillText)
                            .frame(width: layout.buttonSize.width, height: layout.buttonSize.height)
                            .background(Theme.pill, in: Capsule())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .position(layout.buttonCenter)
                }
            }
        }
    }
}
