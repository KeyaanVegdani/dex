import SwiftUI

/// A colour as plain red, green and blue numbers (0...1), so it can be blended and tested.
struct RGB: Equatable {
    var r: Double, g: Double, b: Double

    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }

    init(hex: UInt32) {
        self.init(Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }

    /// Blends from this colour to `other`: 0 gives this colour, 1 gives `other`.
    func mixed(with other: RGB, _ amount: Double) -> RGB {
        let t = min(max(amount, 0), 1)
        return RGB(r + (other.r - r) * t, g + (other.g - g) * t, b + (other.b - b) * t)
    }

    var color: Color { Color(red: r, green: g, blue: b) }
}

/// How the Test System pages turn sensor readings into what is drawn and shown.
enum TestMotion {
    // MARK: Hinge

    /// The hinge angle at which the lid is drawn exactly as in its artwork and the page reads 50%.
    static let defaultHinge = 100.0
    /// The lid is drawn over this stretch of hinge angles, however far the real hinge goes.
    static let hingeDrawRange: ClosedRange<Double> = 30...150

    /// Degrees (clockwise positive, as SwiftUI turns things) to turn the lid artwork by. The artwork is drawn at
    /// `defaultHinge`, and opening the hinge further leans the lid back, which is anticlockwise.
    static func lidRotation(hinge: Double) -> Double {
        let clamped = min(max(hinge, hingeDrawRange.lowerBound), hingeDrawRange.upperBound)
        return -(clamped - defaultHinge)
    }

    /// The percentage shown for a hinge angle: the same `hinge_reading` scale used throughout the app.
    static func hingePercent(hinge: Double) -> Double {
        ReadingMap.hinge(angle: hinge)
    }

    // MARK: Microphone

    /// Loudness 0...1 from a blow reading (1...10).
    static func micLevel(reading: Double) -> Double {
        min(max((reading - 1) / 9, 0), 1)
    }

    // MARK: Trackpad

    static let trackpadRest = RGB(hex: 0xDAE3E6)
    static let trackpadFullPress = RGB(hex: 0xBECBD0)

    /// The trackpad's centre darkens from its resting colour to `#BECBD0` as the press deepens (0...1).
    static func trackpadTint(depth: Double) -> RGB {
        trackpadRest.mixed(with: trackpadFullPress, depth)
    }

    // MARK: Rotation

    /// Tilt at which the rotation reads 100%.
    static let fullTilt = 45.0
    /// Set to -1 if the drawn laptop should turn the other way when the real one is tipped.
    static let rotationDirection = 1.0

    static func rotatePercent(roll: Double) -> Double {
        min(abs(roll) / fullTilt, 1) * 100
    }

    /// Degrees clockwise to turn the drawn laptop by for a real roll (positive when its right side is lower).
    static func rotation(forRoll roll: Double) -> Double {
        min(max(roll, -90), 90) * rotationDirection
    }
}

/// The colours of the left speaker's dots: a gradient from top to bottom that shifts towards red as it gets louder.
enum MicSpeaker {
    static let rows = 12
    static let columns = 4
    /// Dot centres on the laptop artwork: 4 columns and 12 rows, 6 units in radius.
    static let columnX: [Double] = [22, 37.6, 53.2, 68.8]
    static let firstRowY = 42.0
    static let rowSpacing = 17.0
    static let dotRadius = 6.0

    static let calmTop = RGB(hex: 0x4126EF), calmBottom = RGB(hex: 0x38B1DD)
    static let loudTop = RGB(hex: 0xE0192E), loudBottom = RGB(hex: 0xFF7A3D)

    static func y(row: Int) -> Double { firstRowY + Double(row) * rowSpacing }

    /// A dot's colour: `row` 0 is the top, `level` is loudness 0...1.
    static func color(row: Int, level: Double) -> RGB {
        let top = calmTop.mixed(with: loudTop, level)
        let bottom = calmBottom.mixed(with: loudBottom, level)
        return top.mixed(with: bottom, Double(row) / Double(rows - 1))
    }
}

/// The small bounce of the "Hang tight" screen: text hops up and lands like a ball, over and over.
enum HangTightMotion {
    static let hopHeight = 9.0
    static let hopsPerSecond = 1.1
    /// The subtitle follows the title by a beat.
    static let subtitleDelay = 0.14

    /// How far above its resting place the text is, in points-per-unit multiples; never below rest.
    static func lift(at time: Double, delay: Double = 0) -> Double {
        let t = max(time - delay, 0)
        return hopHeight * abs(sin(.pi * hopsPerSecond * t))
    }

    /// The text pops in when the page appears.
    static func entrance(at time: Double) -> Double {
        LessonIntro.spring(time, start: 0, duration: 0.7, damping: 0.55)
    }
}

/// Where everything sits on a Test System page. The numbers come from the design at 2000 x 1290, where the
/// artwork is drawn 1.32 times its SVG size.
struct TestLayout: Equatable {
    let size: CGSize
    let unit: CGFloat
    let illustrationCenter: CGPoint
    let readoutY: CGFloat
    let subtitleY: CGFloat
    let buttonCenter: CGPoint
    let buttonSize: CGSize
    let percentFont: CGFloat
    let subtitleFont: CGFloat
    let buttonFont: CGFloat
    let hangTightTitleY: CGFloat
    let hangTightSubtitleY: CGFloat

    init(size: CGSize) {
        self.size = size
        let u = min(size.width * 0.00066, size.height * 0.001023)
        unit = u
        illustrationCenter = CGPoint(x: size.width / 2, y: size.height * 0.455)
        readoutY = size.height * 0.758
        subtitleY = size.height * 0.802
        buttonCenter = CGPoint(x: size.width / 2, y: size.height * 0.879)
        buttonSize = CGSize(width: 212 * u, height: 53 * u)
        percentFont = 38 * u
        subtitleFont = 20 * u
        buttonFont = 24 * u
        hangTightTitleY = size.height * 0.48
        hangTightSubtitleY = size.height * 0.53
    }
}
