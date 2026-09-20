import AVFoundation
import Foundation
import SwiftUI

/// Decoding the embedded MP3s and cutting the silence off their ends.
enum SoundLoader {
    /// Decodes base64 MP3 data into a float buffer, with leading and trailing silence removed.
    static func decode(base64: String) -> AVAudioPCMBuffer? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        // AVAudioFile reads from a file, so the data takes a short trip through the temporary folder.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("hingeforce-\(UUID().uuidString).mp3")
        defer { try? FileManager.default.removeItem(at: url) }
        guard (try? data.write(to: url)) != nil,
              let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil else { return nil }
        return trimmed(buffer)
    }

    /// Cuts silence (below `threshold` of the loudest sample) from both ends, keeping a little lead-in and tail.
    static func trimmed(_ buffer: AVAudioPCMBuffer, threshold: Float = 0.005, lead: Double = 0.004, tail: Double = 0.03) -> AVAudioPCMBuffer {
        guard let channels = buffer.floatChannelData else { return buffer }
        let frames = Int(buffer.frameLength), channelCount = Int(buffer.format.channelCount)

        var peak: Float = 0
        for c in 0..<channelCount { for i in 0..<frames { peak = max(peak, abs(channels[c][i])) } }
        guard peak > 0 else { return buffer }
        let cutoff = peak * threshold

        func loud(_ i: Int) -> Bool { (0..<channelCount).contains { abs(channels[$0][i]) > cutoff } }
        guard let first = (0..<frames).first(where: loud), let last = (0..<frames).last(where: loud) else { return buffer }

        let rate = buffer.format.sampleRate
        let start = max(first - Int(lead * rate), 0)
        let end = min(last + Int(tail * rate), frames - 1)
        let count = end - start + 1
        guard count > 0, count < frames,
              let out = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: AVAudioFrameCount(count)),
              let outChannels = out.floatChannelData else { return buffer }

        for c in 0..<channelCount { for i in 0..<count { outChannels[c][i] = channels[c][start + i] } }
        out.frameLength = AVAudioFrameCount(count)
        return out
    }

    static func buffer(from samples: [Float], sampleRate: Double) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        for (i, s) in samples.enumerated() { channel[i] = s }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        return buffer
    }
}

/// Steers one continuous sound from the main thread while the audio thread plays it.
private protocol AmbientControl: AnyObject {
    func set(level: Double, tone: Double)
}

/// The settings the audio thread reads while it plays a continuous sound, and the synth it drives.
private final class AmbientBox<Synth: AmbientSynth>: AmbientControl, @unchecked Sendable {
    private let lock = NSLock()
    private var synth: Synth
    private var level = 0.0
    private var tone = 0.0

    init(_ synth: Synth) { self.synth = synth }

    func set(level: Double, tone: Double) {
        lock.lock(); self.level = level; self.tone = tone; lock.unlock()
    }

    func render(into out: UnsafeMutablePointer<Float>, frames: Int, sampleRate: Double) {
        lock.lock()
        defer { lock.unlock() }
        // Nothing to compute while the sound is off and has faded out.
        if level == 0 && synth.currentGain < 1e-5 {
            out.update(repeating: 0, count: frames)
            return
        }
        synth.render(into: out, frames: frames, sampleRate: sampleRate, level: level, tone: tone)
    }
}

/// Every sound in the app, played through one audio engine so they mix cleanly and start without delay.
@MainActor
final class SoundEffects {
    static let shared = SoundEffects()

    enum Effect: CaseIterable {
        /// A button being pressed.
        case button
        /// The pointer moving onto a button.
        case hover
        /// One part of a lesson done.
        case partFinished
        /// A whole lesson done.
        case lessonFinished
    }

    /// The continuous sounds that play for as long as something is happening.
    enum Ambient: CaseIterable {
        /// The knife going through the cake.
        case cut
        /// Water running in the shower.
        case shower
        /// Candles burning.
        case candles
    }

    /// Turn off to silence everything (tests, and anything that shouldn't make noise).
    var isEnabled = true

    private let engine: AVAudioEngine
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private var voices: [Effect: [AVAudioPlayerNode]] = [:]
    private var nextVoice: [Effect: Int] = [:]
    private var clickBuffers: [AVAudioPCMBuffer] = []
    private var clickVoices: [AVAudioPlayerNode] = []
    private var nextClickVoice = 0
    private var ambient: [Ambient: AmbientControl] = [:]
    private var isPrepared = false
    private var lastRestart = Date.distantPast
    private var lastHover = Date.distantPast
    private var lastPress = Date.distantPast
    /// How many hover sounds have been played, which is what tests look at.
    private(set) var hoverPlayCount = 0
    private let clock: () -> Date

    /// Hover sounds are at least this far apart, and stay quiet for this long after a button is pressed. Pressing a
    /// button shrinks it a little, so the pointer can slip out and back in at its edge and would otherwise sound again.
    static let hoverSpacing = 0.08
    static let hoverQuietAfterPress = 0.3
    private var observer: NSObjectProtocol?

    private static let clickPitches = 8
    private static let clickVoiceCount = 6
    private static let sampleRate = 48_000.0

    init(engine: AVAudioEngine = AVAudioEngine(), clock: @escaping () -> Date = Date.init) {
        self.engine = engine
        self.clock = clock
    }

