import XCTest
import AVFoundation
@testable import HingeForce

/// Frequency content helpers for the tests.
private func magnitude(of samples: [Float], atHz hz: Double, rate: Double) -> Double {
    var re = 0.0, im = 0.0
    for (i, s) in samples.enumerated() {
        let w = 0.5 - 0.5 * cos(2 * .pi * Double(i) / Double(samples.count))
        let a = 2 * .pi * hz * Double(i) / rate
        re += Double(s) * w * cos(a); im -= Double(s) * w * sin(a)
    }
    return (re * re + im * im).squareRoot()
}

/// The frequency (searched in steps of 10 Hz) with the most energy.
private func dominantHz(_ samples: [Float], rate: Double, from: Double = 80, to: Double = 3000) -> Double {
    stride(from: from, through: to, by: 10).max { magnitude(of: samples, atHz: $0, rate: rate) < magnitude(of: samples, atHz: $1, rate: rate) }!
}

private func rms(_ x: ArraySlice<Float>) -> Double {
    guard !x.isEmpty else { return 0 }
    return (x.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(x.count)).squareRoot()
}

/// Share of a signal's energy above `hz`, from a 4096-sample window (every other bin).
private func energyShare(above hz: Double, _ x: [Float], rate: Double) -> Double {
    let seg = Array(x.prefix(4096))
    var high = 0.0, all = 0.0
    for k in stride(from: 1, to: seg.count / 2, by: 2) {
        let f = Double(k) * rate / Double(seg.count)
        let m = magnitude(of: seg, atHz: f, rate: rate)
        all += m * m
        if f > hz { high += m * m }
    }
    return all > 0 ? high / all : 0
}

/// How much the loudness modulates at 30-150 Hz, as a fraction of the average loudness. That range is what reads as
/// buzzing, so a chainsaw scores high and a smooth sound scores low.
private func roughness(_ x: [Float], rate: Double) -> Double {
    var env = 0.0
    let a = 1 - exp(-2 * .pi * 250 / rate)
    var e: [Double] = []
    for (i, v) in x.enumerated() { env += a * (abs(Double(v)) - env); if i % 48 == 0 { e.append(env) } }
    let mean = e.reduce(0, +) / Double(e.count)
    let centred = e.map { $0 - mean }
    var power = 0.0
    for hz in stride(from: 30.0, through: 150, by: 2) {
        var re = 0.0, im = 0.0
        for (i, v) in centred.enumerated() {
            let w = 0.5 - 0.5 * cos(2 * .pi * Double(i) / Double(centred.count))
            let angle = 2 * .pi * hz * Double(i) / (rate / 48)
            re += v * w * cos(angle); im -= v * w * sin(angle)
        }
        power += (re * re + im * im) / Double(centred.count * centred.count) * 4
    }
    return power.squareRoot() / mean
}

// MARK: - The MP3s

final class SoundLoaderTests: XCTestCase {
    func testAllFourEmbeddedSoundsDecode() throws {
        for (name, data) in [("button", SoundData.button), ("hover", SoundData.hover), ("partFinished", SoundData.partFinished), ("lessonFinished", SoundData.lessonFinished)] {
            let buffer = try XCTUnwrap(SoundLoader.decode(base64: data), name)
            XCTAssertGreaterThan(buffer.frameLength, 1000, name)
        }
    }

    func testButtonSoundStartsRightAwayNotAfterItsTwoTenthsOfASecondOfSilence() throws {
        let buffer = try XCTUnwrap(SoundLoader.decode(base64: SoundData.button))
        let rate = buffer.format.sampleRate
        // The file is 1.39 s long with sound only from 0.20 s to 0.40 s; trimmed, it is short and begins with the click.
        XCTAssertLessThan(Double(buffer.frameLength) / rate, 0.5)
        XCTAssertGreaterThan(Double(buffer.frameLength) / rate, 0.15)
        let first = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(rate * 0.03)))
        let peak = (0..<Int(buffer.frameLength)).map { abs(buffer.floatChannelData![0][$0]) }.max()!
        XCTAssertGreaterThan(first.map { abs($0) }.max()!, peak * 0.2, "the first click lands within 30 ms of pressing")
    }

    func testHoverSoundIsAShortQuietBlipThatStartsAtOnce() throws {
        let hover = try XCTUnwrap(SoundLoader.decode(base64: SoundData.hover))
        let button = try XCTUnwrap(SoundLoader.decode(base64: SoundData.button))
        let rate = hover.format.sampleRate
        XCTAssertLessThan(Double(hover.frameLength) / rate, 0.1, "well under a tenth of a second, so it can't drag")
        XCTAssertGreaterThan(Double(hover.frameLength) / rate, 0.02)

        func peak(_ b: AVAudioPCMBuffer) -> Float {
            (0..<Int(b.frameLength)).map { abs(b.floatChannelData![0][$0]) }.max()!
        }
        XCTAssertLessThan(peak(hover), peak(button) * 0.5, "a hover is quieter than a press")

        let first = (0..<Int(rate * 0.012)).map { abs(hover.floatChannelData![0][$0]) }.max()!
        XCTAssertGreaterThan(first, peak(hover) * 0.1, "sound begins within 12 ms of the pointer arriving")
    }

    func testTheChimesKeepTheirBodyAndOnlyLoseTheSilence() throws {
        let part = try XCTUnwrap(SoundLoader.decode(base64: SoundData.partFinished))
        XCTAssertEqual(Double(part.frameLength) / part.format.sampleRate, 0.9, accuracy: 0.15)
        let end = try XCTUnwrap(SoundLoader.decode(base64: SoundData.lessonFinished))
        XCTAssertGreaterThan(Double(end.frameLength) / end.format.sampleRate, 1.3)
        XCTAssertLessThanOrEqual(Double(end.frameLength) / end.format.sampleRate, 3.05)
    }

    func testTrimmingLeavesTheSoundInsideUntouched() throws {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000)!
        buffer.frameLength = 48_000
        for i in 10_000..<10_480 { buffer.floatChannelData![0][i] = 0.5 }
        let trimmed = SoundLoader.trimmed(buffer)
        XCTAssertLessThan(trimmed.frameLength, 3_000)
        XCTAssertGreaterThanOrEqual(trimmed.frameLength, 480)
        let inside = (0..<Int(trimmed.frameLength)).filter { trimmed.floatChannelData![0][$0] == 0.5 }.count
        XCTAssertEqual(inside, 480)
    }

    func testSilentSoundIsLeftAlone() {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_800)!
        buffer.frameLength = 4_800
        XCTAssertEqual(SoundLoader.trimmed(buffer).frameLength, 4_800)
    }
}

