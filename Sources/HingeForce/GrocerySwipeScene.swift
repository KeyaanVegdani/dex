import AVFoundation
import SwiftUI

/// Full-bleed / centered swipe video. Paused on load; model starts playback on tilt.
struct GrocerySwipeScene: View {
    let state: GrocerySwipeSceneState
    let size: CGSize
    let player: AVPlayer?

    var body: some View {
        let side = min(size.width * 0.55, size.height * 0.58, 520)
        ZStack {
            if let player {
                SwipeVideoPlayerView(player: player)
                    .frame(width: side, height: side)
                    .position(x: size.width / 2, y: size.height * 0.46)
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

/// AVPlayerLayer hosted in an NSView so the first frame can sit paused until tilt.
private struct SwipeVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.configure(player: player)
        return view
    }

    func updateNSView(_ nsView: PlayerContainerView, context: Context) {
        nsView.configure(player: player)
    }

    final class PlayerContainerView: NSView {
        private let playerLayer = AVPlayerLayer()

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            playerLayer.videoGravity = .resizeAspect
            layer?.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func configure(player: AVPlayer) {
            if playerLayer.player !== player {
                playerLayer.player = player
            }
        }

        override func layout() {
            super.layout()
            playerLayer.frame = bounds
        }
    }
}
