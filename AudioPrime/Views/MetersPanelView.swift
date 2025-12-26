//
//  MetersPanelView.swift
//  AudioPrime
//
//  Professional metering panel (LUFS, True Peak, VU)
//  Bottom panel in main layout - matches original AUDIO_PRIME design
//

import SwiftUI

struct MetersPanelView: View {
    @ObservedObject var viewModel: AudioViewModel
    @Binding var showDebug: Bool

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Professional Meters", icon: "chart.bar.fill")

            HStack(spacing: 16) {
                // LUFS Loudness Meters (with visual bars)
                LUFSMeterView(viewModel: viewModel)
                    .frame(minWidth: 220)

                Divider()

                // True Peak Meter (with visual bar)
                TruePeakMeterView(viewModel: viewModel)
                    .frame(width: 100)

                Divider()

                // VU Meters (L/R)
                VUMetersView(viewModel: viewModel)
                    .frame(width: 140)

                Divider()

                // BPM Display
                BPMMeterView(viewModel: viewModel)
                    .frame(width: 80)

                Spacer()
            }
            .padding(12)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - LUFS Meter with Visual Bars
struct LUFSMeterView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        VStack(spacing: 6) {
            Text("LUFS Loudness")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                LUFSBarView(label: "M", value: viewModel.momentaryLoudness, color: .green)
                LUFSBarView(label: "S", value: viewModel.shortTermLoudness, color: .blue)
                LUFSBarView(label: "I", value: viewModel.integratedLoudness, color: .purple)
            }

            // Scale
            LUFSScaleView()
        }
    }
}

struct LUFSBarView: View {
    let label: String
    let value: Float
    let color: Color

    // Map LUFS (-60 to 0) to percentage (0 to 1)
    private var percentage: CGFloat {
        let clamped = max(-60.0, min(0.0, value))
        return CGFloat((clamped + 60.0) / 60.0)
    }

    // Dynamic color based on LUFS value
    private var dynamicColor: Color {
        if value > -9 { return .red }
        if value > -14 { return .orange }
        if value > -18 { return .yellow }
        return .green
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 14)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))

                    // Meter fill with dynamic color
                    Rectangle()
                        .fill(dynamicColor.opacity(0.8))
                        .frame(width: geometry.size.width * percentage)

                    // Target markers
                    // -14 LUFS (streaming target)
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 1)
                        .offset(x: geometry.size.width * CGFloat((60.0 - 14.0) / 60.0))

                    // -23 LUFS (EBU R128 target)
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 1)
                        .offset(x: geometry.size.width * CGFloat((60.0 - 23.0) / 60.0))
                }
            }
            .frame(height: 12)
            .cornerRadius(2)

            Text(String(format: "%5.1f", value))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(dynamicColor)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

struct LUFSScaleView: View {
    let ticks: [(CGFloat, String)] = [
        (0.0, "-60"),
        (0.4, "-36"),
        (0.6, "-24"),
        (0.767, "-14"),
        (1.0, "0")
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                ForEach(ticks, id: \.0) { tick in
                    Text(tick.1)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .offset(x: (geometry.size.width - 54) * tick.0 + 20 - 10)
                }
            }
        }
        .frame(height: 12)
    }
}

// MARK: - True Peak Meter with Visual Bar
struct TruePeakMeterView: View {
    @ObservedObject var viewModel: AudioViewModel

    // Map dBTP (-60 to +3) to percentage
    private var percentage: CGFloat {
        let clamped = max(-60.0, min(3.0, viewModel.truePeak))
        return CGFloat((clamped + 60.0) / 63.0)
    }

    private var meterColor: Color {
        if viewModel.truePeak > 0 { return .red }
        if viewModel.truePeak > -1 { return .orange }
        if viewModel.truePeak > -3 { return .yellow }
        return .green
    }

    var body: some View {
        VStack(spacing: 6) {
            Text("True Peak")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                // Vertical bar
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        // Background
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))

                        // Meter fill
                        Rectangle()
                            .fill(truePeakGradient)
                            .frame(height: geometry.size.height * percentage)

                        // 0 dBTP line (clip threshold)
                        Rectangle()
                            .fill(Color.red)
                            .frame(height: 2)
                            .offset(y: -geometry.size.height * CGFloat(60.0 / 63.0) + 1)