// MARK: - Hinge clicks

final class HingeClickSynthTests: XCTestCase {
    private let rate = 48_000.0

    func testClickPitchMatchesTheMeasuredSampleAtBothEnds() {
        let low = HingeClickSynth.render(pitch: 0, sampleRate: rate)
        let high = HingeClickSynth.render(pitch: 1, sampleRate: rate)
        // sampleHinge.mp3: the first click is dominated by ~200 Hz and the last by ~700 Hz.
        XCTAssertEqual(dominantHz(Array(low.prefix(Int(rate * 0.04))), rate: rate), 200, accuracy: 60)
        XCTAssertEqual(dominantHz(Array(high.prefix(Int(rate * 0.02))), rate: rate), 700, accuracy: 120)
    }

    func testPitchRisesSteadilyWithTheParameter() {
        let hz = stride(from: 0.0, through: 1.0, by: 0.25).map {
            dominantHz(Array(HingeClickSynth.render(pitch: $0, sampleRate: rate).prefix(Int(rate * 0.03))), rate: rate)
        }
        for (a, b) in zip(hz, hz.dropFirst()) { XCTAssertGreaterThan(b, a) }
    }

    func testClicksTightenAsTheyRiseLikeTheSample() {
        func timeToTenth(_ x: [Float]) -> Double {
            let peak = x.map { abs($0) }.max()!
            // Envelope by 2 ms windows.
            let win = Int(rate * 0.002)
            let env = stride(from: 0, to: x.count - win, by: win).map { rms(x[$0..<$0 + win]) }
            let top = env.enumerated().max { $0.element < $1.element }!
            let after = env[top.offset...].firstIndex { $0 < top.element * 0.1 } ?? env.count
            _ = peak
            return Double(after - top.offset) * 0.002
        }
        let slow = timeToTenth(HingeClickSynth.render(pitch: 0, sampleRate: rate))
        let fast = timeToTenth(HingeClickSynth.render(pitch: 1, sampleRate: rate))
        XCTAssertEqual(slow, 0.044, accuracy: 0.02, "the sample's first click takes about 44 ms to die away")
        XCTAssertEqual(fast, 0.016, accuracy: 0.01, "and its last about 16 ms")
        XCTAssertLessThan(fast, slow)
    }

    func testClicksAreShortLowAndNeverClip() {
        for pitch in stride(from: 0.0, through: 1.0, by: 0.25) {
            let x = HingeClickSynth.render(pitch: pitch, sampleRate: rate)
            XCTAssertLessThanOrEqual(Double(x.count) / rate, 0.12)
            XCTAssertGreaterThan(Double(x.count) / rate, 0.02)
            XCTAssertEqual(Double(x.map { abs($0) }.max()!), Double(HingeClickSynth.peak), accuracy: 1e-4)
            XCTAssertLessThan(abs(x.last!), 0.05, "ends near silence, so there is no pop")
            XCTAssertTrue(x.allSatisfy { $0.isFinite })
        }
    }

    func testMostOfTheEnergyIsLowLikeTheSample() {
        let x = HingeClickSynth.render(pitch: 0.3, sampleRate: rate)
        let low = stride(from: 80.0, through: 700, by: 20).reduce(0.0) { $0 + pow(magnitude(of: x, atHz: $1, rate: rate), 2) }
        let high = stride(from: 1500.0, through: 6000, by: 100).reduce(0.0) { $0 + pow(magnitude(of: x, atHz: $1, rate: rate), 2) } * 5
        XCTAssertGreaterThan(low, high)
    }

