import Foundation
import IOKit.hid

/// Reads the MacBook's lid (hinge) angle from the built-in Apple SPU HID sensor
/// (vendor 0x05AC, product 0x8104, usage page 0x20 / usage 0x8A).
///
/// The sensor's HID report descriptor declares report ID 1 as a 9-bit value
/// spanning 0...360 degrees, so a read returns `[reportID, lo, hi]`.
@MainActor
final class LidAngleSensor: ObservableObject {
    enum Status: Equatable {
        case searching
        case running
        case unavailable(String)
    }

    /// The range the sensor can report, in degrees.
    static let range: ClosedRange<Double> = 0...360

    @Published private(set) var angle: Double?
    @Published private(set) var minSeen: Double?
    @Published private(set) var maxSeen: Double?
    @Published private(set) var status: Status = .searching

    /// `hinge_reading`: the angle mapped through `ReadingMap.hinge` (0...100).
    var hingeReading: Double? { angle.map(ReadingMap.hinge(angle:)) }

    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var timer: Timer?
    private var ticksUntilSearch = 0

    private static let pollInterval: TimeInterval = 1.0 / 30.0
    private static let searchIntervalTicks = 30

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let device { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }
        if let manager { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        device = nil
        manager = nil
        // Forget the old reading, so the next start begins fresh.
        angle = nil
        status = .searching
    }

    func resetObservedRange() {
        minSeen = angle
        maxSeen = angle
    }

    // MARK: - Polling

    private func poll() {
        if device == nil {
            if ticksUntilSearch > 0 {
                ticksUntilSearch -= 1
                return
            }
            ticksUntilSearch = Self.searchIntervalTicks
            connect()
        }
        guard let device else { return }

        guard let reading = Self.readAngle(from: device) else {
            // Device went away (or the read failed); drop it and search again.
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            self.device = nil
            angle = nil
            status = .searching
            return
        }

        angle = reading
        minSeen = min(minSeen ?? reading, reading)
        maxSeen = max(maxSeen ?? reading, reading)
    }

    private func connect() {
        let manager = self.manager ?? {
            let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
            let matching: [String: Any] = [
                kIOHIDVendorIDKey as String: 0x05AC,
                kIOHIDProductIDKey as String: 0x8104,
                kIOHIDPrimaryUsagePageKey as String: 0x20,
                kIOHIDPrimaryUsageKey as String: 0x8A,
            ]
            IOHIDManagerSetDeviceMatching(m, matching as CFDictionary)
            self.manager = m
            return m
        }()

        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            status = .unavailable("Could not open HID manager (IOReturn 0x\(String(UInt32(bitPattern: openResult), radix: 16)))")
            return
        }

        guard let candidate = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>)?.first else {
            status = .unavailable("No lid angle sensor found. This Mac may not have one.")
            return
        }

        guard IOHIDDeviceOpen(candidate, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            status = .unavailable("Found the lid angle sensor but could not open it.")
            return
        }

        device = candidate
        status = .running
    }

    private static func readAngle(from device: IOHIDDevice) -> Double? {
        var report = [UInt8](repeating: 0, count: 8)
        var length = report.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length)
        guard result == kIOReturnSuccess, length >= 3 else { return nil }

        let raw = (UInt16(report[2]) << 8) | UInt16(report[1])
        let degrees = Double(raw & 0x1FF)
        return min(max(degrees, range.lowerBound), range.upperBound)
    }
}