    /// Loads everything and starts the engine. Safe to call again.
    func prepare() {
        guard !isPrepared else { return }
        isPrepared = true

        let sources: [(Effect, String, Int)] = [(.button, SoundData.button, 3), (.hover, SoundData.hover, 2), (.partFinished, SoundData.partFinished, 2), (.lessonFinished, SoundData.lessonFinished, 1)]
        for (effect, data, voiceCount) in sources {
            guard let buffer = SoundLoader.decode(base64: data) else { continue }
            buffers[effect] = buffer
            voices[effect] = (0..<voiceCount).map { _ in attachPlayer(format: buffer.format) }
        }

        for step in 0..<Self.clickPitches {
            let pitch = Double(step) / Double(Self.clickPitches - 1)
            let samples = HingeClickSynth.render(pitch: pitch, sampleRate: Self.sampleRate, seed: UInt32(step + 1))
            if let buffer = SoundLoader.buffer(from: samples, sampleRate: Self.sampleRate) { clickBuffers.append(buffer) }
        }
        if let format = clickBuffers.first?.format {
            clickVoices = (0..<Self.clickVoiceCount).map { _ in attachPlayer(format: format) }
        }

        ambient[.cut] = attachAmbient(CutSynth())
        ambient[.shower] = attachAmbient(ShowerSynth())
        ambient[.candles] = attachAmbient(CandleSynth())

        observer = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.engineConfigurationChanged() }
        }
        startEngine()
    }

    func play(_ effect: Effect) {
        guard isEnabled else { return }
        let now = clock()
        switch effect {
        case .button:
            lastPress = now
        case .hover:
            guard now.timeIntervalSince(lastHover) >= Self.hoverSpacing,
                  now.timeIntervalSince(lastPress) >= Self.hoverQuietAfterPress else { return }
            lastHover = now
            hoverPlayCount += 1
        default:
            break
        }
        prepare()
        guard let buffer = buffers[effect], let pool = voices[effect], !pool.isEmpty else { return }
        let index = nextVoice[effect, default: 0]
        nextVoice[effect] = (index + 1) % pool.count
        trigger(pool[index], buffer: buffer, volume: 1)
    }

    /// One click of the hinge. `pitch` is 0...1 (low to high) and `intensity` 0...1 (soft to firm).
    func hingeClick(pitch: Double, intensity: Double) {
        guard isEnabled else { return }
        prepare()
        guard !clickBuffers.isEmpty, !clickVoices.isEmpty else { return }
        let step = Int((min(max(pitch, 0), 1) * Double(clickBuffers.count - 1)).rounded())
        let voice = clickVoices[nextClickVoice]
        nextClickVoice = (nextClickVoice + 1) % clickVoices.count
        trigger(voice, buffer: clickBuffers[step], volume: Float(min(max(intensity, 0), 1)))
    }

    /// Steers a continuous sound: `level` 0...1 for loudness, and `tone` 0...1 for its character (see each synth).
    func setAmbient(_ kind: Ambient, level: Double, tone: Double = 0) {
        guard isEnabled else { return }
        prepare()
        ambient[kind]?.set(level: level, tone: tone)
    }

    func stopAmbient(_ kind: Ambient) {
        ambient[kind]?.set(level: 0, tone: 0)
    }

    /// The knife's sound: `level` for loudness, `depth` 0...1 for how far down it is.
    func setCut(level: Double, depth: Double) { setAmbient(.cut, level: level, tone: depth) }

    func stopCut() { stopAmbient(.cut) }

    // MARK: - Engine

    private func attachPlayer(format: AVAudioFormat) -> AVAudioPlayerNode {
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        return node
    }

    /// Adds a continuous sound to the engine, silent until it is steered up.
    private func attachAmbient<Synth: AmbientSynth>(_ synth: Synth) -> AmbientControl? {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Self.sampleRate, channels: 1, interleaved: false) else { return nil }
        let box = AmbientBox(synth)
        let rate = Self.sampleRate
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let out = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            box.render(into: out, frames: Int(frameCount), sampleRate: rate)
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        return box
    }

    private func trigger(_ voice: AVAudioPlayerNode, buffer: AVAudioPCMBuffer, volume: Float) {
        startEngine()
        guard engine.isRunning else { return }
        voice.stop()
        voice.volume = volume
        voice.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        voice.play()
    }

    private func startEngine() {
        guard !engine.isRunning else { return }
        engine.prepare()
        do { try engine.start() } catch { DebugLog.write("sound engine failed to start: \(error.localizedDescription)") }
    }

    /// The output device changed (headphones plugged in, say) and the engine stopped; start it again, but never in a hurry.
    private func engineConfigurationChanged() {
        guard Date().timeIntervalSince(lastRestart) > 0.3 else { return }
        lastRestart = Date()
        startEngine()
    }
}

// MARK: - Buttons

/// Plays the button sound the moment a button is pressed. Used by every button style in the app.
struct PressSound: ViewModifier {
    let isPressed: Bool

    func body(content: Content) -> some View {
        content.onChange(of: isPressed) { _, pressed in
            if pressed { SoundEffects.shared.play(.button) }
        }
    }
}

/// Plays the hover sound when the pointer moves onto a view.
struct HoverSound: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { hovering in
            if hovering { SoundEffects.shared.play(.hover) }
        }
    }
}

/// A button that looks like its label, and makes the press sound when pressed, and the hover sound and pointing-hand
/// cursor when the pointer arrives. Set `hoverSound` to false where the button's owner already tracks hover itself.
struct SoundPlainButtonStyle: ButtonStyle {
    var hoverSound = true

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if hoverSound {
                configuration.label.modifier(HoverSound()).modifier(PointerCursor())
            } else {
                configuration.label
            }
        }
        .modifier(PressSound(isPressed: configuration.isPressed))
    }
}