    func testTheSameClickComesOutTheSameEveryTime() {
        XCTAssertEqual(HingeClickSynth.render(pitch: 0.5, sampleRate: rate, seed: 4), HingeClickSynth.render(pitch: 0.5, sampleRate: rate, seed: 4))
    }
}

final class HingeClickTrackerTests: XCTestCase {
    func testNoClickForTheFirstReading() {
        var tracker = HingeClickTracker()
        XCTAssertTrue(tracker.update(angle: 100, dt: 0.033).isEmpty)
    }

    func testOneClickPerStepOfTravelInEitherDirection() {
        var tracker = HingeClickTracker()
        _ = tracker.update(angle: 100, dt: 0.033)
        var clicks = 0
        for degrees in stride(from: 101.0, through: 115, by: 1) { clicks += tracker.update(angle: degrees, dt: 0.033).count }
        XCTAssertEqual(clicks, Int(15 / HingeClickTracker.step), accuracy: 1)
        for degrees in stride(from: 114.0, through: 100, by: -1) { clicks += tracker.update(angle: degrees, dt: 0.033).count }
        XCTAssertEqual(clicks, Int(30 / HingeClickTracker.step), accuracy: 2, "and it clicks on the way back too")
    }

    func testAHingeThatIsHeldStillDoesNotChatterWhenTheSensorFlickersByADegree() {
        var tracker = HingeClickTracker()
        _ = tracker.update(angle: 110, dt: 0.033)
        var clicks = 0
        for i in 0..<300 { clicks += tracker.update(angle: i.isMultiple(of: 2) ? 110 : 111, dt: 0.033).count }
        XCTAssertEqual(clicks, 0)
    }

    func testAJumpCannotProduceARunOfClicks() {
        var tracker = HingeClickTracker()
        _ = tracker.update(angle: 60, dt: 0.033)
        XCTAssertLessThanOrEqual(tracker.update(angle: 130, dt: 0.033).count, HingeClickTracker.maxPerUpdate)
        XCTAssertTrue(tracker.update(angle: 130, dt: 0.033).isEmpty, "and it doesn't owe any more afterwards")
    }

    func testTurnSpeedIsMeasuredOverTheTimeTheReadingActuallyChangedNotPerFrame() {
        // The same turn, 30 degrees a second, seen by a sensor that updates every 33 ms and drawn at 60 fps (so the
        // reading only changes every other frame) and by one drawn at 30 fps. Both should click equally firmly.
        var every2 = HingeClickTracker(), every1 = HingeClickTracker()
        _ = every2.update(angle: 80, dt: 1.0 / 60); _ = every1.update(angle: 80, dt: 1.0 / 30)
        var firm2 = 0.0, firm1 = 0.0
        var angle = 80.0
        for frame in 0..<12 {
            if frame.isMultiple(of: 2) { angle += 1 }
            if let click = every2.update(angle: angle, dt: 1.0 / 60).first { firm2 = max(firm2, click.intensity) }
        }
        angle = 80
        for _ in 0..<6 {
            angle += 1
            if let click = every1.update(angle: angle, dt: 1.0 / 30).first { firm1 = max(firm1, click.intensity) }
        }
        XCTAssertGreaterThan(firm2, 0)
        XCTAssertEqual(firm2, firm1, accuracy: 0.05)
    }

    func testPitchFollowsTheHingeAngleAndQuickerTurnsAreFirmer() {
        XCTAssertEqual(HingeClickTracker.pitch(forAngle: 40), 0)
        XCTAssertEqual(HingeClickTracker.pitch(forAngle: 130), 1)
        XCTAssertEqual(HingeClickTracker.pitch(forAngle: 85), 0.5, accuracy: 1e-9)
        XCTAssertEqual(HingeClickTracker.pitch(forAngle: 10), 0)

        var slow = HingeClickTracker(), quick = HingeClickTracker()
        _ = slow.update(angle: 80, dt: 0.033); _ = quick.update(angle: 80, dt: 0.033)
        let gentle = slow.update(angle: 82, dt: 0.5).first!
        let sharp = quick.update(angle: 82, dt: 0.033).first!
        XCTAssertGreaterThan(sharp.intensity, gentle.intensity)
        XCTAssertLessThanOrEqual(sharp.intensity, 1)
        XCTAssertGreaterThan(gentle.pitch, 0.4)
        XCTAssertLessThan(gentle.pitch, 0.6)
    }
}

// MARK: - The cutting sound

final class CutSynthTests: XCTestCase {
    private let rate = 48_000.0

    private func render(level: Double, depth: Double, seconds: Double = 1.0, synth: inout CutSynth) -> [Float] {
        var out = [Float](repeating: 0, count: Int(seconds * rate))
        out.withUnsafeMutableBufferPointer { synth.render(into: $0.baseAddress!, frames: $0.count, sampleRate: rate, level: level, tone: depth) }
        return out
    }

