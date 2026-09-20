import Foundation

/// The hinge's click, built to match sampleHinge.mp3, which is a run of short low-pitched clicks about 66 ms apart.
/// Measured from that sample, the pitch climbs from about 200 Hz to 700 Hz along the run while each click gets
/// tighter, decaying in 44 ms at first and 16 ms by the end, and nearly all the energy sits below 700 Hz. So a click's
/// `pitch` (0 to 1) sets both, and the app maps the hinge angle onto it: the further the hinge opens, the higher and
/// tighter the click, like a ratchet tightening.
enum HingeClickSynth {
    static let lowestHz = 200.0
    static let highestHz = 700.0
    /// Time for a click to fall to a tenth of its loudness, at the lowest and highest pitch (from the sample).
    static let slowestDecay = 0.044
    static let fastestDecay = 0.016
    static let peak: Float = 0.8

    static func frequency(pitch: Double) -> Double {
        lowestHz + (highestHz - lowestHz) * min(max(pitch, 0), 1)
    }

    /// Seconds for the click to fall to a tenth of its peak.
    static func decayToTenth(pitch: Double) -> Double {
        slowestDecay + (fastestDecay - slowestDecay) * min(max(pitch, 0), 1)
    }

    static func render(pitch: Double, sampleRate: Double, seed: UInt32 = 1) -> [Float] {
        let f0 = frequency(pitch: pitch)
        let tau = decayToTenth(pitch: pitch) / log(10.0)          // exponential time constant
        let length = Int((min(6 * tau + 0.012, 0.12)) * sampleRate)

        var noise = seed | 1
        var lowNoise = 0.0
        var phase = 0.0, phase2 = 0.0, phaseSub = 0.0
        var samples = [Float](repeating: 0, count: length)

        for i in 0..<length {
            let t = Double(i) / sampleRate
            // The body of the click: a damped tone that drops slightly in pitch as it rings out, with a
            // brighter overtone that dies faster and a sub tone for weight.
            let glide = 1 + 0.12 * exp(-t / 0.008)
            phase += 2 * .pi * f0 * glide / sampleRate
            phase2 += 2 * .pi * f0 * 2.05 * glide / sampleRate
            phaseSub += 2 * .pi * f0 * 0.5 / sampleRate
            let body = exp(-t / tau) * (sin(phase) + 0.18 * exp(-t / (0.5 * tau)) * sin(phase2) + 0.35 * sin(phaseSub))

            // A very short, soft, dark thump at the front, so it reads as a click rather than a tone. It is kept low
            // and smooth: the sample is a dull clunk, not a bright tick.
            noise ^= noise << 13; noise ^= noise >> 17; noise ^= noise << 5
            let white = Double(noise) / Double(UInt32.max) * 2 - 1
            lowNoise += (white - lowNoise) * 0.05
            let thump = 1.2 * lowNoise * exp(-t / 0.003)

            let attack = min(t / 0.0008, 1)
            samples[i] = Float((body + thump) * attack)
        }

        // A soft overall roll-off (about 1.2 kHz), so no faint brightness is left: the sample is a dull clunk.
        var smooth = 0.0
        for i in 0..<length {
            smooth += (Double(samples[i]) - smooth) * 0.14
            samples[i] = Float(smooth)
        }

        let top = samples.map { abs($0) }.max() ?? 1
        let scale = top > 0 ? peak / top : 0
        return samples.map { $0 * scale }
    }
}

/// Decides when the hinge has turned far enough to click. It clicks each time the hinge has moved a full step from where
/// it last clicked, in either direction. Measuring from the last click, not the last reading, means the sensor
/// flickering by a degree while the hinge is still doesn't make it chatter.
struct HingeClickTracker {
    /// Degrees of hinge travel per click.
    static let step = 1.5
    /// The most clicks one reading can produce, however far the hinge jumped.
    static let maxPerUpdate = 3
    /// The hinge angles that map onto the lowest and highest click pitch.
    static let pitchRange: ClosedRange<Double> = 40...130

    struct Click: Equatable {
        /// 0...1 for the click's pitch.
        var pitch: Double
        /// 0...1 for how firmly it is played; a quicker turn is louder.
        var intensity: Double
    }

    private var lastClickAngle: Double?
    private var lastAngle: Double?
    private var timeSinceChange = 0.0

    static func pitch(forAngle angle: Double) -> Double {
        min(max((angle - pitchRange.lowerBound) / (pitchRange.upperBound - pitchRange.lowerBound), 0), 1)
    }

