import Foundation
import IOKit
import IOKit.hid

/// Pure maths for the accelerometer, kept apart from the hardware so it can be tested.
enum AccelerometerMath {
    /// Decodes one 22-byte report from the Mac's built-in accelerometer into gravity in g.
    /// The three axes are little-endian 32-bit integers at byte offsets 6, 10 and 14, in units of 1/65536 g.
    static func gravity(fromReport bytes: [UInt8]) -> (x: Double, y: Double, z: Double)? {
        guard bytes.count >= 18 else { return nil }
        func axis(_ offset: Int) -> Double {
            let raw = UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
            return Double(Int32(bitPattern: raw)) / 65536
        }
        return (axis(6), axis(10), axis(14))
    }

    /// How far the laptop is rolled sideways, in degrees, from the gravity reading. Zero when it lies flat;
    /// positive when the reading's x axis points down, which is the laptop's right side going down.
    /// Tipping the laptop forwards or backwards doesn't change it.
    static func rollDegrees(x: Double, y: Double, z: Double) -> Double {
        atan2(x, hypot(y, z)) * 180 / .pi
    }

    /// How far the laptop is tipped forward/back, in degrees. Zero when it lies flat;
    /// positive when the reading's y axis points down (tipping along the pitch axis).
    /// Rolling sideways doesn't change it.
    static func pitchDegrees(x: Double, y: Double, z: Double) -> Double {
        atan2(y, hypot(x, z)) * 180 / .pi
    }
}

/// Reads the built-in accelerometer of Apple Silicon MacBooks.
///
/// macOS has no public API for it. It is one of the SPU sensors (the family the lid-angle sensor belongs to):
/// a vendor HID device (usage page 0xFF00, usage 3) that stays silent until its driver is switched on through
/// the IORegistry. Both steps work from an ordinary, unsandboxed app with no special permission. The driver
/// is switched off again on `stop()`.
@MainActor
final class Accelerometer: ObservableObject {
    enum Status: Equatable {
        case idle
        case running
        case unavailable(String)
    }

    @Published private(set) var status: Status = .idle
    /// The latest gravity reading in g (lightly smoothed), or nil until the first report arrives.
    @Published private(set) var gravity: (x: Double, y: Double, z: Double)?

    /// Laptop roll in degrees (see `AccelerometerMath.rollDegrees`), or nil before the first reading.
    var rollDegrees: Double? { gravity.map { AccelerometerMath.rollDegrees(x: $0.x, y: $0.y, z: $0.z) } }

    /// Laptop pitch in degrees (see `AccelerometerMath.pitchDegrees`), or nil before the first reading.
    var pitchDegrees: Double? { gravity.map { AccelerometerMath.pitchDegrees(x: $0.x, y: $0.y, z: $0.z) } }

    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
    private var receivedReport = false

    /// Smoothing applied to each of the ~100 reports a second.
    private static let smoothing = 0.15

    deinit { buffer.deallocate() }

    func start() {
        guard device == nil else { return }
        guard Self.setSensors(on: true) else {
            status = .unavailable("This Mac doesn't have an accelerometer the app can read.")
            return
        }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDPrimaryUsagePageKey: 0xFF00,
            kIOHIDPrimaryUsageKey: 3,
            kIOHIDTransportKey: "SPU",
        ] as CFDictionary)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        guard let candidate = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>)?.first,
              IOHIDDeviceOpen(candidate, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            Self.setSensors(on: false)
            status = .unavailable("Couldn't open this Mac's accelerometer.")
            return
        }

        self.manager = manager
        device = candidate
        receivedReport = false
        DebugLog.write("accelerometer opened")

        IOHIDDeviceRegisterInputReportCallback(candidate, buffer, 64, { context, _, _, _, _, report, length in
            guard let context else { return }
            let bytes = Array(UnsafeBufferPointer(start: report, count: length))
            let me = Unmanaged<Accelerometer>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { me.handle(bytes) }
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(candidate, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        // If nothing arrives soon the sensor isn't reporting; say so rather than leave the lesson stuck.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard let self, self.device != nil, !self.receivedReport else { return }
            self.status = .unavailable("The accelerometer isn't sending readings.")
        }
    }

    func stop() {
        if let device {
            IOHIDDeviceRegisterInputReportCallback(device, buffer, 64, nil, nil)
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            Self.setSensors(on: false)
        }
        if let manager { IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue) }
        device = nil
        manager = nil
        gravity = nil
        status = .idle
    }

    private func handle(_ report: [UInt8]) {
        guard let reading = AccelerometerMath.gravity(fromReport: report) else { return }
        receivedReport = true
        if let current = gravity {
            let a = Self.smoothing
            gravity = (current.x + (reading.x - current.x) * a,
                       current.y + (reading.y - current.y) * a,
                       current.z + (reading.z - current.z) * a)
        } else {
            gravity = reading
        }
        if status != .running { status = .running }
    }

    /// Switches the accelerometer and gyroscope drivers on or off. Returns false if none were found.
    @discardableResult
    private static func setSensors(on: Bool) -> Bool {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSPUHIDDriver"), &iterator) == KERN_SUCCESS else {
            return false
        }
        defer { IOObjectRelease(iterator) }

        var found = false
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            func number(_ key: String) -> Int? {
                IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int
            }
            guard number("PrimaryUsagePage") == 0xFF00, number("PrimaryUsage") == 3 else { continue }
            found = true
            let value = on ? 1 : 0
            IORegistryEntrySetCFProperty(service, "SensorPropertyReportingState" as CFString, value as CFNumber)
            IORegistryEntrySetCFProperty(service, "SensorPropertyPowerState" as CFString, value as CFNumber)
            // The report interval is what actually starts and stops the stream: the two flags above alone
            // leave the sensor sending readings, so switching off must zero it too.
            IORegistryEntrySetCFProperty(service, "ReportInterval" as CFString, (on ? 10_000 : 0) as CFNumber)
        }
        return found
    }
}