    func testSilentWhenNotCutting() {
        var synth = CutSynth()
        XCTAssertTrue(render(level: 0, depth: 0.5, synth: &synth).allSatisfy { abs($0) < 1e-6 })
    }

    func testGetsLouderWithTheLevelAndNeverClips() {
        var quiet = CutSynth(), loud = CutSynth()
        let soft = render(level: 0.2, depth: 0.5, synth: &quiet)
        let firm = render(level: 1.0, depth: 0.5, synth: &loud)
        XCTAssertGreaterThan(rms(firm[Int(rate * 0.3)...]), 2 * rms(soft[Int(rate * 0.3)...]))
        XCTAssertLessThanOrEqual(firm.map { abs($0) }.max()!, 1)
        XCTAssertTrue(firm.allSatisfy { $0.isFinite })
        XCTAssertLessThan(rms(firm[Int(rate * 0.3)...]), 0.5, "gentle next to the other effects")
    }

    func testPitchRisesAsTheKnifeSinksLikeTheHingeClicks() {
        var shallow = CutSynth(), deep = CutSynth()
        let a = Array(render(level: 1, depth: 0, synth: &shallow)[Int(rate * 0.2)..<Int(rate * 0.2) + 2048])
        let b = Array(render(level: 1, depth: 1, synth: &deep)[Int(rate * 0.2)..<Int(rate * 0.2) + 2048])
        func centroid(_ x: [Float]) -> Double {
            var num = 0.0, den = 0.0
            for hz in stride(from: 100.0, through: 3000, by: 25) { let m = magnitude(of: x, atHz: hz, rate: rate); num += m * hz; den += m }
            return num / den
        }
        XCTAssertGreaterThan(centroid(b), centroid(a) + 100)
        XCTAssertEqual(CutSynth.centre(depth: 0), CutSynth.lowestHz)
        XCTAssertEqual(CutSynth.centre(depth: 1), CutSynth.highestHz)
    }

    func testVolumeChangesGraduallySoThereAreNoClicks() {
        var synth = CutSynth()
        _ = render(level: 0, depth: 0.5, seconds: 0.1, synth: &synth)
        let onset = render(level: 1, depth: 0.5, seconds: 0.05, synth: &synth)
        XCTAssertLessThan(onset.prefix(8).map { abs($0) }.max()!, 0.02, "starts from silence rather than jumping in")
        var stopping = CutSynth()
        _ = render(level: 1, depth: 0.5, seconds: 0.5, synth: &stopping)
        let fade = render(level: 0, depth: 0.5, seconds: 0.5, synth: &stopping)
        XCTAssertLessThan(rms(fade[Int(rate * 0.3)...]), 0.01, "fades out when the cut stops")
    }

    func testDeterministicAndStableOverLongRuns() {
        var a = CutSynth(), b = CutSynth()
        XCTAssertEqual(render(level: 0.7, depth: 0.3, synth: &a), render(level: 0.7, depth: 0.3, synth: &b))
        var long = CutSynth()
        let x = render(level: 1, depth: 1, seconds: 20, synth: &long)
        XCTAssertTrue(x.allSatisfy { $0.isFinite && abs($0) <= 1 })
    }

    func testLevelIsSteadyWhilePressingAndBoostedWhileMoving() {
        XCTAssertEqual(CutSoundLevel.level(depth: 0.8, speed: 0, pressing: false), 0)
        XCTAssertGreaterThan(CutSoundLevel.level(depth: 0.8, speed: 0, pressing: true), 0.1)
        XCTAssertGreaterThan(CutSoundLevel.level(depth: 0.5, speed: 1, pressing: true), CutSoundLevel.level(depth: 0.5, speed: 0, pressing: true))
        XCTAssertEqual(CutSoundLevel.level(depth: 0.5, speed: -1, pressing: false), CutSoundLevel.level(depth: 0.5, speed: 1, pressing: false), "rubbing either way")
        XCTAssertLessThanOrEqual(CutSoundLevel.level(depth: 1, speed: 50, pressing: true), 1)
        XCTAssertGreaterThan(CutSoundLevel.level(depth: 1, speed: 0, pressing: true), CutSoundLevel.level(depth: 0.2, speed: 0, pressing: true), "the deeper the louder")
    }
}

// MARK: - The whole engine, rendered offline

@MainActor
final class SoundEffectsEngineTests: XCTestCase {
    private let rate = 48_000.0