    /// Feed each hinge reading (degrees), once per frame. `dt` is the time since the last call. The sensor only
    /// updates now and then, so speed is measured over the time since the reading last changed.
    mutating func update(angle: Double, dt: Double) -> [Click] {
        timeSinceChange += dt
        var speed = 0.0
        if let lastAngle, angle != lastAngle {
            speed = abs(angle - lastAngle) / max(timeSinceChange, 1e-3)
            timeSinceChange = 0
        }
        lastAngle = angle

        guard let anchor = lastClickAngle else {
            lastClickAngle = angle
            return []
        }
        let intensity = min(0.55 + speed / 60, 1)

        var clicks: [Click] = []
        var position = anchor
        while abs(angle - position) >= Self.step && clicks.count < Self.maxPerUpdate {
            position += (angle > position ? 1 : -1) * Self.step
            clicks.append(Click(pitch: Self.pitch(forAngle: position), intensity: intensity))
        }
        lastClickAngle = clicks.count == Self.maxPerUpdate ? angle : position
        return clicks
    }

    mutating func reset() {
        lastClickAngle = nil
        lastAngle = nil
        timeSinceChange = 0
    }
}

/// A cheap deterministic noise source (xorshift), so every synth sounds the same every time it is played.
struct NoiseSource {
    private var state: UInt32

    init(seed: UInt32) { state = seed | 1 }

    /// White noise in -1...1.
    mutating func next() -> Double {
        state ^= state << 13; state ^= state >> 17; state ^= state << 5
        return Double(state) / Double(UInt32.max) * 2 - 1
    }

    /// A number in 0...1.
    mutating func unit() -> Double { (next() + 1) / 2 }
}

/// A sound that is generated continuously, and whose loudness and character are steered while it plays.
/// `level` (0...1) is how loud it should be and `tone` (0...1) is how bright or intense; what that means depends on the sound.
protocol AmbientSynth {
    /// The loudness right now, which follows `level` smoothly. Zero means the sound has faded out completely.
    var currentGain: Double { get }
    mutating func render(into out: UnsafeMutablePointer<Float>, frames: Int, sampleRate: Double, level: Double, tone: Double)
}

/// The soft, continuous sound of the knife going through the cake: a warm, breathy "hush" that rises in pitch as the
/// knife sinks, the same rising character as the hinge clicks and in the same register as the chimes.
///
/// Its body is a soft chord of tones (a fifth and an octave apart) that drift very slightly against each other, with a
/// little breath of narrow-band noise on top. Tones have no random loudness flicker, and each noise band is only
/// ~20 Hz wide, so nothing in it can beat in the 30-150 Hz range that sounds like buzzing. A chainsaw is the opposite:
/// wide noise that flutters in exactly that range.
struct CutSynth: AmbientSynth {
    static let lowestHz = 200.0
    static let highestHz = 700.0
    /// Loudest the sound ever gets, kept low so it sits under the other effects.
    static let maxAmplitude = 0.16
    /// How quickly the volume follows its target, in seconds; slow enough that it swells rather than jumps.
    static let smoothing = 0.08
    /// The tones, as multiples of the centre pitch, with how strong each is and how fast each drifts.
    static let partials: [(ratio: Double, weight: Double, driftHz: Double)] = [(1.0, 1.0, 0.31), (1.5, 0.5, 0.47), (2.0, 0.25, 0.71)]
    /// How much noise is mixed under the tones, and how narrow each noise band is (pitch divided by width).
    static let breathAmount = 0.25
    static let sharpness = 25.0

    private var noise = NoiseSource(seed: 0x1234_5678)
    private var low = [Double](repeating: 0, count: 3)
    private var band = [Double](repeating: 0, count: 3)
    private var phase = [Double](repeating: 0, count: 3)
    private var drift = [0.0, 1.7, 3.1]
    private var breath = 0.0
    private var softened = 0.0
    private(set) var currentGain = 0.0

    static func centre(depth: Double) -> Double {
        lowestHz + (highestHz - lowestHz) * min(max(depth, 0), 1)
    }

