import SwiftUI

/// The home screen for a given moment: everything is drawn from `clock` and `isHoveringBook`.
struct HomePage: View {
    let clock: HomeClock
    var isHoveringBook = false
    var userName = "Harry"
    var onBookHover: (Bool) -> Void = { _ in }
    var onStartPractice: () -> Void = {}
    var onTest: () -> Void = {}
    var onHistory: () -> Void = {}

    private static let background = LinearGradient(
        stops: [
            .init(color: Color(red: 0.839, green: 0.894, blue: 1.0), location: 0.0),
            .init(color: Color(red: 0.906, green: 0.902, blue: 0.988), location: 0.12),
            .init(color: Color(red: 0.965, green: 0.922, blue: 0.984), location: 0.22),
            .init(color: Color(red: 0.992, green: 0.965, blue: 0.992), location: 0.32),
            .init(color: .white, location: 0.40),
        ],
        startPoint: .top, endPoint: .bottom)

    var body: some View {
        GeometryReader { geo in
            let layout = HomeLayout(size: geo.size)
            let t = clock.elapsed

            ZStack(alignment: .topLeading) {
                Self.background.ignoresSafeArea()

                burst(layout, t)

                Text("Your Daily Practice is\nHere \(userName)!")
                    .font(.system(size: layout.titleFont, weight: .bold))
                    .foregroundStyle(Color.black)
                    .multilineTextAlignment(.center)
                    .lineSpacing(layout.titleFont * 0.08)
                    .position(x: geo.size.width / 2, y: layout.titleCenterY)
                    .opacity(HomeMotion.titleOpacity(at: t))
                    .allowsHitTesting(false)

                book(layout, t)

                nav(layout)
                    .opacity(HomeMotion.chromeOpacity(at: t))

                testButton(layout)
                    .opacity(HomeMotion.chromeOpacity(at: t))
            }
        }
    }

    // MARK: - Pieces

    /// The flower shape behind the book, swaying about its bottom edge.
    private func burst(_ layout: HomeLayout, _ t: Double) -> some View {
        let size = HomeArtwork.burstSize
        return Image(nsImage: HomeArtwork.burst)
            .resizable()
            .frame(width: size.width * layout.unit, height: size.height * layout.unit)
            .rotationEffect(.degrees(HomeMotion.burstAngle(activeTime: clock.activeTime)), anchor: .bottom)
            .opacity(HomeMotion.burstOpacity(at: t))
            .offset(x: layout.burstOrigin.x, y: layout.burstOrigin.y)
            .allowsHitTesting(false)
    }

    /// The book with its cake. It sways opposite to the burst, and on hover it grows, lifts and holds still.
    /// Hover is detected on a fixed frame around it, so the book growing or lifting away from the pointer
    /// can't flip it in and out of hover at its edges.
    private func book(_ layout: HomeLayout, _ t: Double) -> some View {
        let size = HomeArtwork.bookSize
        let cake = HomeArtwork.cakeCenter
        let slide = HomeMotion.bookSlide(at: t) * HomeMotion.bookSlideDistance * layout.unit
        let frame = CGSize(width: size.width * layout.unit, height: size.height * layout.unit)

        return ZStack {
            Button(action: onStartPractice) {
                ZStack(alignment: .topLeading) {
                    Image(nsImage: HomeArtwork.book)
                        .resizable()
                        .frame(width: frame.width, height: frame.height)

                    Image(nsImage: HomeArtwork.cake)
                        .resizable()
                        .frame(width: frame.width, height: frame.height)
                        .scaleEffect(HomeMotion.cakeScale(at: t),
                                     anchor: UnitPoint(x: cake.x / size.width, y: cake.y / size.height))
                }
                .frame(width: frame.width, height: frame.height, alignment: .topLeading)
                .contentShape(Rectangle())
                .rotationEffect(.degrees(HomeMotion.bookAngle(activeTime: clock.activeTime)), anchor: .bottom)
            }
            .buttonStyle(SoundPlainButtonStyle())
            .scaleEffect(isHoveringBook ? HomeMotion.hoverScale : 1)
            .offset(y: isHoveringBook ? -HomeMotion.hoverLift * layout.unit : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.68), value: isHoveringBook)
            .accessibilityLabel("Start today's practice")
        }
        .frame(width: frame.width, height: frame.height)
        .contentShape(Rectangle())
        .onHover(perform: onBookHover)
        .opacity(HomeMotion.bookOpacity(at: t))
        .offset(x: layout.bookOrigin.x, y: layout.bookOrigin.y + slide)
    }

    private func nav(_ layout: HomeLayout) -> some View {
        let logo = HomeArtwork.logoSize
        return ZStack(alignment: .topLeading) {
            Image(nsImage: HomeArtwork.logo)
                .resizable()
                .frame(width: logo.width * layout.unit * 1.02, height: logo.height * layout.unit * 1.02)
                .offset(x: 34, y: 40)
                .allowsHitTesting(false)

            Button(action: onHistory) {
                Text("History")
                    .font(.system(size: layout.navFont))
                    .foregroundStyle(Color(white: 0.27))
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SoundPlainButtonStyle())
            .position(x: layout.size.width - 34 - 30, y: 56)
        }
    }

    private func testButton(_ layout: HomeLayout) -> some View {
        Button(action: onTest) {
            HStack(spacing: 14 * layout.unit) {
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 26 * layout.unit, weight: .regular))
                Text("Test System")
                    .font(.system(size: 24 * layout.unit, weight: .semibold))
            }
            .foregroundStyle(Theme.pillText)
            .frame(width: layout.buttonSize.width, height: layout.buttonSize.height)
            .background(Theme.pill, in: Capsule())
        }
        .buttonStyle(HomePressStyle())
        .position(layout.buttonCenter)
    }
}

private struct HomePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .modifier(PressSound(isPressed: configuration.isPressed))
    }
}

/// The home screen. It runs its own 60 fps clock and stops the sway while the pointer is over the book.
struct HomeView: View {
    let onStartPractice: () -> Void
    let onTest: () -> Void
    let onHistory: () -> Void

    @State private var clock = HomeClock()
    @State private var isHoveringBook = false
    @State private var timer: Timer?
    @State private var lastTick = Date()

    var body: some View {
        HomePage(clock: clock,
                 isHoveringBook: isHoveringBook,
                 onBookHover: { hovering in
                     isHoveringBook = hovering
                     if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                 },
                 onStartPractice: onStartPractice,
                 onTest: onTest,
                 onHistory: onHistory)
            .onAppear { startClock() }
            .onDisappear {
                timer?.invalidate()
                timer = nil
                if isHoveringBook { NSCursor.pop() }
            }
    }

    private func startClock() {
        guard timer == nil else { return }
        lastTick = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            let now = Date()
            let dt = min(now.timeIntervalSince(lastTick), 0.1)
            lastTick = now
            clock.advance(by: dt, paused: isHoveringBook)
        }
    }
}

/// A page with nothing on it yet, and a way back home.
struct BlankPage: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.background
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: 17))
                .foregroundStyle(Color(white: 0.27))
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(SoundPlainButtonStyle())
            .padding(.leading, 26)
            .padding(.top, 34)
        }
        .accessibilityLabel(title)
    }
}
