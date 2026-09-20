import SwiftUI

/// The stretch transition between lessons. The outgoing page's artwork stretches slightly taller,
/// easing in so it accelerates; at the peak the pages swap and the incoming artwork starts out just as
/// stretched, then settles back to normal, easing out. Everything is a pure function of the
/// seconds elapsed, so it can be tested and rendered frame by frame.
enum PageTransition {
    /// How tall the artwork is stretched at the moment of the swap, as a multiple of its height (6% taller).
    static let peakStretch = 1.06
    static let outDuration: TimeInterval = 0.25
    static let inDuration: TimeInterval = 0.4
    /// The outgoing page's caption, bar and button fade over this long, at the start.
    static let chromeFadeDuration: TimeInterval = 0.15

    /// Vertical scale of the outgoing artwork, `t` seconds after the transition starts (ease-in).
    static func outgoingStretch(at t: TimeInterval) -> Double {
        let x = LessonIntro.progress(t, 0, outDuration)
        return 1 + (peakStretch - 1) * x * x * x
    }

    /// Vertical scale of the incoming artwork, `t` seconds after the swap (ease-out).
    static func incomingStretch(at t: TimeInterval) -> Double {
        let x = LessonIntro.progress(t, 0, inDuration)
        return 1 + (peakStretch - 1) * pow(1 - x, 3)
    }

    static func outgoingChromeOpacity(at t: TimeInterval) -> Double {
        1 - LessonIntro.progress(t, 0, chromeFadeDuration)
    }
}

/// What the lesson pages need to draw a frame of the transition.
struct PageTransitionState: Equatable {
    var stretch = 1.0
    var chromeOpacity = 1.0
}

private struct PageTransitionKey: EnvironmentKey {
    static let defaultValue = PageTransitionState()
}

extension EnvironmentValues {
    /// Set by the root view while one lesson hands over to the next.
    var pageTransition: PageTransitionState {
        get { self[PageTransitionKey.self] }
        set { self[PageTransitionKey.self] = newValue }
    }
}

/// Runs the transition on a 60 fps clock and swaps pages at the peak.
@MainActor
final class PageTransitionDriver: ObservableObject {
    @Published private(set) var state = PageTransitionState()
    private(set) var isRunning = false
    private var timer: Timer?

    /// Starts the transition; `swap` is called once, at the peak, to change the page.
    func run(swap: @escaping () -> Void) {
        guard !isRunning else { return }
        isRunning = true

        let start = Date()
        var swapped = false
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(start)

                if elapsed < PageTransition.outDuration {
                    self.state = PageTransitionState(stretch: PageTransition.outgoingStretch(at: elapsed),
                                                     chromeOpacity: PageTransition.outgoingChromeOpacity(at: elapsed))
                    return
                }

                if !swapped {
                    swapped = true
                    swap()
                }
                let sinceSwap = elapsed - PageTransition.outDuration
                if sinceSwap < PageTransition.inDuration {
                    self.state = PageTransitionState(stretch: PageTransition.incomingStretch(at: sinceSwap), chromeOpacity: 1)
                } else {
                    self.state = PageTransitionState()
                    self.timer?.invalidate()
                    self.timer = nil
                    self.isRunning = false
                }
            }
        }
    }
}
