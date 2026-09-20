import XCTest
import CoreAudio
@testable import HingeForce

final class AudioDevicesTests: XCTestCase {
    private func device(_ id: UInt32, _ name: String, transport: String, source: String? = nil) -> AudioDevices.InputDevice {
        AudioDevices.InputDevice(id: id, uid: "uid-\(id)", name: name,
                                 transportType: AudioDevices.fourCC(transport),
                                 dataSource: source.map(AudioDevices.fourCC))
    }

    func testFourCharacterCodesMatchCoreAudiosConstants() {
        XCTAssertEqual(AudioDevices.fourCC("bltn"), kAudioDeviceTransportTypeBuiltIn)
        XCTAssertEqual(AudioDevices.fourCC("blue"), kAudioDeviceTransportTypeBluetooth)
    }

    func testPicksTheBuiltInMicEvenWhenBluetoothIsTheSystemDefault() {
        // The order CoreAudio returned on a real MacBook Pro with AirPods connected and as the default input.
        let devices = [
            device(86, "Keyaan’s iPhone (1546) Microphone", transport: "ccwd"),
            device(94, "Batman’s AirPods", transport: "blue"),
            device(72, "MacBook Pro Microphone", transport: "bltn", source: "imic"),
            device(84, "Keyaan’s iPhone Microphone", transport: "ccwd"),
        ]
        XCTAssertEqual(AudioDevices.builtInMicrophone(in: devices)?.id, 72)
    }

    func testNeverFallsBackToABluetoothOrPhoneMicrophone() {
        let devices = [
            device(94, "Batman’s AirPods", transport: "blue"),
            device(86, "iPhone Microphone", transport: "ccwd"),
            device(60, "USB Mic", transport: "usb "),
        ]
        XCTAssertNil(AudioDevices.builtInMicrophone(in: devices))
        XCTAssertNil(AudioDevices.builtInMicrophone(in: []))
    }

    func testSkipsABuiltInHeadsetJackMicWhenTheInternalOneIsThere() {
        let devices = [
            device(70, "External Microphone", transport: "bltn", source: "hdpn"),
            device(72, "MacBook Pro Microphone", transport: "bltn", source: "imic"),
        ]
        XCTAssertEqual(AudioDevices.builtInMicrophone(in: devices)?.id, 72)
        XCTAssertNil(AudioDevices.builtInMicrophone(in: [devices[0]]))
    }

    func testAcceptsABuiltInMicWithNoDataSourceConcept() {
        XCTAssertEqual(AudioDevices.builtInMicrophone(in: [device(5, "Built-in Microphone", transport: "bltn")])?.id, 5)
    }

    func testFindsTheRealBuiltInMicOnThisMachine() throws {
        let devices = AudioDevices.inputDevices()
        try XCTSkipIf(devices.isEmpty, "no audio input devices here")
        guard let mic = AudioDevices.builtInMicrophone(in: devices) else {
            throw XCTSkip("this machine has no built-in microphone")
        }
        XCTAssertTrue(mic.isBuiltIn)
        XCTAssertNotEqual(mic.transportType, kAudioDeviceTransportTypeBluetooth)
    }
}

final class PCMConverterTests: XCTestCase {
    private func convert<T>(_ values: [T], isFloat: Bool, bits: Int, channels: Int) -> [Float] {
        values.withUnsafeBytes { PCMConverter.monoSamples(from: $0, isFloat: isFloat, bitsPerChannel: bits, channels: channels) }
    }

    func testFloatMonoPassesThroughUnchanged() {
        XCTAssertEqual(convert([0.5, -0.25, 1.0] as [Float], isFloat: true, bits: 32, channels: 1), [0.5, -0.25, 1.0])
    }

    func testSixteenBitIntegersScaleToMinusOneToOne() {
        let out = convert([0, 16384, -16384, Int16.min] as [Int16], isFloat: false, bits: 16, channels: 1)
        XCTAssertEqual(out, [0, 0.5, -0.5, -1])
    }

    func testInterleavedStereoKeepsOnlyTheFirstChannel() {
        let stereo: [Float] = [0.1, 0.9, 0.2, 0.8, 0.3, 0.7]      // L R L R L R
        XCTAssertEqual(convert(stereo, isFloat: true, bits: 32, channels: 2), [0.1, 0.2, 0.3])
    }

    func testUnsupportedFormatsGiveNoSamplesRatherThanGarbage() {
        XCTAssertTrue(convert([1, 2, 3] as [Int32], isFloat: false, bits: 32, channels: 1).isEmpty)
        XCTAssertTrue(convert([Float]() , isFloat: true, bits: 32, channels: 1).isEmpty)
    }
}

final class SampleBatcherTests: XCTestCase {
    func testWaitsForAHundredMillisecondsOfAudioBeforeReleasingAFrame() {
        var batcher = SampleBatcher()
        let chunk = [Float](repeating: 0.1, count: 512)              // ~10.7 ms at 48 kHz
        var frames: [[Float]] = []
        for _ in 0..<9 {
            if let frame = batcher.add(chunk, sampleRate: 48_000) { frames.append(frame) }
        }
        XCTAssertTrue(frames.isEmpty, "9 x 512 = 4608 samples is still under 100 ms")
        XCTAssertNotNil(batcher.add(chunk, sampleRate: 48_000), "the tenth chunk crosses 4800")
    }

    func testNoAudioIsLostOrRepeatedBetweenFrames() {
        var batcher = SampleBatcher()
        var released = 0
        var fed = 0
        for i in 0..<200 {
            let chunk = [Float](repeating: Float(i), count: 512)
            fed += chunk.count
            if let frame = batcher.add(chunk, sampleRate: 48_000) { released += frame.count }
        }
        XCTAssertGreaterThan(released, 0)
        XCTAssertLessThanOrEqual(fed - released, 4800 + 512, "at most one partial frame is left waiting")
    }

    func testFramesKeepSamplesInOrder() {
        var batcher = SampleBatcher()
        let first = batcher.add((0..<3000).map(Float.init), sampleRate: 44_100)
        XCTAssertNil(first)
        let frame = try! XCTUnwrap(batcher.add((3000..<6000).map(Float.init), sampleRate: 44_100))
        XCTAssertEqual(frame, (0..<6000).map(Float.init))
    }

    func testFrameLengthFollowsTheSampleRate() {
        var slow = SampleBatcher(), fast = SampleBatcher()
        let chunk = [Float](repeating: 0, count: 4500)
        XCTAssertNotNil(slow.add(chunk, sampleRate: 44_100))     // needs 4410
        XCTAssertNil(fast.add(chunk, sampleRate: 48_000))        // needs 4800
    }
}