    /// An engine that renders into memory instead of the speakers, so nothing is heard while testing.
    private func makeSilentEngine(clock: @escaping () -> Date = Date.init) throws -> (SoundEffects, AVAudioEngine) {
        let engine = AVAudioEngine()
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 2, interleaved: false)!
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        return (SoundEffects(engine: engine, clock: clock), engine)
    }

    /// Renders `seconds` of whatever the engine is playing.
    private func render(_ engine: AVAudioEngine, seconds: Double) throws -> [Float] {
        let format = engine.manualRenderingFormat
        let block = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
        var out: [Float] = []
        while out.count < Int(seconds * rate) {
            let status = try engine.renderOffline(4096, to: block)
            guard status == .success else { break }
            out += Array(UnsafeBufferPointer(start: block.floatChannelData![0], count: Int(block.frameLength)))
        }
        return out
    }

    func testNothingPlaysUntilAsked() throws {
        let (effects, engine) = try makeSilentEngine()
        effects.prepare()
        XCTAssertTrue(engine.isRunning)
        let x = try render(engine, seconds: 0.3)
        XCTAssertLessThan(x.map { abs($0) }.max() ?? 0, 1e-6)
    }

    func testEachEffectPlaysAndThenEnds() throws {
        for effect in SoundEffects.Effect.allCases {
            let (effects, engine) = try makeSilentEngine()
            effects.play(effect)
            let x = try render(engine, seconds: 3.6)
            let peak = x.map { abs($0) }.max() ?? 0
            XCTAssertGreaterThan(peak, 0.05, "\(effect) is audible")
            XCTAssertLessThan(rms(x[Int(rate * 3.4)...]), 0.001, "\(effect) has finished by the end")
        }
    }

    func testButtonSoundStartsAtOnceWhenPressed() throws {
        let (effects, engine) = try makeSilentEngine()
        effects.play(.button)
        let x = try render(engine, seconds: 0.2)
        let loudFrom = x.firstIndex { abs($0) > 0.05 }!
        XCTAssertLessThan(Double(loudFrom) / rate, 0.03, "audible within 30 ms, not after the file's 200 ms of silence")
    }

    func testHingeClicksPlayAtTheirPitchAndCanOverlap() throws {
        let (effects, engine) = try makeSilentEngine()
        effects.hingeClick(pitch: 0, intensity: 1)
        let low = try render(engine, seconds: 0.15)
        XCTAssertEqual(dominantHz(Array(low.prefix(Int(rate * 0.04))), rate: rate), 200, accuracy: 70)

        let (fast, fastEngine) = try makeSilentEngine()
        for _ in 0..<4 { fast.hingeClick(pitch: 1, intensity: 1) }
        let burst = try render(fastEngine, seconds: 0.15)
        XCTAssertGreaterThan(burst.map { abs($0) }.max()!, low.map { abs($0) }.max()! * 0.9, "several at once still mix")
    }

    func testSofterClicksAreQuieter() throws {
        let (a, ea) = try makeSilentEngine(), (b, eb) = try makeSilentEngine()
        a.hingeClick(pitch: 0.5, intensity: 1)
        b.hingeClick(pitch: 0.5, intensity: 0.3)
        let loud = try render(ea, seconds: 0.1).map { abs($0) }.max()!
        let soft = try render(eb, seconds: 0.1).map { abs($0) }.max()!
        XCTAssertLessThan(soft, loud * 0.5)
    }

    func testCuttingSoundIsContinuousWhileOnAndFadesWhenOff() throws {
        let (effects, engine) = try makeSilentEngine()
        effects.setCut(level: 0.8, depth: 0.5)
        let on = try render(engine, seconds: 0.8)
        // No gaps: every 50 ms stretch after the fade-in has sound in it.
        let chunk = Int(rate * 0.05)
        for start in stride(from: Int(rate * 0.2), to: on.count - chunk, by: chunk) {
            XCTAssertGreaterThan(rms(on[start..<start + chunk]), 0.02, "gap in the cutting sound at \(Double(start) / rate)s")
        }
        effects.stopCut()
        let off = try render(engine, seconds: 0.6)
        XCTAssertLessThan(rms(off[Int(rate * 0.4)...]), 0.005)
    }

    func testShowerAndCandlesPlayThroughTheEngineAndStopWhenTold() throws {
        for kind in [SoundEffects.Ambient.shower, .candles] {
            let (effects, engine) = try makeSilentEngine()
            effects.setAmbient(kind, level: 0.9, tone: 0.5)
            let on = try render(engine, seconds: 1.5)
            XCTAssertGreaterThan(rms(on[Int(rate * 0.8)...]), 0.003, "\(kind) is audible")
            XCTAssertLessThan(on.map { abs($0) }.max()!, 0.6, "\(kind) stays gentle")
            effects.stopAmbient(kind)
            let off = try render(engine, seconds: 1.6)
            XCTAssertLessThan(rms(off[Int(rate * 1.2)...]), 0.001, "\(kind) has faded out")
        }
    }

    func testTheThreeContinuousSoundsAreIndependentAndCanPlayTogether() throws {
        let (effects, engine) = try makeSilentEngine()
        effects.setAmbient(.shower, level: 0.7)
        let showerOnly = try render(engine, seconds: 1.0)
        let (both, bothEngine) = try makeSilentEngine()
        both.setAmbient(.shower, level: 0.7)
        both.setAmbient(.candles, level: 0.7)
        let mixed = try render(bothEngine, seconds: 1.0)
        XCTAssertGreaterThan(rms(mixed[Int(rate * 0.5)...]), rms(showerOnly[Int(rate * 0.5)...]) * 0.98, "adding one never removes another")
        both.stopAmbient(.candles)
        both.stopAmbient(.shower)
        XCTAssertTrue(try render(bothEngine, seconds: 2.0)[Int(rate * 1.8)...].allSatisfy { abs($0) < 0.001 })
    }

    func testHoverSoundsAreSpacedOutAndStayQuietJustAfterAPress() throws {
        var now = Date(timeIntervalSince1970: 1_000)
        let (effects, _) = try makeSilentEngine(clock: { now })

        effects.play(.hover)                                   // pointer arrives
        XCTAssertEqual(effects.hoverPlayCount, 1)
        now += 0.05
        effects.play(.hover)                                   // a flicker of the same hover, 50 ms later
        XCTAssertEqual(effects.hoverPlayCount, 1, "too soon after the last one")
        now += 0.05
        effects.play(.hover)                                   // 100 ms after the first: a genuinely new hover
        XCTAssertEqual(effects.hoverPlayCount, 2)

        now += 1
        effects.play(.button)                                  // the button is pressed
        now += 0.1
        effects.play(.hover)                                   // the pointer slips out and back in as it shrinks
        XCTAssertEqual(effects.hoverPlayCount, 2, "quiet for a moment after a press")
        now += 0.3
        effects.play(.hover)
        XCTAssertEqual(effects.hoverPlayCount, 3, "and back to normal afterwards")
        XCTAssertLessThanOrEqual(SoundEffects.hoverSpacing, 0.1)
        XCTAssertLessThanOrEqual(SoundEffects.hoverQuietAfterPress, 0.5)
    }

    func testHoverSoundPlaysThroughTheEngineWithoutHoldingUpThePressSound() throws {
        let (effects, engine) = try makeSilentEngine()
        effects.play(.hover)
        let hoverOnly = try render(engine, seconds: 0.25)
        XCTAssertGreaterThan(hoverOnly.map { abs($0) }.max()!, 0.03, "audible")
        XCTAssertLessThan(rms(hoverOnly[Int(rate * 0.15)...]), 0.001, "and over in about a tenth of a second")

        let (both, bothEngine) = try makeSilentEngine()
        both.play(.hover)
        both.play(.button)     // pressed straight away: the press must still sound at full strength
        let mixed = try render(bothEngine, seconds: 0.2)
        let (pressOnly, pressEngine) = try makeSilentEngine()
        pressOnly.play(.button)
        let solo = try render(pressEngine, seconds: 0.2)
        XCTAssertGreaterThan(mixed.map { abs($0) }.max()!, solo.map { abs($0) }.max()! * 0.95)
    }

    func testDisabledEffectsMakeNoHoverSoundEither() throws {
        let (effects, _) = try makeSilentEngine()
        effects.isEnabled = false
        effects.play(.hover)
        XCTAssertEqual(effects.hoverPlayCount, 0)
    }

    func testDisabledEffectsMakeNoSound() throws {
        let (effects, engine) = try makeSilentEngine()
        effects.prepare()              // the engine is running and ready, but switched off
        effects.isEnabled = false
        effects.play(.button)
        effects.hingeClick(pitch: 0.5, intensity: 1)
        effects.setCut(level: 1, depth: 1)
        let x = try render(engine, seconds: 0.3)
        XCTAssertLessThan(x.map { abs($0) }.max() ?? 0, 1e-6)
    }
}

