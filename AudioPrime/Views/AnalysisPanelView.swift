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

                    HStack(spacing: 20) {
                        StereoMeter(label: "Mid", value: viewModel.midLevel, color: .blue)
                        StereoMeter(label: "Side", value: viewModel.sideLevel, color: .orange)
                    }
                    .frame(height: 80)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)

                // Goniometer (Lissajous display)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goniometer")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    GoniometerView(xPoints: viewModel.goniometerX, yPoints: viewModel.goniometerY)
                        .frame(minHeight: 200)
                        .frame(maxHeight: 300)
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

// MARK: - Stereo Meter
struct StereoMeter: View {
    let label: String
    let value: Float
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    // Level bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(height: geometry.size.height * CGFloat(min(1.0, value * 3)))  // Scale up for visibility
                }
            }
            .frame(width: 30)

            Text(String(format: "%.0f%%", value * 100))
                .font(.caption2.monospacedDigit())
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Goniometer View
struct GoniometerView: View {
    let xPoints: [Float]
    let yPoints: [Float]

    var body: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let centerY = size.height / 2
            let radius = min(size.width, size.height) / 2 - 15  // Leave room for labels

            // Draw reference circle
            let circlePath = Path(ellipseIn: CGRect(
                x: centerX - radius,
                y: centerY - radius,
                width: radius * 2,
                height: radius * 2
            ))
            context.stroke(circlePath, with: .color(.gray.opacity(0.3)), lineWidth: 1)

            // Draw crosshairs (M/S axes)
            var crossPath = Path()
            crossPath.move(to: CGPoint(x: centerX - radius, y: centerY))
            crossPath.addLine(to: CGPoint(x: centerX + radius, y: centerY))
            crossPath.move(to: CGPoint(x: centerX, y: centerY - radius))
            crossPath.addLine(to: CGPoint(x: centerX, y: centerY + radius))
            context.stroke(crossPath, with: .color(.gray.opacity(0.3)), lineWidth: 1)

            // Draw diagonal lines (L and R axes at 45 degrees)
            var diagPath = Path()
            let diag = radius * 0.707
            diagPath.move(to: CGPoint(x: centerX - diag, y: centerY - diag))
            diagPath.addLine(to: CGPoint(x: centerX + diag, y: centerY + diag))
            diagPath.move(to: CGPoint(x: centerX + diag, y: centerY - diag))
            diagPath.addLine(to: CGPoint(x: centerX - diag, y: centerY + diag))
            context.stroke(diagPath, with: .color(.gray.opacity(0.2)), lineWidth: 1)

            // Find max amplitude for auto-scaling
            var maxAmp: Float = 0.001  // Minimum to avoid division by zero
            for i in 0..<min(xPoints.count, yPoints.count) {
                let amp = sqrt(xPoints[i] * xPoints[i] + yPoints[i] * yPoints[i])
                maxAmp = max(maxAmp, amp)
            }

            // Scale factor to fit within circle (with some headroom)
            let scaleFactor = radius * 0.85 / CGFloat(maxAmp)

            // Draw Lissajous curve
            guard xPoints.count > 1 && yPoints.count > 1 else { return }

            var lissajousPath = Path()
            var hasStarted = false

            // Use stride to reduce points for performance
            let pointStride = max(1, xPoints.count / 256)

            for i in Swift.stride(from: 0, to: min(xPoints.count, yPoints.count), by: pointStride) {
                // X is Mid (horizontal), Y is Side (vertical)
                let x = centerX + CGFloat(xPoints[i]) * scaleFactor
                let y = centerY - CGFloat(yPoints[i]) * scaleFactor  // Invert Y for screen coords

                if !hasStarted {
                    lissajousPath.move(to: CGPoint(x: x, y: y))
                    hasStarted = true
                } else {
                    lissajousPath.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(lissajousPath, with: .color(.green.opacity(0.8)), lineWidth: 1.5)

            // Draw axis labels
            context.draw(
                Text("+M").font(.caption2).foregroundColor(.gray.opacity(0.6)),
                at: CGPoint(x: centerX + radius + 12, y: centerY)
            )
            context.draw(
                Text("+S").font(.caption2).foregroundColor(.gray.opacity(0.6)),
                at: CGPoint(x: centerX, y: centerY - radius - 8)
            )
            context.draw(
                Text("L").font(.caption2).foregroundColor(.gray.opacity(0.6)),
                at: CGPoint(x: centerX - diag - 8, y: centerY - diag - 8)
            )
            context.draw(
                Text("R").font(.caption2).foregroundColor(.gray.opacity(0.6)),
                at: CGPoint(x: centerX + diag + 8, y: centerY - diag - 8)
            )
        }
    }
}

#Preview {
    AnalysisPanelView(viewModel: AudioViewModel())
        .frame(width: 300, height: 600)
}