                        // -1 dBTP line (headroom)
                        Rectangle()
                            .fill(Color.orange.opacity(0.7))
                            .frame(height: 1)
                            .offset(y: -geometry.size.height * CGFloat(59.0 / 63.0) + 0.5)
                    }
                }
                .frame(width: 20)
                .cornerRadius(3)

                // Scale labels
                VStack {
                    Text("+3")
                    Spacer()
                    Text("0")
                    Spacer()
                    Text("-20")
                    Spacer()
                    Text("-60")
                }
                .font(.system(size: 7))
                .foregroundColor(.secondary)
            }

            // Value display
            Text(String(format: "%.1f", viewModel.truePeak))
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(meterColor)

            Text("dBTP")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var truePeakGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .green, location: 0.0),
                .init(color: .green, location: 0.7),
                .init(color: .yellow, location: 0.85),
                .init(color: .orange, location: 0.93),
                .init(color: .red, location: 0.95)
            ]),
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

// MARK: - VU Meters (L/R)
struct VUMetersView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        VStack(spacing: 6) {
            Text("VU Meters")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                // Scale on left
                VStack {
                    Text("0")
                    Spacer()
                    Text("-12")
                    Spacer()
                    Text("-24")
                    Spacer()
                    Text("-48")
                }
                .font(.system(size: 7))
                .foregroundColor(.secondary)
                .frame(width: 20)

                VUMeterBar(
                    label: "L",
                    vuLevel: viewModel.vuLeft,
                    peakHold: viewModel.peakHoldLeft
                )

                VUMeterBar(
                    label: "R",
                    vuLevel: viewModel.vuRight,
                    peakHold: viewModel.peakHoldRight
                )
            }

            // RMS values
            HStack(spacing: 8) {
                Text(String(format: "L:%.1f", vuToDB(viewModel.vuLeft)))
                Text(String(format: "R:%.1f", vuToDB(viewModel.vuRight)))
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.secondary)
        }
    }

    private func vuToDB(_ level: Float) -> Float {
        level > 0 ? 20.0 * log10(level) : -60.0
    }
}

struct VUMeterBar: View {
    let label: String
    let vuLevel: Float
    let peakHold: Float

    private var vuDB: Float {
        vuLevel > 0 ? 20.0 * log10(vuLevel) : -60.0
    }

    private var peakHoldDB: Float {
        peakHold > 0 ? 20.0 * log10(peakHold) : -60.0
    }

    private func dbToNormalized(_ db: Float) -> CGFloat {
        let clamped = max(-60.0, min(0.0, db))
        return CGFloat((clamped + 60.0) / 60.0)
    }

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Background
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))

                    // VU level bar
                    Rectangle()
                        .fill(vuGradient)
                        .frame(height: geometry.size.height * dbToNormalized(vuDB))

                    // Peak hold indicator
                    Rectangle()
                        .fill(Color.red)
                        .frame(height: 2)
                        .offset(y: -geometry.size.height * dbToNormalized(peakHoldDB) + 1)

                    // Clip indicator
                    if peakHoldDB > -0.5 {
                        Rectangle()
                            .fill(Color.red)
                            .frame(height: 4)
                            .position(x: geometry.size.width / 2, y: 2)
                    }
                }
            }
            .frame(width: 28)
            .cornerRadius(3)

            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
        }
    }

    private var vuGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .green, location: 0.0),
                .init(color: .green, location: 0.6),
                .init(color: .yellow, location: 0.8),
                .init(color: .orange, location: 0.9),
                .init(color: .red, location: 0.95)
            ]),
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

// MARK: - BPM Display
struct BPMMeterView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        VStack(spacing: 6) {
            Text("Tempo")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            Spacer()

            // Beat indicator
            Circle()
                .fill(viewModel.beatDetected ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 16, height: 16)
                .animation(.easeInOut(duration: 0.1), value: viewModel.beatDetected)

            Text(String(format: "%.0f", viewModel.currentBPM))
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)

            Text("BPM")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

#Preview {
    MetersPanelView(viewModel: AudioViewModel(), showDebug: .constant(false))
        .frame(width: 700, height: 160)
}
