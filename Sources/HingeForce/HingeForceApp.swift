import SwiftUI

@main
struct HingeForceApp: App {
    @StateObject private var lid = LidAngleSensor()
    @StateObject private var force = TrackpadForce()

    init() {
        // Lets the app show a window and take focus when launched via `swift run`.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        Window("Hinge & Force", id: "main") {
            ContentView(lid: lid, force: force)
                .onAppear { lid.start() }
        }
        .windowResizability(.contentSize)
    }
}
