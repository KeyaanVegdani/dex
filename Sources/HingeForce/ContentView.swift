import SwiftUI

struct ContentView: View {
    @ObservedObject var lid: LidAngleSensor
    @ObservedObject var force: TrackpadForce

    var body: some View {
        VStack(spacing: 16) {
            hingeSection
            forceSection
        }
        .padding(20)
        .frame(width: 420)
    }

    // MARK: - Hinge

    private var hingeSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                ReadoutField(title: "Hinge angle", value: lid.angle.map(Self.degrees) ?? "—")
                ReadoutField(title: "Sensor range",
                             value: "\(Self.degrees(LidAngleSensor.range.lowerBound)) – \(Self.degrees(LidAngleSensor.range.upperBound))")
                ReadoutField(title: "Observed min / max",
                             value: "\(lid.minSeen.map(Self.degrees) ?? "—") / \(lid.maxSeen.map(Self.degrees) ?? "—")")

                Gauge(value: lid.angle ?? 0, in: LidAngleSensor.range) { EmptyView() }
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
                ReadoutField(title: "Pressure", value: String(format: "%.3f", force.pressure))
                ReadoutField(title: "Stage", value: "\(force.stage)")
                ReadoutField(title: "Peak pressure", value: String(format: "%.3f", force.peak))
                ReadoutField(title: "Pressure range",
                             value: String(format: "%.1f – %.1f", TrackpadForce.range.lowerBound, TrackpadForce.range.upperBound))

                Gauge(value: Double(min(max(force.pressure, TrackpadForce.range.lowerBound), TrackpadForce.range.upperBound)),
                      in: Double(TrackpadForce.range.lowerBound)...Double(TrackpadForce.range.upperBound)) { EmptyView() }
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
        .frame(height: 110)
    }

    private static func degrees(_ value: Double) -> String {
        String(format: "%.0f°", value)
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
