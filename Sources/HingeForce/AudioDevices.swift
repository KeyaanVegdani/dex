import CoreAudio
import Foundation

/// Finds the Mac's built-in microphone so the app never listens to a Bluetooth headset,
/// an iPhone's continuity microphone, or whatever else the system happens to default to.
enum AudioDevices {
    struct InputDevice: Equatable {
        let id: AudioDeviceID
        /// CoreAudio's identifier for the device; `AVCaptureDevice(uniqueID:)` accepts the same string.
        let uid: String
        let name: String
        /// e.g. `bltn` (built in), `blue` (Bluetooth), `ccwd` (iPhone continuity), `usb `.
        let transportType: UInt32
        /// e.g. `imic` (internal microphone); nil when the device has no data-source concept.
        let dataSource: UInt32?

        var isBuiltIn: Bool { transportType == kAudioDeviceTransportTypeBuiltIn }
    }

    /// The built-in microphone. Devices that only look built in, like a headphone-jack headset, are skipped.
    static func builtInMicrophone(in devices: [InputDevice]) -> InputDevice? {
        let internalMicrophone = fourCC("imic")
        return devices.first { $0.isBuiltIn && $0.dataSource == internalMicrophone }
            ?? devices.first { $0.isBuiltIn && $0.dataSource == nil }
    }

    static func builtInMicrophone() -> InputDevice? {
        builtInMicrophone(in: inputDevices())
    }

    /// Every audio device that can record.
    static func inputDevices() -> [InputDevice] {
        var address = property(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }

        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }

        return ids.compactMap { id in
            guard inputChannelCount(of: id) > 0 else { return nil }
            return InputDevice(id: id, uid: uid(of: id), name: name(of: id),
                               transportType: transportType(of: id), dataSource: inputDataSource(of: id))
        }
    }

    /// The four-character code `"imic"` and friends as the number CoreAudio uses.
    static func fourCC(_ code: String) -> UInt32 {
        code.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    // MARK: - CoreAudio queries

    private static func property(_ selector: AudioObjectPropertySelector,
                                 scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func uid(of id: AudioDeviceID) -> String {
        var address = property(kAudioDevicePropertyDeviceUID)
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &uid) == noErr, let uid else { return "" }
        return uid.takeRetainedValue() as String
    }

    private static func name(of id: AudioDeviceID) -> String {
        var address = property(kAudioObjectPropertyName)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name) == noErr, let name else { return "Unknown" }
        return name.takeRetainedValue() as String
    }

    private static func transportType(of id: AudioDeviceID) -> UInt32 {
        var address = property(kAudioDevicePropertyTransportType)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
        return value
    }

    private static func inputDataSource(of id: AudioDeviceID) -> UInt32? {
        var address = property(kAudioDevicePropertyDataSource, scope: kAudioObjectPropertyScopeInput)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func inputChannelCount(of id: AudioDeviceID) -> Int {
        var address = property(kAudioDevicePropertyStreamConfiguration, scope: kAudioObjectPropertyScopeInput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }

        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, raw) == noErr else { return 0 }

        let buffers = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
    }
}
