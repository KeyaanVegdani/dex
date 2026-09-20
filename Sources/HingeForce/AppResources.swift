import AppKit
import Foundation

/// Resolves the SPM resource bundle both under `swift run` and inside HingeForce.app.
enum AppResources {
    static var bundle: Bundle {
        if let resources = Bundle.main.resourceURL {
            let packaged = resources.appendingPathComponent("HingeForce_HingeForce.bundle")
            if let bundle = Bundle(path: packaged.path) {
                return bundle
            }
        }
        return .module
    }

    static func image(_ name: String) -> NSImage {
        if let url = bundle.url(forResource: name, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSImage(size: NSSize(width: 1, height: 1))
    }

    /// Swipe-to-pay video. Ships `swipe.webm` (Jane’s source); AVFoundation playback uses
    /// the bundled `swipe.mp4` twin when present, since macOS AVPlayer does not decode WebM.
    static func swipeVideoURL() -> URL? {
        if let mp4 = bundle.url(forResource: "swipe", withExtension: "mp4") {
            return mp4
        }
        return bundle.url(forResource: "swipe", withExtension: "webm")
    }
}
