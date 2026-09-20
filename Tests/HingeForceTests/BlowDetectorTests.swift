import XCTest
@testable import HingeForce

/// Feeds synthetic audio through `BlowDetector`, in 1024-sample buffers like the mic tap.
final class BlowDetectorTests: XCTestCase {
    private let sampleRate = 48_000.0
    private let bufferSize = 1024

    /// Deterministic white noise in -1...1.
    private struct Noise {
        var state: UInt64 = 0x1234_5678_9ABC_DEF0
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(1 << 53) * 2 - 1
        }
    }

    private func amplitude(dBFS: Double) -> Double { pow(10, dBFS / 20) }

    private func whiteNoise(seconds: Double, rmsDB: Double, noise: inout Noise) -> [Float] {
        // Uniform(-1,1) has RMS 1/sqrt(3).
        let scale = amplitude(dBFS: rmsDB) * 3.0.squareRoot()
        return (0..<Int(seconds * sampleRate)).map { _ in Float(noise.next() * scale) }
    }

    private func sine(seconds: Double, frequency: Double, rmsDB: Double) -> [Float] {
        let peak = amplitude(dBFS: rmsDB) * 2.0.squareRoot()
        return (0..<Int(seconds * sampleRate)).map { Float(peak * sin(2 * .pi * frequency * Double($0) / sampleRate)) }
    }

    /// Low-frequency rumble like breath on a mic: white noise low-passed near 150 Hz.
    private func breathNoise(seconds: Double, rmsDB: Double, noise: inout Noise) -> [Float] {
        let a = exp(-2 * .pi * 150 / sampleRate)
        var y = 0.0
        var raw = (0..<Int(seconds * sampleRate)).map { _ -> Double in
            y = (1 - a) * noise.next() + a * y
            return y
        }
        let rms = (raw.reduce(0) { $0 + $1 * $1 } / Double(raw.count)).squareRoot()
        let scale = amplitude(dBFS: rmsDB) / rms
        raw = raw.map { $0 * scale }
        return raw.map(Float.init)
    }

    @discardableResult
    private func feed(_ detector: BlowDetector, _ samples: [Float]) -> BlowDetector.Output {
        var last: BlowDetector.Output!
        var index = 0
        while index + bufferSize <= samples.count {
            last = samples[index..<index + bufferSize].withUnsafeBufferPointer {
                detector.process($0, sampleRate: sampleRate)
            }
            index += bufferSize
        }
        return last
    }

    private func calibrated(noise: inout Noise, backgroundDB: Double = -50) -> BlowDetector {
        let detector = BlowDetector()
        let out = feed(detector, whiteNoise(seconds: 2.5, rmsDB: backgroundDB, noise: &noise))
        XCTAssertFalse(out.isCalibrating)
        return detector
    }

    func testReportsCalibratingThenLearnsNoiseFloor() {
        var noise = Noise()
        let detector = BlowDetector()

        let early = feed(detector, whiteNoise(seconds: 0.5, rmsDB: -50, noise: &noise))
        XCTAssertTrue(early.isCalibrating)
        XCTAssertEqual(early.reading, 1)
        XCTAssertNil(early.noiseFloorDB)

        let done = feed(detector, whiteNoise(seconds: 2, rmsDB: -50, noise: &noise))
        XCTAssertFalse(done.isCalibrating)
        let floor = try! XCTUnwrap(done.noiseFloorDB)
        let threshold = try! XCTUnwrap(done.thresholdDB)
        XCTAssertGreaterThanOrEqual(threshold - floor, BlowDetector.minMarginDB - 1e-9)
    }

    func testSteadyBackgroundStaysAtOne() {
        var noise = Noise()
        let detector = calibrated(noise: &noise)
        let out = feed(detector, whiteNoise(seconds: 2, rmsDB: -50, noise: &noise))
        XCTAssertEqual(out.reading, 1, accuracy: 0.05)
    }

    func testFullStrengthBlowReadsNearTen() {
        var noise = Noise()
        let detector = calibrated(noise: &noise)
        let out = feed(detector, breathNoise(seconds: 1, rmsDB: BlowDetector.fullScaleLevelDB + 1, noise: &noise))
        XCTAssertGreaterThan(out.reading, 9)
    }

    func testOrdinaryBlowStaysWellBelowTen() {
        var noise = Noise()
        let detector = calibrated(noise: &noise)
        let out = feed(detector, breathNoise(seconds: 1, rmsDB: -20, noise: &noise))
        XCTAssertGreaterThan(out.reading, 3)
        XCTAssertLessThan(out.reading, 8)
    }

    func testHigherPitchedSoundOfSameLoudnessIsMostlyRejected() {
        var noise = Noise()
        let detector = calibrated(noise: &noise)
        let out = feed(detector, sine(seconds: 1, frequency: 2_000, rmsDB: -20))
        XCTAssertLessThan(out.reading, 2)
    }

    func testReadingScalesWithBlowStrengthAndReturnsToOne() {
        var noise = Noise()
        let detector = calibrated(noise: &noise)

        let soft = feed(detector, breathNoise(seconds: 1, rmsDB: -45, noise: &noise)).reading
        let firm = feed(detector, breathNoise(seconds: 1, rmsDB: -30, noise: &noise)).reading
        let hard = feed(detector, breathNoise(seconds: 1, rmsDB: 0, noise: &noise)).reading
        XCTAssertLessThan(soft, firm)
        XCTAssertLessThan(firm, hard)

        let after = feed(detector, whiteNoise(seconds: 2, rmsDB: -50, noise: &noise))
        XCTAssertEqual(after.reading, 1, accuracy: 0.1)
    }

    func testReadingStaysInRangeAndSilenceIsSafe() {
        let detector = BlowDetector()
        let out = feed(detector, [Float](repeating: 0, count: Int(3 * sampleRate)))
        XCTAssertFalse(out.isCalibrating)
        XCTAssertTrue((1...10).contains(out.reading))

        let loud = feed(detector, [Float](repeating: 1, count: 8192))
        XCTAssertTrue((1...10).contains(loud.reading))
    }

    func testRecalibrateRestartsCalibration() {
        var noise = Noise()
        let detector = calibrated(noise: &noise)
        detector.recalibrate()
        let out = feed(detector, whiteNoise(seconds: 0.2, rmsDB: -50, noise: &noise))
        XCTAssertTrue(out.isCalibrating)
        XCTAssertEqual(out.reading, 1)
    }
}
