import AppKit
import SwiftUI

/// Latest pressure reading from a Force Touch trackpad.
///
/// macOS only reports trackpad force while the button is being clicked, and only to
/// the view under the cursor, so readings come from `ForcePad` below.
@MainActor
final class TrackpadForce: ObservableObject {
    /// Nominal range of `NSEvent.pressure`.
    static let range: ClosedRange<Float> = 0...1

    @Published private(set) var pressure: Float = 0
    @Published private(set) var stage: Int = 0
    @Published private(set) var peak: Float = 0
    @Published private(set) var isPressed = false

    func update(from event: NSEvent, pressed: Bool) {
        pressure = event.pressure
        stage = event.stage
        isPressed = pressed
        peak = max(peak, event.pressure)
    }

    func release() {
        pressure = 0
        stage = 0
        isPressed = false
    }

    func resetPeak() {
        peak = pressure
    }
}

/// A view that captures click pressure and forwards it to a `TrackpadForce` model.
struct ForcePad: NSViewRepresentable {
    let model: TrackpadForce

    func makeNSView(context: Context) -> ForcePadView {
        let view = ForcePadView()
        view.model = model
        return view
    }

    func updateNSView(_ view: ForcePadView, context: Context) {
        view.model = model
    }
}

final class ForcePadView: NSView {
    var model: TrackpadForce?

    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) { model?.update(from: event, pressed: true) }
    override func mouseDragged(with event: NSEvent) { model?.update(from: event, pressed: true) }
    override func pressureChange(with event: NSEvent) { model?.update(from: event, pressed: true) }
    override func mouseUp(with event: NSEvent) { model?.release() }
}
