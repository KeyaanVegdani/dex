import AppKit
import SwiftUI

/// Latest pressure reading from a Force Touch trackpad.
///
/// macOS only reports trackpad force while the button is being clicked, and only to
/// the view under the cursor, so readings come from `ForcePad` below.
///
/// The first moments of a click are noisy: the mouse-down event carries its own pressure
/// value and the first pressure events jump around. Only pressure-change events that
/// arrive at least `settleDuration` after the mouse-down are used.
@MainActor
final class TrackpadForce: ObservableObject {
    /// Nominal range of `NSEvent.pressure`.
    static let range: ClosedRange<Float> = 0...1
    /// How long after mouse-down pressure events are ignored, in seconds.
    static let settleDuration: TimeInterval = 0.12

    @Published private(set) var pressure: Float = 0
    @Published private(set) var stage: Int = 0
    @Published private(set) var peak: Float = 0
    @Published private(set) var isPressed = false
    /// Press location in the ForcePad, normalized 0...1 with origin at the top-left (SwiftUI space).
    @Published private(set) var locationNorm: CGPoint?

    private var pressStart: TimeInterval?

    /// `pressure_reading`: settled pressure mapped onto 1...10 (1 when not pressing).
    var pressureReading: Double { ReadingMap.pressure(pressure) }

    func begin(at timestamp: TimeInterval, locationNorm: CGPoint? = nil) {
        pressStart = timestamp
        pressure = 0
        stage = 0
        isPressed = true
        self.locationNorm = locationNorm.map(Self.clampUnit)
    }

    func update(from event: NSEvent) {
        guard isPressed, let start = pressStart,
              event.timestamp - start >= Self.settleDuration else { return }
        pressure = event.pressure
        stage = event.stage
        peak = max(peak, event.pressure)
    }

    /// Update the normalized press point while dragging (still top-left origin).
    func move(locationNorm: CGPoint) {
        guard isPressed else { return }
        self.locationNorm = Self.clampUnit(locationNorm)
    }

    func release() {
        pressStart = nil
        pressure = 0
        stage = 0
        isPressed = false
        locationNorm = nil
    }

    func resetPeak() {
        peak = pressure
    }

    private static func clampUnit(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, 0), 1), y: min(max(p.y, 0), 1))
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

    override func mouseDown(with event: NSEvent) {
        model?.begin(at: event.timestamp, locationNorm: normalized(from: event))
    }

    override func mouseDragged(with event: NSEvent) {
        model?.move(locationNorm: normalized(from: event))
        // Some trackpads keep sending pressure with drag.
        model?.update(from: event)
    }

    override func pressureChange(with event: NSEvent) {
        model?.update(from: event)
        model?.move(locationNorm: normalized(from: event))
    }

    override func mouseUp(with event: NSEvent) { model?.release() }

    /// NSView coords are bottom-left; convert to top-left unit space for SwiftUI overlays.
    private func normalized(from event: NSEvent) -> CGPoint {
        let p = convert(event.locationInWindow, from: nil)
        let w = max(bounds.width, 1)
        let h = max(bounds.height, 1)
        return CGPoint(x: p.x / w, y: 1 - p.y / h)
    }
}
