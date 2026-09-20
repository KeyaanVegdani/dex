import Foundation

/// The home screen's motion, as pure functions.
///
/// On load, in order: the burst behind everything and the title fade in, the book fades and slides up from the
/// bottom, the cake grows in with an overshoot, and lastly the top navigation and bottom button fade in.
/// Once it is all in, the burst and the book sway back and forth in opposite directions.
enum HomeMotion {
    // MARK: Idle sway

    /// Seconds for the burst and book to sway to one side, the other, and back.
    static let swingPeriod = 6.5
    /// How far the burst swings either way about its bottom edge, in degrees.
    static let burstSwing = 2.2
    /// How far the book swings the opposite way, more gently.
    static let bookSwing = 1.4

    /// `activeTime` only advances while nothing is paused (see `HomeClock`).
    static func burstAngle(activeTime: Double) -> Double {
        burstSwing * sin(2 * .pi * activeTime / swingPeriod)
    }

    static func bookAngle(activeTime: Double) -> Double {
        -bookSwing * sin(2 * .pi * activeTime / swingPeriod)
    }

    // MARK: Load animation (seconds since the page appeared)

    static let introDuration = 2.0

    static func burstOpacity(at t: Double) -> Double {
        LessonIntro.easeOutCubic(LessonIntro.progress(t, 0, 0.7))
    }

    static func titleOpacity(at t: Double) -> Double {
        LessonIntro.easeOutCubic(LessonIntro.progress(t, 0.1, 0.6))
    }

    static func bookOpacity(at t: Double) -> Double {
        LessonIntro.progress(t, 0.25, 0.7)
    }

    /// 1 when the book is fully below its place, 0 once it has slid up into it.
    static func bookSlide(at t: Double) -> Double {
        1 - LessonIntro.easeOutCubic(LessonIntro.progress(t, 0.25, 1.05))
    }

    /// How far below its place the book starts, in layout units.
    static let bookSlideDistance = 90.0

    /// The cake grows from nothing, overshoots its size a little, and settles.
    static func cakeScale(at t: Double) -> Double {
        LessonIntro.spring(t, start: 0.75, duration: 0.9, damping: 0.5)
    }

    /// The top navigation and the bottom button, once everything else is in.
    static func chromeOpacity(at t: Double) -> Double {
        LessonIntro.progress(t, 1.6, 2.0)
    }

    // MARK: Hover

    static let hoverScale = 1.05
    /// How far the book lifts on hover, in layout units.
    static let hoverLift = 16.0
}

/// The home screen's two clocks. `elapsed` always runs and drives the load animation; `activeTime` stops while
/// the pointer is over the book, which is what pauses the sway, and picks up again from the same angle afterwards.
struct HomeClock: Equatable {
    var elapsed = 0.0
    var activeTime = 0.0

    mutating func advance(by dt: Double, paused: Bool) {
        elapsed += dt
        if !paused { activeTime += dt }
    }
}

/// Where everything sits on the home screen for a window size. One scale (`unit`) sets the size of all the
/// artwork, taken from the design, where the book is about 590 px wide in a 2000 px window.
struct HomeLayout: Equatable {
    let size: CGSize
    /// Points per artwork unit.
    let unit: CGFloat
    let titleFont: CGFloat
    let titleCenterY: CGFloat
    /// The centre of the book's canvas.
    let bookCenter: CGPoint
    let buttonCenter: CGPoint
    let buttonSize: CGSize
    let navFont: CGFloat

    init(size: CGSize) {
        self.size = size
        let unit = min(size.width * 0.00066, size.height * 0.001015)
        self.unit = unit
        titleFont = min(size.width * 0.031, size.height * 0.0477)
        titleCenterY = size.height * 0.215
        bookCenter = CGPoint(x: size.width / 2, y: size.height * 0.551)
        buttonCenter = CGPoint(x: size.width / 2, y: size.height * 0.894)
        buttonSize = CGSize(width: 267 * unit, height: 53 * unit)
        navFont = max(15, 17 * unit)
    }

    var bookOrigin: CGPoint {
        CGPoint(x: bookCenter.x - HomeArtwork.bookSize.width / 2 * unit,
                y: bookCenter.y - HomeArtwork.bookSize.height / 2 * unit)
    }

    /// The burst sits behind the book, its top-left up and to the left of the book's.
    var burstOrigin: CGPoint {
        CGPoint(x: bookOrigin.x - 190 * unit, y: bookOrigin.y - 135 * unit)
    }

    var bookRect: CGRect {
        CGRect(x: bookOrigin.x, y: bookOrigin.y,
               width: HomeArtwork.bookSize.width * unit, height: HomeArtwork.bookSize.height * unit)
    }
}