    /// `tone` is how deep the knife is.
    mutating func render(into out: UnsafeMutablePointer<Float>, frames: Int, sampleRate: Double, level: Double, tone depth: Double) {
        let target = min(max(level, 0), 1) * Self.maxAmplitude
        let gainStep = 1 - exp(-1 / (Self.smoothing * sampleRate))
        let centre = Self.centre(depth: depth)
        let damping = 1 / Self.sharpness
        let filters = Self.partials.map { 2 * sin(.pi * min($0.ratio * centre, sampleRate / 6) / sampleRate) }
        // A narrow noise band lets little through; the wider the band, the more, so keep the loudness steady.
        let breathNorm = 0.9 * (centre / 400).squareRoot()
        // A final gentle roll-off above the chord's top tone, so no trace of hiss can be left.
        let softenA = 1 - exp(-2 * .pi * 1700 / sampleRate)

        for i in 0..<frames {
            currentGain += (target - currentGain) * gainStep
            let white = noise.next()

            var tones = 0.0, breathy = 0.0
            for j in 0..<3 {
                let partial = Self.partials[j]
                // Each tone wanders a fraction of a percent in pitch, slowly, so together they shimmer rather than sit still.
                drift[j] += 2 * .pi * partial.driftHz / sampleRate
                if drift[j] > 2 * .pi { drift[j] -= 2 * .pi }
                phase[j] += 2 * .pi * partial.ratio * centre * (1 + 0.006 * sin(drift[j])) / sampleRate
                if phase[j] > 2 * .pi { phase[j] -= 2 * .pi }
                tones += partial.weight * sin(phase[j])

                low[j] += filters[j] * band[j]
                let high = white - low[j] - damping * band[j]
                band[j] += filters[j] * high
                breathy += partial.weight * band[j]
            }

            breath += 2 * .pi * 0.5 / sampleRate
            if breath > 2 * .pi { breath -= 2 * .pi }

            let mix = (0.30 * tones + Self.breathAmount * breathNorm * breathy) * (1 + 0.08 * sin(breath))
            softened += softenA * (mix - softened)
            out[i] = Float(tanh(softened * currentGain * 1.6))
        }
    }
}

/// A gentle shower: a soft hiss with the fine patter of droplets on the plate. Kept quiet and rolled off, so it sits
/// in the background. `tone` brightens it slightly.
struct ShowerSynth: AmbientSynth {
    static let maxAmplitude = 0.06
    static let smoothing = 0.15
    /// Droplets per second.
    static let dropletRate = 110.0

    private var noise = NoiseSource(seed: 0x9E37_79B9)
    private var dropletNoise = NoiseSource(seed: 0x7F4A_7C15)
    private var lowPass900 = 0.0
    private var soft1 = 0.0, soft2 = 0.0
    private var ringLow = 0.0, ringBand = 0.0
    private(set) var currentGain = 0.0

    mutating func render(into out: UnsafeMutablePointer<Float>, frames: Int, sampleRate: Double, level: Double, tone: Double) {
        let target = min(max(level, 0), 1) * Self.maxAmplitude
        let gainStep = 1 - exp(-1 / (Self.smoothing * sampleRate))
        let highPassA = 1 - exp(-2 * .pi * 900 / sampleRate)
        let softA = 1 - exp(-2 * .pi * (5000 + 1500 * min(max(tone, 0), 1)) / sampleRate)
        // The droplets ring a narrow band around 3.2 kHz.
        let ringF = 2 * sin(.pi * 3200 / sampleRate)
        let ringDamping = 1 / 5.0
        let dropletChance = Self.dropletRate / sampleRate

        for i in 0..<frames {
            currentGain += (target - currentGain) * gainStep

            // Hiss: noise with the low end taken out and the top rolled off.
            let white = noise.next()
            lowPass900 += highPassA * (white - lowPass900)
            let highPassed = white - lowPass900
            soft1 += softA * (highPassed - soft1)
            soft2 += softA * (soft1 - soft2)

            // Patter: occasional small impulses, each ringing briefly.
            var impulse = 0.0
            if dropletNoise.unit() < dropletChance { impulse = 0.4 + 0.6 * dropletNoise.unit() }
            ringLow += ringF * ringBand
            let ringHigh = impulse * 6 - ringLow - ringDamping * ringBand
            ringBand += ringF * ringHigh

            out[i] = Float(tanh((soft2 * 1.5 + ringBand * 0.32) * currentGain * 3))
        }
    }
}

/// Candles burning: a low, soft flutter of flame with the odd tiny crackle. `tone` is how turbulent the flames are,
/// such as when someone blows on them: more flutter and more crackle.
struct CandleSynth: AmbientSynth {
    static let maxAmplitude = 0.12
    static let smoothing = 0.25
    /// Crackles per second when calm, and how many more per second at full turbulence.
    static let calmCrackleRate = 1.6
    static let extraCrackleRate = 6.0

