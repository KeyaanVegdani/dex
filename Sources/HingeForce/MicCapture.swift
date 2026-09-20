import AVFoundation
import CoreMedia
import Foundation

/// Turns the raw bytes of an audio buffer into mono float samples in -1...1.
enum PCMConverter {
    /// Reads channel 0 of interleaved PCM. Supports 32-bit float and 16-bit integer samples.
    static func monoSamples(from bytes: UnsafeRawBufferPointer, isFloat: Bool, bitsPerChannel: Int, channels: Int) -> [Float] {
        let channels = max(channels, 1)
        switch (isFloat, bitsPerChannel) {
        case (true, 32):
            let samples = bytes.bindMemory(to: Float.self)
            return stride(from: 0, to: samples.count - channels + 1, by: channels).map { samples[$0] }
        case (false, 16):
            let samples = bytes.bindMemory(to: Int16.self)
            return stride(from: 0, to: samples.count - channels + 1, by: channels).map { Float(samples[$0]) / 32768 }
        default:
            return []
        }
    }
}

/// Collects the capture's small buffers into ~100 ms frames, the frame length the blow detector's
/// levels and thresholds were tuned on. Shorter frames would read jumpier and hop to the UI far more often.
struct SampleBatcher {
    static let frameDuration: TimeInterval = 0.1

    private var pending: [Float] = []

    /// Adds samples; returns a complete frame once at least `frameDuration` has been gathered.
    mutating func add(_ samples: [Float], sampleRate: Double) -> [Float]? {
        pending.append(contentsOf: samples)
        guard Double(pending.count) >= sampleRate * Self.frameDuration else { return nil }
        defer { pending.removeAll(keepingCapacity: true) }
        return pending
    }
}

/// Records from one specific microphone with an `AVCaptureSession` and feeds the blow detector.
///
/// Unlike an `AVAudioEngine` bound to a device, a capture session takes the microphone it is given
/// without touching the system's audio routing, and it copes with route changes on its own. Starting
/// and stopping happen on a background queue, so a slow microphone can never freeze the interface.
final class MicCapture: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "HingeForce.mic.session")
    private let sampleQueue = DispatchQueue(label: "HingeForce.mic.samples")
    private let detector: BlowDetector
    private let deliver: @Sendable (BlowDetector.Output) -> Void
    private let onFailure: @Sendable (String) -> Void
    private var loggedFormat = false
    private var batcher = SampleBatcher()      // touched only on `sampleQueue`
    private var errorObserver: NSObjectProtocol?

    init(detector: BlowDetector,
         deliver: @escaping @Sendable (BlowDetector.Output) -> Void,
         onFailure: @escaping @Sendable (String) -> Void) {
        self.detector = detector
        self.deliver = deliver
        self.onFailure = onFailure
        super.init()
    }

    /// Starts recording from the device with `uid`. Returns immediately; problems are reported to `onFailure`.
    func start(deviceUID uid: String) {
        sessionQueue.async { [self] in
            guard let device = AVCaptureDevice(uniqueID: uid) else {
                onFailure("Couldn't open the built-in microphone.")
                return
            }
            do {
                let input = try AVCaptureDeviceInput(device: device)
                let output = AVCaptureAudioDataOutput()
                output.audioSettings = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMBitDepthKey: 32,
                    AVLinearPCMIsFloatKey: true,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false,
                    AVNumberOfChannelsKey: 1,
                ]
                output.setSampleBufferDelegate(self, queue: sampleQueue)

                session.beginConfiguration()
                guard session.canAddInput(input), session.canAddOutput(output) else {
                    session.commitConfiguration()
                    onFailure("Couldn't start recording from the built-in microphone.")
                    return
                }
                session.addInput(input)
                session.addOutput(output)
                session.commitConfiguration()

                errorObserver = NotificationCenter.default.addObserver(
                    forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil
                ) { [onFailure] note in
                    let error = note.userInfo?[AVCaptureSessionErrorKey] as? NSError
                    onFailure("The microphone stopped: \(error?.localizedDescription ?? "unknown error")")
                }
                DebugLog.write("capture starting on '\(device.localizedName)' uid=\(uid)")
                session.startRunning()
                DebugLog.write("capture running=\(session.isRunning)")
            } catch {
                onFailure("Couldn't open the built-in microphone: \(error.localizedDescription)")
            }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if let errorObserver { NotificationCenter.default.removeObserver(errorObserver) }
            errorObserver = nil
            if session.isRunning { session.stopRunning() }
            for input in session.inputs { session.removeInput(input) }
            for output in session.outputs { session.removeOutput(output) }
        }
    }

    // MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer),
              let description = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee,
              let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        var length = 0
        var pointer: UnsafeMutablePointer<CChar>?
        guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer) == kCMBlockBufferNoErr,
              let pointer else { return }

        let isFloat = description.mFormatFlags & kAudioFormatFlagIsFloat != 0
        let samples = PCMConverter.monoSamples(from: UnsafeRawBufferPointer(start: pointer, count: length),
                                               isFloat: isFloat,
                                               bitsPerChannel: Int(description.mBitsPerChannel),
                                               channels: Int(description.mChannelsPerFrame))
        guard !samples.isEmpty else { return }

        if !loggedFormat {
            loggedFormat = true
            DebugLog.write("first buffer sr=\(description.mSampleRate) ch=\(description.mChannelsPerFrame) bits=\(description.mBitsPerChannel) float=\(isFloat) frames=\(samples.count)")
        }
        guard let frame = batcher.add(samples, sampleRate: description.mSampleRate) else { return }
        let result = frame.withUnsafeBufferPointer { detector.process($0, sampleRate: description.mSampleRate) }
        deliver(result)
    }
}
