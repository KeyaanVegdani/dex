import SwiftUI

/// The original sensor readout window (hinge, trackpad force, microphone). Kept for reference
/// while the lesson flow is built; it is not currently shown by the app.
struct SensorDashboardView: View {
    @ObservedObject var lid: LidAngleSensor
    @ObservedObject var force: TrackpadForce
    @ObservedObject var mic: MicMonitor

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 14) {
                hingeSection
                micSection
            }
            forceSection
        }
        .padding(20)
        .frame(width: 800)
    }

    // MARK: - Hinge

    private var hingeSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                ReadoutField(title: "hinge_reading (0–100)", value: lid.hingeReading.map { String(format: "%.1f", $0) } ?? "—")
                ReadoutField(title: "Hinge angle", value: lid.angle.map(Self.degrees) ?? "—")
                ReadoutField(title: "Observed min / max",
                             value: "\(lid.minSeen.map(Self.degrees) ?? "—") / \(lid.maxSeen.map(Self.degrees) ?? "—")")

                Gauge(value: lid.hingeReading ?? 0, in: 0...100) { EmptyView() }
                    .gaugeStyle(.linearCapacity)

                HStack {
                    if case .unavailable(let reason) = lid.status {
                        Text(reason).font(.caption).foregroundStyle(.red)
                    }
                    Spacer()
                    Button("Reset min/max") { lid.resetObservedRange() }
                        .controlSize(.small)
                }
            }
            .padding(6)
        } label: {
            Label("Hinge", systemImage: "laptopcomputer")
        }
    }

    // MARK: - Trackpad force

    private var forceSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                ReadoutField(title: "pressure_reading (1–10)", value: String(format: "%.1f", force.pressureReading))
                ReadoutField(title: "Raw pressure", value: String(format: "%.3f", force.pressure))
                ReadoutField(title: "Stage", value: "\(force.stage)")
                ReadoutField(title: "Peak raw pressure", value: String(format: "%.3f", force.peak))

                Gauge(value: force.pressureReading, in: 1...10) { EmptyView() }
                    .gaugeStyle(.linearCapacity)

                pressPad

                HStack {
                    Spacer()
                    Button("Reset peak") { force.resetPeak() }
                        .controlSize(.small)
                }
            }
            .padding(6)
        } label: {
            Label("Trackpad force", systemImage: "hand.tap")
        }
    }

    private var pressPad: some View {
        ZStack {
            ForcePad(model: force)

            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.10 + 0.6 * Double(min(force.pressure, 1))))
                .allowsHitTesting(false)
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(.secondary)
                .allowsHitTesting(false)
            Text(force.isPressed ? "Pressing…" : "Click and press firmly here")
                .foregroundStyle(.secondary)
                .allowsHitTesting(false)
        }
        .frame(height: 90)
    }

    // MARK: - Microphone

    private var micSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                ReadoutField(title: "blow_reading (1–10)", value: String(format: "%.1f", mic.blowReading))
                ReadoutField(title: "Input level", value: mic.levelDB.map(Self.decibels) ?? "—")
                ReadoutField(title: "Noise floor / threshold",
                             value: "\(mic.noiseFloorDB.map(Self.decibels) ?? "…") / \(mic.thresholdDB.map(Self.decibels) ?? "…")")

                Gauge(value: mic.blowReading, in: 1...10) { EmptyView() }
                    .gaugeStyle(.linearCapacity)

                HStack(alignment: .top) {
                    Text(Self.statusText(mic.status))
                        .font(.caption)
                        .foregroundStyle(Self.isProblem(mic.status) ? Color.red : Color.secondary)
                    Spacer()
                    Button("Recalibrate") { mic.recalibrate() }
                        .controlSize(.small)
                }
            }
            .padding(6)
        } label: {
            Label("Microphone", systemImage: "mic")
        }
    }

    // MARK: - Formatting

    private static func degrees(_ value: Double) -> String {
        String(format: "%.0f°", value)
    }

    private static func decibels(_ value: Double) -> String {
        String(format: "%.1f dB", value)
    }

    private static func statusText(_ status: MicMonitor.Status) -> String {
        switch status {
        case .idle: return "Starting…"
        case .calibrating: return "Calibrating background noise — stay quiet for a moment."
        case .listening: return "Listening — blow into the mic."
        case .denied: return "Microphone access denied. Allow it in System Settings › Privacy & Security › Microphone."
        case .unavailable(let reason): return reason
        }
    }

    private static func isProblem(_ status: MicMonitor.Status) -> Bool {
        switch status {
        case .denied, .unavailable: return true
        default: return false
        }
    }
}

/// A labelled, non-editable text field used to display a live value.
struct ReadoutField: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title) {
            TextField("", text: .constant(value))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 170)
                .allowsHitTesting(false)
        }
    }
}