    private var noise = NoiseSource(seed: 0x2545_F491)
    private var events = NoiseSource(seed: 0x6C07_8965)
    private var rumble1 = 0.0, rumble2 = 0.0, rumble3 = 0.0
    private var flicker = 0.8, flickerTarget = 0.8
    private var samplesToFlickerChange = 0
    private var samplesToCrackle = 0
    private var crackleEnvelope = 0.0, crackleAmount = 0.0
    private var crackleLow = 0.0
    private var whooshLow = 0.0, whooshBand = 0.0
    private(set) var currentGain = 0.0

    mutating func render(into out: UnsafeMutablePointer<Float>, frames: Int, sampleRate: Double, level: Double, tone: Double) {
        let turbulence = min(max(tone, 0), 1)
        let target = min(max(level, 0), 1) * Self.maxAmplitude
        let gainStep = 1 - exp(-1 / (Self.smoothing * sampleRate))
        let rumbleA = 1 - exp(-2 * .pi * 140 / sampleRate)
        let flickerA = 1 - exp(-1 / (0.07 * sampleRate))
        let crackleHighA = 1 - exp(-2 * .pi * 1800 / sampleRate)
        let whooshF = 2 * sin(.pi * 700 / sampleRate)

        for i in 0..<frames {
            currentGain += (target - currentGain) * gainStep
            let white = noise.next()

            // The soft body of the flame: dull low noise that swells and dips like a flicker.
            rumble1 += rumbleA * (white - rumble1)
            rumble2 += rumbleA * (rumble1 - rumble2)
            rumble3 += rumbleA * (rumble2 - rumble3)
            if samplesToFlickerChange <= 0 {
                flickerTarget = (0.65 - 0.35 * turbulence) + (0.35 + 0.35 * turbulence) * events.unit()
                samplesToFlickerChange = Int((0.08 + 0.14 * events.unit()) * sampleRate)
            }
            samplesToFlickerChange -= 1
            flicker += flickerA * (flickerTarget - flicker)

            // A breathy whoosh that only appears when the flames are being blown.
            whooshLow += whooshF * whooshBand
            let whooshHigh = white - whooshLow - 0.9 * whooshBand
            whooshBand += whooshF * whooshHigh

            // Now and then, a tiny crackle: a few milliseconds of bright noise.
            if samplesToCrackle <= 0 {
                let rate = Self.calmCrackleRate + Self.extraCrackleRate * turbulence
                samplesToCrackle = Int(-log(max(events.unit(), 1e-4)) / rate * sampleRate)
                crackleAmount = 0.2 + 0.5 * events.unit()
                crackleEnvelope = 1
            }
            samplesToCrackle -= 1
            crackleLow += crackleHighA * (white - crackleLow)
            let crackle = (white - crackleLow) * crackleEnvelope * crackleAmount
            crackleEnvelope *= exp(-1 / (0.004 * sampleRate))

            let body = rumble3 * 8 * flicker + whooshBand * 0.35 * turbulence + crackle * 0.5
            out[i] = Float(tanh(body * currentGain * 2.2))
        }
    }
}

/// How loud the cutting sound is: steady while the knife is being pressed down, plus more while it is actually moving.
enum CutSoundLevel {
    /// Loudness sustained while pressing, per unit of depth.
    static let sustain = 0.28
    /// Extra loudness per unit of knife speed (depth per second), whichever way it moves.
    static let motion = 0.35

    static func level(depth: Double, speed: Double, pressing: Bool) -> Double {
        let held = pressing ? sustain * min(max(depth, 0), 1) : 0
        return min(held + motion * abs(speed), 1)
    }
}

/// How loud the candles are: silent until the flames are lit, then a steady soft flutter, gone as they are blown out.
enum CandleSoundLevel {
    /// Loudness of the flutter while the candles burn (the synth itself is already quiet).
    static let steady = 0.7
    /// How quickly the flame sound dies once the candles are blown out.
    static let fadeOutDuration = 0.35

    /// `lit` is 0...1, how much of the flames' lighting animation is done; `blowOutElapsed` is nil while lit.
    static func level(lit: Double, blowOutElapsed: Double?) -> Double {
        let burning = steady * min(max(lit, 0), 1)
        guard let elapsed = blowOutElapsed else { return burning }
        return burning * (1 - min(max(elapsed / fadeOutDuration, 0), 1))
    }
}

/// How loud the shower is: a soft, steady patter while water is running, gone when it stops.
enum ShowerSoundLevel {
    static let steady = 0.7

    /// `streamOpacity` is 1 while the water runs and falls to 0 as it stops.
    static func level(streamOpacity: Double) -> Double {
        steady * min(max(streamOpacity, 0), 1)
    }
}
