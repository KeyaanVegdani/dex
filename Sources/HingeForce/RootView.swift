import SwiftUI

struct RootView: View {
    private enum Page { case start, lesson, cut, press, next }

    @ObservedObject var mic: MicMonitor
    @ObservedObject var lid: LidAngleSensor
    @ObservedObject var force: TrackpadForce
    @State private var page: Page = .start
    /// Bumped to give the lessons a fresh start (new intro, new timers, a new cut line) when redone.
    @State private var lessonRun = 0
    @StateObject private var transition = PageTransitionDriver()

    var body: some View {
        ZStack {
            switch page {
            case .start:
                StartView { go(to: .lesson) }
                    .transition(.opacity)
            case .lesson:
                LessonView(mic: mic) { stretch(to: .cut) }
                    .id(lessonRun)
                    .transition(.opacity)
            case .cut:
                CutLessonView(lid: lid) { stretch(to: .press) }
                    .id(lessonRun)
                    .transition(.opacity)
            case .press:
                PressLessonView(force: force) { go(to: .next) }
                    .id(lessonRun)
                    .transition(.opacity)
            case .next:
                RedoView {
                    lessonRun += 1
                    go(to: .lesson)
                }
                .transition(.opacity)
            }
        }
        .frame(minWidth: 900, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
        .background(Theme.background)
        .environment(\.pageTransition, transition.state)
        .background(WindowSizer())
        .preferredColorScheme(.light)
    }
}

extension RootView {
    /// Cross-fades to another page.
    private func go(to next: Page) {
        withAnimation(.easeOut(duration: 0.2)) { page = next }
    }

    /// Hands over to another lesson with the vertical stretch: the page is swapped instantly, at the
    /// moment the outgoing artwork is at its most stretched, so the new artwork snaps in from there.
    private func stretch(to next: Page) {
        transition.run {
            var swap = Transaction()
            swap.disablesAnimations = true
            withTransaction(swap) { page = next }
        }
    }
}

/// Sizes the hosting window to fill the screen's usable area when it first appears.
private struct WindowSizer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { SizerView() }
    func updateNSView(_ view: NSView, context: Context) {}

    private final class SizerView: NSView {
        override func viewDidMoveToWindow() {
            guard let window, let screen = window.screen ?? NSScreen.main else { return }
            DispatchQueue.main.async {
                window.setFrame(screen.visibleFrame, display: true)
            }
        }
    }
}