// MARK: - Smoothness of the cutting sound, and the shower and candle sounds

final class CutSoundSmoothnessTests: XCTestCase {
    private let rate = 48_000.0

    private func render<S: AmbientSynth>(_ synth: inout S, level: Double, tone: Double, seconds: Double, chunk: Int? = nil) -> [Float] {
        var out = [Float](repeating: 0, count: Int(seconds * rate))
        if let chunk {
            var i = 0
            while i < out.count {
                let n = min(chunk, out.count - i)
                out.withUnsafeMutableBufferPointer { synth.render(into: $0.baseAddress! + i, frames: n, sampleRate: rate, level: level, tone: tone) }
                i += n
            }
        } else {
            out.withUnsafeMutableBufferPointer { synth.render(into: $0.baseAddress!, frames: $0.count, sampleRate: rate, level: level, tone: tone) }
        }
        return out
    }

    func testTheCutSoundHasNoHissToRaspAndSitsInTheWarmRegisterOfTheOtherSounds() {
        for depth in [0.0, 0.5, 1.0] {
            var synth = CutSynth()
            let x = Array(render(&synth, level: 0.8, tone: depth, seconds: 2)[Int(rate * 0.5)...])
            // The chord's top tone reaches 1.4 kHz at full depth, so hiss is measured above 2 kHz. The old sound had
            // 5-13% of its energy above 1.5 kHz, and a wide band of noise well beyond that.
            XCTAssertLessThan(energyShare(above: 2000, x, rate: rate), 0.02, "depth \(depth): no hiss")
            XCTAssertLessThan(energyShare(above: 1500, x, rate: rate), 0.06, "depth \(depth): less than the old sound had")
            XCTAssertEqual(dominantHz(Array(x.prefix(4096)), rate: rate, from: 100, to: 2500), CutSynth.centre(depth: depth), accuracy: 60)
        }
    }

