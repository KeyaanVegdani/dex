import Foundation

/// Turns raw microphone samples into a 1...10 "blow" reading.
///
/// Pipeline:
/// 1. Band-pass the audio (`passBand`). Breath noise on a mic is dominated by low
///    frequencies, while speech and most background sound sit higher, so this keeps
///    the blow and drops much of everything else.
/// 2. Measure each buffer's RMS level in dB.
/// 3. For the first `calibrationDuration` seconds, learn the background: the mean and
///    standard deviation of that level. Blow detection is then relative to this floor.
/// 4. The threshold is `floor + max(stdDevMultiplier * std, minMarginDB)`, so a noisy
///    room needs a bigger jump than a quiet one. Level between the threshold and
///    `fullScaleLevelDB` is mapped onto 1...10 and smoothed (fast attack, slow release).
///
/// `process` is called on the audio thread; `recalibrate` may be called from any thread.
final class BlowDetector: @unchecked Sendable {
    struct Output: Equatable {
        var reading: Double
        var levelDB: Double
        var noiseFloorDB: Double?
        var thresholdDB: Double?
        var isCalibrating: Bool
    }

    // MARK: Tuning

    static let passBand: ClosedRange<Double> = 30...500
    /// Time at the start of a calibration to discard while the filters and mic settle.
    static let calibrationSettle: TimeInterval = 0.3
    static let calibrationDuration: TimeInterval = 1.5
    static let stdDevMultiplier = 3.0
    static let minMarginDB = 6.0
    /// Band-passed level (dB) that maps to a reading of 10. Fixed rather than relative to
    /// the noise floor, so a blow of a given strength reads the same in a quiet or noisy
    /// room. The built-in mic's in-band level goes above 0 dB on hard blows (about +7 at
    /// the hardest measured); raise this to make 10 harder to reach, lower it to make it easier.
    static let fullScaleLevelDB = 8.0
    static let silenceDB = -140.0
    static let minNoiseFloorDB = -90.0
    static let attack: TimeInterval = 0.03
    static let release: TimeInterval = 0.25

    // MARK: State (guarded by `lock`)

    private let lock = NSLock()
    private var filters = FilterChain()
    private var filterSampleRate = 0.0

    private var calibrationElapsed: TimeInterval = 0
    private var calibrationCount = 0
    private var calibrationMean = 0.0
    private var calibrationM2 = 0.0
    private var noiseFloorDB: Double?
    private var thresholdDB = 0.0
    private var spanDB = BlowDetector.minMarginDB
    private var smoothed = 1.0

    func recalibrate() {
        lock.lock()
        defer { lock.unlock() }
        noiseFloorDB = nil
        calibrationElapsed = 0
        calibrationCount = 0
        calibrationMean = 0
        calibrationM2 = 0
        smoothed = 1
    }

    func process(_ samples: UnsafeBufferPointer<Float>, sampleRate: Double) -> Output {
        lock.lock()
        defer { lock.unlock() }

        if sampleRate != filterSampleRate {
            filters = FilterChain(sampleRate: sampleRate, passBand: Self.passBand)
            filterSampleRate = sampleRate
        }

        var sumSquares = 0.0
        for sample in samples {
            let y = filters.process(Double(sample))
            sumSquares += y * y
        }
        let rms = samples.isEmpty ? 0 : (sumSquares / Double(samples.count)).squareRoot()
        let levelDB = max(20 * log10(max(rms, 1e-12)), Self.silenceDB)
        let dt = sampleRate > 0 ? Double(samples.count) / sampleRate : 0

        if noiseFloorDB == nil {
            accumulateCalibration(levelDB: levelDB, dt: dt)
        }

        guard let floor = noiseFloorDB else {
            return Output(reading: 1, levelDB: levelDB, noiseFloorDB: nil, thresholdDB: nil, isCalibrating: true)
        }

        let fraction = (levelDB - thresholdDB) / spanDB
        let target = ReadingMap.oneToTen(fraction)
        let tau = target > smoothed ? Self.attack : Self.release
        smoothed += (target - smoothed) * (1 - exp(-dt / tau))

        return Output(reading: smoothed, levelDB: levelDB, noiseFloorDB: floor, thresholdDB: thresholdDB, isCalibrating: false)
    }

    // MARK: - Calibration

    private func accumulateCalibration(levelDB: Double, dt: TimeInterval) {
        calibrationElapsed += dt
        guard calibrationElapsed >= Self.calibrationSettle else { return }

        // Welford's running mean / variance.
        calibrationCount += 1
        let delta = levelDB - calibrationMean
        calibrationMean += delta / Double(calibrationCount)
        calibrationM2 += delta * (levelDB - calibrationMean)

        guard calibrationElapsed >= Self.calibrationSettle + Self.calibrationDuration,
              calibrationCount > 1 else { return }

        let std = (calibrationM2 / Double(calibrationCount - 1)).squareRoot()
        let floor = max(calibrationMean, Self.minNoiseFloorDB)
        thresholdDB = floor + max(Self.stdDevMultiplier * std, Self.minMarginDB)
        spanDB = max(Self.fullScaleLevelDB - thresholdDB, Self.minMarginDB)
        noiseFloorDB = floor
    }
}

// MARK: - Filters

/// Band-pass built from a 2nd-order high-pass and two cascaded 2nd-order low-passes.
private struct FilterChain {
    private var highPass: Biquad
    private var lowPassA: Biquad
    private var lowPassB: Biquad

    init(sampleRate: Double = 48_000, passBand: ClosedRange<Double> = 30...500) {
        highPass = .highPass(cutoff: passBand.lowerBound, sampleRate: sampleRate)
        lowPassA = .lowPass(cutoff: passBand.upperBound, sampleRate: sampleRate)
        lowPassB = .lowPass(cutoff: passBand.upperBound, sampleRate: sampleRate)
    }

    mutating func process(_ x: Double) -> Double {
        lowPassB.process(lowPassA.process(highPass.process(x)))
    }
}

/// RBJ-cookbook biquad, transposed direct form II.
private struct Biquad {
    private var b0: Double, b1: Double, b2: Double, a1: Double, a2: Double
    private var z1 = 0.0, z2 = 0.0

    private init(b0: Double, b1: Double, b2: Double, a0: Double, a1: Double, a2: Double) {
        self.b0 = b0 / a0
        self.b1 = b1 / a0
        self.b2 = b2 / a0
        self.a1 = a1 / a0
        self.a2 = a2 / a0
    }

    static func lowPass(cutoff: Double, sampleRate: Double, q: Double = 0.7071) -> Biquad {
        let (cosW, alpha) = terms(cutoff, sampleRate, q)
        return Biquad(b0: (1 - cosW) / 2, b1: 1 - cosW, b2: (1 - cosW) / 2,
                      a0: 1 + alpha, a1: -2 * cosW, a2: 1 - alpha)
    }

    static func highPass(cutoff: Double, sampleRate: Double, q: Double = 0.7071) -> Biquad {
        let (cosW, alpha) = terms(cutoff, sampleRate, q)
        return Biquad(b0: (1 + cosW) / 2, b1: -(1 + cosW), b2: (1 + cosW) / 2,
                      a0: 1 + alpha, a1: -2 * cosW, a2: 1 - alpha)
    }

    private static func terms(_ cutoff: Double, _ sampleRate: Double, _ q: Double) -> (cos: Double, alpha: Double) {
        let w0 = 2 * Double.pi * min(cutoff, sampleRate / 2 * 0.99) / sampleRate
        return (cos(w0), sin(w0) / (2 * q))
    }

    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y
    }
}
