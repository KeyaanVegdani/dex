import SwiftUI

@main
struct HingeForceApp: App {
    @StateObject private var mic = MicMonitor()
    @StateObject private var lid = LidAngleSensor()
    @StateObject private var force = TrackpadForce()
    @StateObject private var accelerometer = Accelerometer()

    init() {
        // Lets the app show a window and take focus when launched via `swift run`.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        Window("Hinge & Force", id: "main") {
            RootView(mic: mic, lid: lid, force: force, accelerometer: accelerometer)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(NSScreen.main?.visibleFrame.size ?? CGSize(width: 1280, height: 800))
    }
}