    func testTheCutSoundDoesNotBuzzInTheRangeThatSoundsLikeAChainsaw() {
        for depth in [0.2, 0.5, 0.8] {
            var synth = CutSynth()
            let x = Array(render(&synth, level: 0.8, tone: depth, seconds: 3)[Int(rate * 0.6)...])
            // The previous, rasping version measured 0.073-0.099 on this scale.
            XCTAssertLessThan(roughness(x, rate: rate), 0.08, "depth \(depth)")
        }
    }

    func testTheCutSoundIsSubtleNextToTheOtherEffects() {
        for depth in [0.2, 0.5, 0.8] {
            var synth = CutSynth()
            let x = Array(render(&synth, level: 0.8, tone: depth, seconds: 2)[Int(rate * 0.5)...])
            // The previous version's loudness was 0.074-0.099 (RMS) at this setting.
            XCTAssertLessThan(rms(x[...]), 0.075, "depth \(depth)")
            XCTAssertGreaterThan(rms(x[...]), 0.02, "still audible, depth \(depth)")
        }
        XCTAssertLessThan(CutSynth.maxAmplitude, 0.2)
    }

    func testEveryContinuousSoundComesOutTheSameHoweverTheAudioSystemChopsItUp() {
        func check<S: AmbientSynth>(_ make: () -> S, _ name: String) {
            var whole = make(), chopped = make(), odd = make()
            let a = render(&whole, level: 0.7, tone: 0.4, seconds: 1)
            let b = render(&chopped, level: 0.7, tone: 0.4, seconds: 1, chunk: 512)
            let c = render(&odd, level: 0.7, tone: 0.4, seconds: 1, chunk: 331)
            XCTAssertEqual(a, b, "\(name): 512-frame blocks")
            XCTAssertEqual(a, c, "\(name): 331-frame blocks")
        }
        check({ CutSynth() }, "cut")
        check({ ShowerSynth() }, "shower")
        check({ CandleSynth() }, "candles")
    }

    func testEveryContinuousSoundIsSilentWhenOffFadesInAndOutSmoothlyAndNeverClips() {
        func check<S: AmbientSynth>(_ make: () -> S, _ name: String) {
            var quiet = make()
            XCTAssertTrue(render(&quiet, level: 0, tone: 0.5, seconds: 0.5).allSatisfy { abs($0) < 1e-6 }, "\(name) silent at level 0")
            XCTAssertEqual(quiet.currentGain, 0, accuracy: 1e-9)

            var synth = make()
            let up = render(&synth, level: 1, tone: 1, seconds: 3)
            XCTAssertTrue(up.allSatisfy { $0.isFinite && abs($0) <= 1 }, "\(name) bounded")
            XCTAssertLessThan(up.prefix(16).map { abs($0) }.max()!, 0.03, "\(name) fades in rather than jumping in")
            XCTAssertGreaterThan(rms(up[Int(rate * 1.5)...]), 0.005, "\(name) is audible")

            let down = render(&synth, level: 0, tone: 1, seconds: 2.5)
            XCTAssertLessThan(rms(down[Int(rate * 2.2)...]), 0.001, "\(name) fades out")
            XCTAssertLessThan(synth.currentGain, 1e-3)
        }
        check({ CutSynth() }, "cut")
        check({ ShowerSynth() }, "shower")
        check({ CandleSynth() }, "candles")
    }

    // MARK: Shower

    func testTheShowerIsASoftBrightHissWithPatter() {
        var synth = ShowerSynth()
        let x = Array(render(&synth, level: 0.7, tone: 0.3, seconds: 3)[Int(rate * 0.8)...])
        XCTAssertGreaterThan(energyShare(above: 1000, x, rate: rate), 0.8, "water is mostly high frequencies")
        XCTAssertLessThan(energyShare(above: 9000, x, rate: rate), 0.25, "but rolled off, not harsh")
        XCTAssertLessThan(rms(x[...]), 0.06, "subtle: quieter than the chimes")
        XCTAssertGreaterThan(rms(x[...]), 0.01)
        XCTAssertLessThan(Double(x.map { abs($0) }.max()!), 0.4, "droplets never spike loudly")
    }

    func testTheShowerBrightensASmallAmountWithTone() {
        var soft = ShowerSynth(), bright = ShowerSynth()
        let a = Array(render(&soft, level: 1, tone: 0, seconds: 2)[Int(rate * 0.8)...])
        let b = Array(render(&bright, level: 1, tone: 1, seconds: 2)[Int(rate * 0.8)...])
        XCTAssertGreaterThan(energyShare(above: 5000, b, rate: rate), energyShare(above: 5000, a, rate: rate))
    }

    func testTheShowerIsSteadyRatherThanPulsing() {
        var synth = ShowerSynth()
        let x = Array(render(&synth, level: 0.7, tone: 0.3, seconds: 3)[Int(rate * 0.8)...])
        let win = Int(rate * 0.05)
        let env = stride(from: 0, to: x.count - win, by: win).map { rms(x[$0..<$0 + win]) }
        let mean = env.reduce(0, +) / Double(env.count)
        let spread = (env.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(env.count)).squareRoot() / mean
        XCTAssertLessThan(spread, 0.15)
    }

