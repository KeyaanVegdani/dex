import AVFoundation
import SwiftUI

/// Full-bleed swipe video (aspect-fill). Paused on load; model starts playback on tilt.
struct GrocerySwipeScene: View {
    let state: GrocerySwipeSceneState
    let size: CGSize
    let player: AVPlayer?

    var body: some View {
        ZStack {
            if let player {
                SwipeVideoPlayerView(player: player)
                    .frame(width: size.width, height: size.height)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// AVPlayerLayer hosted in an NSView — aspect-fill so the video covers the whole screen.
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
            playerLayer.videoGravity = .resizeAspectFill
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
