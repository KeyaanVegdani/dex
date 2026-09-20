import Foundation

/// What happens after the candles are blown out, as pure functions of the seconds since then
/// (`nil` while the candles are still lit):
/// the flames vanish (see `CandleScene`), a smoke wisp is drawn up from each candle, the progress
/// segment turns green, the caption fades away, and a Continue button pops up from the bottom.
enum LessonOutro {
    /// Smoke starts once the flame is mostly gone, left candle first like the wind.
    private static let smokeStart = 0.25
    private static let smokeStagger = 0.09
    private static let smokeDuration = 0.8

    /// When the Continue button starts to appear (as the last wisp finishes), and when it can be pressed.
    static let continueStart = smokeStart + 2 * smokeStagger + smokeDuration
    /// The button becomes pressable this long after it starts to appear.
    static let continueEnabledDelay = 0.15

    /// 0...1: how much of a candle's smoke wisp has been drawn.
    static func smokeProgress(candle: Int, elapsed: Double?) -> Double {
        guard let elapsed else { return 0 }
        let start = smokeStart + smokeStagger * Double(candle)
        return LessonIntro.easeInOut(LessonIntro.progress(elapsed, start, start + smokeDuration))
    }

    /// 1 while the caption is showing, fading to 0 as the candles go out.
    static func captionOpacity(elapsed: Double?) -> Double {
        guard let elapsed else { return 1 }
        return 1 - LessonIntro.progress(elapsed, 0, 0.25)
    }

    /// 0...1: how far the progress segment has turned green.
    static func barCompletion(elapsed: Double?) -> Double {
        guard let elapsed else { return 0 }
        return LessonIntro.easeOutCubic(LessonIntro.progress(elapsed, 0.1, 0.5))
    }

    /// Rises from 0 to 1 with a small overshoot: drives the Continue button sliding up and popping.
    static func continueRise(elapsed: Double?, start: Double = continueStart) -> Double {
        guard let elapsed else { return 0 }
        return LessonIntro.spring(elapsed, start: start, duration: 0.6, damping: 0.65)
    }

    static func continueOpacity(elapsed: Double?, start: Double = continueStart) -> Double {
        guard let elapsed else { return 0 }
        return LessonIntro.progress(elapsed, start, start + 0.25)
    }

    static func isContinueEnabled(elapsed: Double?, start: Double = continueStart) -> Bool {
        guard let elapsed else { return false }
        return elapsed >= start + continueEnabledDelay
    }
}