    // MARK: Candles

    func testCandlesAreALowSoftFlutterWithTheOddTinyCrackle() {
        var synth = CandleSynth()
        let x = Array(render(&synth, level: 0.7, tone: 0, seconds: 8)[Int(rate * 1)...])
        XCTAssertLessThan(rms(x[...]), 0.05, "very subtle")
        XCTAssertGreaterThan(rms(x[...]), 0.004)
        // Mostly a low rumble.
        XCTAssertLessThan(energyShare(above: 600, Array(x.prefix(4096)), rate: rate), 0.2)
        // The crackles are short bursts well above the average loudness.
        let win = Int(rate * 0.003)
        let env = stride(from: 0, to: x.count - win, by: win).map { rms(x[$0..<$0 + win]) }
        let mean = env.reduce(0, +) / Double(env.count)
        let bursts = zip(env.dropFirst(), env).filter { $0.0 > mean * 2.5 && $0.1 <= mean * 2.5 }.count
        XCTAssertGreaterThan(bursts, 3, "some crackles in eight seconds")
    }

    func testCandlesFlutterAndCrackleMoreWhenBlown() {
        func bursts(_ tone: Double) -> Int {
            var synth = CandleSynth()
            let x = Array(render(&synth, level: 0.7, tone: tone, seconds: 10)[Int(rate * 1)...])
            let win = Int(rate * 0.003)
            let env = stride(from: 0, to: x.count - win, by: win).map { rms(x[$0..<$0 + win]) }
            let mean = env.reduce(0, +) / Double(env.count)
            return zip(env.dropFirst(), env).filter { $0.0 > mean * 2.5 && $0.1 <= mean * 2.5 }.count
        }
        XCTAssertGreaterThan(bursts(1), bursts(0))
    }

    func testCandlesAreQuieterThanTheChimes() {
        // The part-finished chime's loudness is about 0.09 RMS; the candles at their steady level must sit well below it.
        var synth = CandleSynth()
        let x = Array(render(&synth, level: CandleSoundLevel.steady, tone: 0.5, seconds: 5)[Int(rate * 1)...])
        XCTAssertLessThan(rms(x[...]), 0.05)
    }
}

final class AmbientLevelTests: XCTestCase {
    func testCandlesAreSilentUntilLitThenSteadyThenFadeWhenBlownOut() {
        XCTAssertEqual(CandleSoundLevel.level(lit: 0, blowOutElapsed: nil), 0)
        XCTAssertEqual(CandleSoundLevel.level(lit: 1, blowOutElapsed: nil), CandleSoundLevel.steady, accuracy: 1e-9)
        XCTAssertGreaterThan(CandleSoundLevel.level(lit: 0.5, blowOutElapsed: nil), 0)
        XCTAssertLessThan(CandleSoundLevel.level(lit: 0.5, blowOutElapsed: nil), CandleSoundLevel.steady)
        XCTAssertEqual(CandleSoundLevel.level(lit: 1, blowOutElapsed: 0), CandleSoundLevel.steady, accuracy: 1e-9)
        XCTAssertEqual(CandleSoundLevel.level(lit: 1, blowOutElapsed: CandleSoundLevel.fadeOutDuration), 0, accuracy: 1e-9)
        XCTAssertEqual(CandleSoundLevel.level(lit: 1, blowOutElapsed: 9), 0)
        XCTAssertEqual(CandleSoundLevel.level(lit: 7, blowOutElapsed: nil), CandleSoundLevel.steady, "an overshoot while lighting can't make it louder")
    }

    func testTheCandleSoundFollowsTheFlamesLightingAnimation() {
        // Nothing before the flames appear, full once they have all popped on.
        func lit(_ t: Double) -> Double {
            let f = LessonIntro.cake(at: t).flameScale
            return f.reduce(0, +) / Double(f.count)
        }
        XCTAssertEqual(CandleSoundLevel.level(lit: lit(0.3), blowOutElapsed: nil), 0)
        XCTAssertEqual(CandleSoundLevel.level(lit: lit(LessonIntro.duration + 1), blowOutElapsed: nil), CandleSoundLevel.steady, accuracy: 1e-9)
    }

    func testTheShowerRunsWhileTheWaterDoesAndStopsWithIt() {
        XCTAssertEqual(ShowerSoundLevel.level(streamOpacity: 1), ShowerSoundLevel.steady, accuracy: 1e-9)
        XCTAssertEqual(ShowerSoundLevel.level(streamOpacity: 0), 0)
        XCTAssertEqual(ShowerSoundLevel.level(streamOpacity: WashCut.streamOpacity(elapsed: nil)), ShowerSoundLevel.steady, accuracy: 1e-9)
        XCTAssertEqual(ShowerSoundLevel.level(streamOpacity: WashCut.streamOpacity(elapsed: WashCut.streamFadeDuration)), 0, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(ShowerSoundLevel.steady, 0.8, "kept subtle")
    }
}
