import AVFoundation
import Foundation

/// Listens to the Mac's built-in microphone and publishes a 1...10 `blow_reading`.
/// The signal processing lives in `BlowDetector` and the recording in `MicCapture`; this class
/// handles permission, choosing the microphone, and hopping results back to the main actor.
@MainActor
final class MicMonitor: ObservableObject {
    enum Status: Equatable {
        case idle
        case calibrating
        case listening
        case denied
        case unavailable(String)
    }

    @Published private(set) var blowReading: Double = 1
    @Published private(set) var levelDB: Double?
    @Published private(set) var noiseFloorDB: Double?
    @Published private(set) var thresholdDB: Double?
    @Published private(set) var status: Status = .idle
    /// The microphone being listened to (always the built-in one), once capture has started.
    @Published private(set) var inputDeviceName: String?

    private let detector = BlowDetector()
    private var capture: MicCapture?

    private var logCount = 0

    func start() {
        DebugLog.write("MicMonitor.start() capture=\(capture == nil ? "nil" : "present") auth=\(AVCaptureDevice.authorizationStatus(for: .audio).rawValue)")
        guard capture == nil else { return }

        // Without a usage description macOS terminates the process on mic access; the description is
        // embedded in the executable, so this only trips if that embedding is ever removed.
        guard Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") != nil else {
            status = .unavailable("The app is missing its microphone description.")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            beginCapture()
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                if granted { beginCapture() } else { status = .denied }
            }
        default:
            status = .denied
        }
    }

    func stop() {
        capture?.stop()
        capture = nil
        inputDeviceName = nil
    }

    /// Re-learns the background noise. Stay quiet for about two seconds afterwards.
    func recalibrate() {
        detector.recalibrate()
        noiseFloorDB = nil
        thresholdDB = nil
        blowReading = 1
        if capture != nil { status = .calibrating }
    }

    // MARK: - Capture

    private func beginCapture() {
        guard capture == nil else { return }

        // Always the MacBook's own microphone, never whatever the system default has become
        // (Bluetooth headsets and a nearby iPhone both take over as the default input).
        guard let microphone = AudioDevices.builtInMicrophone() else {
            status = .unavailable("Couldn't find this Mac's built-in microphone.")
            return
        }

        inputDeviceName = microphone.name
        status = .calibrating
        detector.recalibrate()

        let capture = MicCapture(
            detector: detector,
            deliver: { [weak self] output in Task { @MainActor in self?.apply(output) } },
            onFailure: { [weak self] message in Task { @MainActor in self?.fail(message) } }
        )
        self.capture = capture
        capture.start(deviceUID: microphone.uid)
    }

    private func fail(_ message: String) {
        DebugLog.write("capture failed: \(message)")
        capture?.stop()
        capture = nil
        inputDeviceName = nil
        status = .unavailable(message)
    }

    private func apply(_ output: BlowDetector.Output) {
        guard capture != nil else { return }
        logCount += 1
        if logCount % 3 == 0 {
            DebugLog.write(String(format: "mic level=%6.1f floor=%@ thr=%@ reading=%.2f calibrating=%d",
                                  output.levelDB, output.noiseFloorDB.map { String(format: "%.1f", $0) } ?? "-",
                                  output.thresholdDB.map { String(format: "%.1f", $0) } ?? "-", output.reading, output.isCalibrating ? 1 : 0))
        }
        blowReading = output.reading
        levelDB = output.levelDB
        noiseFloorDB = output.noiseFloorDB
        thresholdDB = output.thresholdDB
        status = output.isCalibrating ? .calibrating : .listening
    }
}
