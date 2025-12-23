//
//  AnalysisPanelView.swift
//  AudioPrime
//
//  Stereo and Voice analysis panel
//  Right panel in main layout
//

import SwiftUI

struct AnalysisPanelView: View {
    @ObservedObject var viewModel: AudioViewModel
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Analysis", icon: "waveform.path.ecg")

            // Tab selector
            Picker("", selection: $selectedTab) {
                Text("Stereo").tag(0)
                Text("Voice").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Tab content
            TabView(selection: $selectedTab) {
                StereoAnalysisView(viewModel: viewModel)
                    .tag(0)

                VoiceAnalysisView(viewModel: viewModel)
                    .tag(1)
            }
            .tabViewStyle(.automatic)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Stereo Analysis
struct StereoAnalysisView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Correlation Meter
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stereo Correlation")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    HStack {
                        Text("L")
                            .font(.caption2)
                        ProgressView(value: (Double(viewModel.stereoCorrelation) + 1.0) / 2.0)
                            .tint(viewModel.stereoCorrelation > 0 ? .green : .red)
                        Text("R")
                            .font(.caption2)
                    }

                    Text(String(format: "%.2f", viewModel.stereoCorrelation))
                        .font(.title3.monospacedDigit())
                        .foregroundColor(viewModel.stereoCorrelation > 0 ? .green : .orange)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)

                // M/S Metering
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mid/Side Levels")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        MiniMeter(label: "Mid", value: viewModel.midLevel, color: .blue)
                        MiniMeter(label: "Side", value: viewModel.sideLevel, color: .orange)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)

                // Goniometer placeholder
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goniometer")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)

                        // Placeholder Lissajous curve
                        Text("◇")
                            .font(.system(size: 60))
                            .foregroundColor(.green.opacity(0.5))
                    }
                    .frame(height: 150)
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)

                Spacer()
            }
            .padding(12)
        }
    }
}

// MARK: - Voice Analysis
struct VoiceAnalysisView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Voice Detection
                HStack {
                    Circle()
                        .fill(viewModel.voiceDetected ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)

                    Text(viewModel.voiceDetected ? "Voice Detected" : "No Voice")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)

                // Fundamental Frequency
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pitch")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    Text(String(format: "%.1f Hz", viewModel.fundamentalFrequency))
                        .font(.title2.monospacedDigit())
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)

                // Formants
                VStack(alignment: .leading, spacing: 8) {
                    Text("Formants")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    ForEach(0..<4) { index in
                        HStack {
                            Text("F\(index + 1)")
                                .font(.caption2.bold())
                                .foregroundColor(.secondary)
                                .frame(width: 30)

                            Text(String(format: "%.0f Hz", viewModel.formants[index]))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)

                // Vibrato
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vibrato")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    Text(String(format: "%.1f Hz", viewModel.vibratoRate))
                        .font(.title3.monospacedDigit())
                        .foregroundColor(.purple)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)

                Spacer()
            }
            .padding(12)
        }
    }
}

struct MiniMeter: View {
    let label: String
    let value: Float
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))

                    Rectangle()
                        .fill(color)
                        .frame(height: geometry.size.height * CGFloat(value))
                }
            }
            .frame(width: 40)
            .cornerRadius(4)

            Text(String(format: "%.0f%%", value * 100))
                .font(.caption2.monospacedDigit())
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    AnalysisPanelView(viewModel: AudioViewModel())
        .frame(width: 300, height: 600)
}
