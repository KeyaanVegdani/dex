import SwiftUI

/// The chrome every lesson page shares: the progress bar, a caption, and a Continue button that
/// pops up once the activity is done. The lesson's own artwork goes in `content`, which is given
/// the page size and positions itself.
struct LessonScaffold<Content: View>: View {
    let currentSegment: Int
    /// Seconds since the page appeared; drives the bar and caption entrance.
    let introTime: Double
    /// Seconds since the activity was completed, or nil while it is still going.
    let outroElapsed: Double?
    let title: String
    let subtitle: String
    var subtitleIsProblem = false
    /// The label on the button that appears when the activity is done.
    var continueTitle = "Continue"
    /// When (in outro seconds) the Continue button starts to appear.
    var continueStart = LessonOutro.continueStart
    /// Whether the artwork can receive clicks. Off by default; lessons that listen for the trackpad turn it on.
    var contentAllowsHits = false
    var onContinue: () -> Void = {}
    @ViewBuilder let content: (CGSize) -> Content

    @Environment(\.pageTransition) private var transition

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.background

                // The artwork stretches about the centre of the screen during a lesson-to-lesson transition.
                content(geo.size)
                    .scaleEffect(x: 1, y: transition.stretch, anchor: .center)
                    .allowsHitTesting(contentAllowsHits)

                VStack {
                    LessonProgressBar(segments: 4, current: currentSegment,
                                      expansion: LessonIntro.barExpansion(at: introTime),
                                      completion: LessonOutro.barCompletion(elapsed: outroElapsed))
                        .padding(.top, 64)
                        .allowsHitTesting(false)
                    Spacer()
                    ZStack {
                        caption.allowsHitTesting(false)
                        continueButton
                    }
                    .frame(height: 100)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 90)
                }
                .opacity(transition.chromeOpacity)
            }
        }
    }

    private var caption: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(Theme.headingFont)
                .foregroundStyle(Theme.title)
            Text(subtitle)
                .font(.system(size: 22))
                .foregroundStyle(subtitleIsProblem ? Color.red : Theme.subtitle)
        }
        .multilineTextAlignment(.center)
        .offset(y: 36 * (1 - LessonIntro.textReveal(at: introTime)))
        .opacity(LessonIntro.textReveal(at: introTime) * LessonOutro.captionOpacity(elapsed: outroElapsed))
    }

    /// Fades and pops up from the bottom once the activity is complete.
    private var continueButton: some View {
        let rise = LessonOutro.continueRise(elapsed: outroElapsed, start: continueStart)
        return PillButton(title: continueTitle, style: .secondary, action: onContinue)
            .keyboardShortcut(.defaultAction)
            .offset(y: 90 * (1 - rise))
            .scaleEffect(0.9 + 0.1 * rise)
            .opacity(LessonOutro.continueOpacity(elapsed: outroElapsed, start: continueStart))
            .allowsHitTesting(LessonOutro.isContinueEnabled(elapsed: outroElapsed, start: continueStart))
    }
}
