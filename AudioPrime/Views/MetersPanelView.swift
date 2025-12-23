//
//  MetersPanelView.swift
//  AudioPrime
//
//  Professional metering panel (LUFS, True Peak, VU)
//  Bottom center panel in main layout
//

import SwiftUI

struct MetersPanelView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Professional Meters", icon: "chart.bar.fill")

            HStack(spacing: 12) {
                // LUFS Loudness Meter
                LUFSMeterView(viewModel: viewModel)

                Divider()

                // True Peak Meter
                TruePeakMeterView(viewModel: viewModel)

                Divider()

                // BPM Detector
                BPMMeterView(viewModel: viewModel)

                Divider()

                // Level Meters (L/R)
                LevelMetersView(viewModel: viewModel)
            }
            .padding(12)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct LUFSMeterView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        VStack(spacing: 8) {
            Text("LUFS Loudness")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                MeterRow(label: "M", value: viewModel.momentaryLoudness, unit: "LUFS", color: .green)
                MeterRow(label: "S", value: viewModel.shortTermLoudness, unit: "LUFS", color: .blue)
                MeterRow(label: "I", value: viewModel.integratedLoudness, unit: "LUFS", color: .purple)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct TruePeakMeterView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        VStack(spacing: 8) {
            Text("True Peak")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            Text(String(format: "%.1f", viewModel.truePeak))
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(viewModel.truePeak > -1.0 ? .red : .green)

            Text("dBTP")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct BPMMeterView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        VStack(spacing: 8) {
            Text("Tempo")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                if viewModel.beatDetected {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .animation(.easeInOut(duration: 0.1), value: viewModel.beatDetected)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                }

                Text(String(format: "%.0f", viewModel.currentBPM))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }

            Text("BPM")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LevelMetersView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        VStack(spacing: 8) {
            Text("Levels")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                VerticalMeter(label: "L", value: viewModel.leftLevel, color: .green)
                VerticalMeter(label: "R", value: viewModel.rightLevel, color: .blue)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct MeterRow: View {
    let label: String
    let value: Float
    let unit: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
                .frame(width: 15)

            Text(String(format: "%.1f", value))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 50, alignment: .trailing)

            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct VerticalMeter: View {
    let label: String
    let value: Float
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Background
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))

                    // Level bar
                    Rectangle()
                        .fill(color)
                        .frame(height: geometry.size.height * CGFloat(value))
                }
            }
            .frame(width: 30)
            .cornerRadius(4)

            Text(label)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    MetersPanelView(viewModel: AudioViewModel())
        .frame(width: 800, height: 200)
}
