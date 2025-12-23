//
//  SpectrumPanelView.swift
//  AudioPrime
//
//  512-bar spectrum analyzer panel
//  Left panel in main layout
//

import SwiftUI

struct SpectrumPanelView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            PanelHeader(title: "Spectrum Analyzer", icon: "waveform")

            // Spectrum visualization with grid and scale
            GeometryReader { geometry in
                Canvas { context, size in
                    let leftMargin: CGFloat = 40  // Space for dB labels
                    let rightMargin: CGFloat = 8  // Small right margin
                    let bottomMargin: CGFloat = 22  // Space for frequency labels
                    let topMargin: CGFloat = 4  // Small top margin
                    let plotWidth = size.width - leftMargin - rightMargin
                    let plotHeight = size.height - bottomMargin - topMargin

                    // Draw grid first (behind spectrum)
                    drawGrid(context: context, size: size, leftMargin: leftMargin, rightMargin: rightMargin, topMargin: topMargin, bottomMargin: bottomMargin)

                    // Draw spectrum bars
                    let barWidth = plotWidth / CGFloat(viewModel.spectrumData.count)

                    for (index, value) in viewModel.spectrumData.enumerated() {
                        let x = leftMargin + CGFloat(index) * barWidth
                        let height = CGFloat(value) * plotHeight
                        let y = topMargin + plotHeight - height

                        let rect = CGRect(x: x, y: y, width: max(1, barWidth - 1), height: height)

                        // Color gradient based on frequency
                        let hue = Double(index) / Double(viewModel.spectrumData.count)
                        let color = Color(hue: hue * 0.6, saturation: 0.8, brightness: 0.9)

                        context.fill(Path(rect), with: .color(color))
                    }

                    // Draw labels
                    drawFrequencyLabels(context: context, size: size, leftMargin: leftMargin, rightMargin: rightMargin, bottomMargin: bottomMargin)
                    drawDBLabels(context: context, size: size, leftMargin: leftMargin, topMargin: topMargin, bottomMargin: bottomMargin)
                }
            }
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            .padding(12)

            // Bass detail panel
            BassDetailPanelView(viewModel: viewModel)
                .padding(.horizontal, 12)

            // Controls
            SpectrumControlsView(viewModel: viewModel)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func drawGrid(context: GraphicsContext, size: CGSize, leftMargin: CGFloat, rightMargin: CGFloat, topMargin: CGFloat, bottomMargin: CGFloat) {
        let plotWidth = size.width - leftMargin - rightMargin
        let plotHeight = size.height - bottomMargin - topMargin
        let gridColor = Color.white.opacity(0.15)
        let gridColorLight = Color.white.opacity(0.08)

        // Horizontal grid lines (dB levels: 0, -10, -20, -30, -40, -50, -60, -70, -80)
        // Major lines at 0, -20, -40, -60, -80; minor lines at -10, -30, -50, -70
        let dbLevels: [CGFloat] = [0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0]
        let majorLevels: Set<CGFloat> = [0, 0.25, 0.5, 0.75, 1.0]
        for level in dbLevels {
            let y = topMargin + plotHeight * (1.0 - level)
            var path = Path()
            path.move(to: CGPoint(x: leftMargin, y: y))
            path.addLine(to: CGPoint(x: size.width - rightMargin, y: y))
            let color = majorLevels.contains(level) ? gridColor : gridColorLight
            context.stroke(path, with: .color(color), lineWidth: 0.5)
        }

        // Vertical grid lines at frequency markers (doubled)
        // 20Hz, 50Hz, 100Hz, 200Hz, 500Hz, 1kHz, 2kHz, 5kHz, 10kHz, 20kHz
        let freqPositions: [CGFloat] = [0.0, 0.08, 0.15, 0.23, 0.35, 0.45, 0.55, 0.70, 0.85, 1.0]
        let majorFreqs: Set<CGFloat> = [0.0, 0.15, 0.45, 0.85, 1.0]  // 20Hz, 100Hz, 1kHz, 10kHz, 20kHz
        for pos in freqPositions {
            let x = leftMargin + plotWidth * pos
            var path = Path()
            path.move(to: CGPoint(x: x, y: topMargin))
            path.addLine(to: CGPoint(x: x, y: topMargin + plotHeight))
            let color = majorFreqs.contains(pos) ? gridColor : gridColorLight
            context.stroke(path, with: .color(color), lineWidth: 0.5)
        }
    }

    private func drawFrequencyLabels(context: GraphicsContext, size: CGSize, leftMargin: CGFloat, rightMargin: CGFloat, bottomMargin: CGFloat) {
        // Major labels: 20Hz, 100Hz, 1kHz, 10kHz, 20kHz
        // Minor labels: 50Hz, 200Hz, 500Hz, 2kHz, 5kHz
        let frequencies = ["20", "50", "100", "200", "500", "1k", "2k", "5k", "10k", "20k"]
        let positions: [CGFloat] = [0.0, 0.08, 0.15, 0.23, 0.35, 0.45, 0.55, 0.70, 0.85, 1.0]
        let plotWidth = size.width - leftMargin - rightMargin

        for (freq, pos) in zip(frequencies, positions) {
            let x = leftMargin + plotWidth * pos
            context.draw(
                Text(freq).font(.system(size: 8)).foregroundColor(.white.opacity(0.5)),
                at: CGPoint(x: x, y: size.height - 8)
            )
        }
    }

    private func drawDBLabels(context: GraphicsContext, size: CGSize, leftMargin: CGFloat, topMargin: CGFloat, bottomMargin: CGFloat) {
        let plotHeight = size.height - bottomMargin - topMargin
        // 0dB at top (pos=1.0), -80dB at bottom (pos=0)
        let dbLabels = ["0dB", "-20", "-40", "-60", "-80"]
        let positions: [CGFloat] = [1.0, 0.75, 0.5, 0.25, 0]  // Inverted: top to bottom

        for (label, pos) in zip(dbLabels, positions) {
            let y = topMargin + plotHeight * (1.0 - pos)
            context.draw(
                Text(label).font(.system(size: 8)).foregroundColor(.white.opacity(0.6)),
                at: CGPoint(x: 20, y: y)
            )
        }
    }
}

struct SpectrumControlsView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FFT Size:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $viewModel.fftSize) {
                    Text("512").tag(512)
                    Text("1024").tag(1024)
                    Text("2048").tag(2048)
                    Text("4096").tag(4096)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            HStack {
                Text("Smoothing:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $viewModel.smoothing, in: 0...1)
                Text("\(Int(viewModel.smoothing * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 40)
            }

            // New feature toggles
            HStack(spacing: 12) {
                Toggle("Multi-Res FFT", isOn: $viewModel.useMultiResolutionFFT)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                Toggle("A-Weighting", isOn: $viewModel.usePerceptualWeighting)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}

// MARK: - Bass Detail Panel

struct BassDetailPanelView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.orange)
                Text("Bass Detail (20-200Hz)")
                    .font(.caption.bold())
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            // Bass spectrum visualization with grid and scale
            GeometryReader { geometry in
                Canvas { context, size in
                    let leftMargin: CGFloat = 40  // Space for dB labels
                    let rightMargin: CGFloat = 8  // Small right margin
                    let bottomMargin: CGFloat = 18  // Space for frequency labels
                    let topMargin: CGFloat = 4  // Small top margin
                    let plotWidth = size.width - leftMargin - rightMargin
                    let plotHeight = size.height - bottomMargin - topMargin

                    // Draw grid first (behind spectrum)
                    drawBassGrid(context: context, size: size, leftMargin: leftMargin, rightMargin: rightMargin, topMargin: topMargin, bottomMargin: bottomMargin)

                    // Draw spectrum bars
                    let barWidth = plotWidth / CGFloat(viewModel.bassDetailData.count)

                    for (index, value) in viewModel.bassDetailData.enumerated() {
                        let x = leftMargin + CGFloat(index) * barWidth
                        let height = CGFloat(value) * plotHeight
                        let y = topMargin + plotHeight - height

                        let rect = CGRect(x: x, y: y, width: max(1, barWidth - 1), height: height)

                        // Orange/red gradient for bass
                        let hue = 0.05 + Double(index) / Double(viewModel.bassDetailData.count) * 0.1
                        let color = Color(hue: hue, saturation: 0.9, brightness: 0.9)

                        context.fill(Path(rect), with: .color(color))
                    }

                    // Draw labels
                    drawBassFrequencyLabels(context: context, size: size, leftMargin: leftMargin, rightMargin: rightMargin, bottomMargin: bottomMargin)
                    drawBassDBLabels(context: context, size: size, leftMargin: leftMargin, topMargin: topMargin, bottomMargin: bottomMargin)
                }
            }
            .frame(height: 160)
            .background(Color.black.opacity(0.8))
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func drawBassGrid(context: GraphicsContext, size: CGSize, leftMargin: CGFloat, rightMargin: CGFloat, topMargin: CGFloat, bottomMargin: CGFloat) {
        let plotWidth = size.width - leftMargin - rightMargin
        let plotHeight = size.height - bottomMargin - topMargin
        let gridColor = Color.white.opacity(0.15)
        let gridColorLight = Color.white.opacity(0.08)

        // Horizontal grid lines (dB levels: 0, -10, -20, -30, -40, -50, -60, -70, -80)
        let dbLevels: [CGFloat] = [0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0]
        let majorLevels: Set<CGFloat> = [0, 0.25, 0.5, 0.75, 1.0]
        for level in dbLevels {
            let y = topMargin + plotHeight * (1.0 - level)
            var path = Path()
            path.move(to: CGPoint(x: leftMargin, y: y))
            path.addLine(to: CGPoint(x: size.width - rightMargin, y: y))
            let color = majorLevels.contains(level) ? gridColor : gridColorLight
            context.stroke(path, with: .color(color), lineWidth: 0.5)
        }

        // Vertical grid lines at bass frequency markers (doubled)
        // 20Hz, 30Hz, 50Hz, 70Hz, 100Hz, 150Hz, 200Hz
        let freqPositions: [CGFloat] = [0.0, 0.18, 0.4, 0.55, 0.7, 0.88, 1.0]
        let majorFreqs: Set<CGFloat> = [0.0, 0.4, 0.7, 1.0]  // 20Hz, 50Hz, 100Hz, 200Hz
        for pos in freqPositions {
            let x = leftMargin + plotWidth * pos
            var path = Path()
            path.move(to: CGPoint(x: x, y: topMargin))
            path.addLine(to: CGPoint(x: x, y: topMargin + plotHeight))
            let color = majorFreqs.contains(pos) ? gridColor : gridColorLight
            context.stroke(path, with: .color(color), lineWidth: 0.5)
        }
    }

    private func drawBassFrequencyLabels(context: GraphicsContext, size: CGSize, leftMargin: CGFloat, rightMargin: CGFloat, bottomMargin: CGFloat) {
        // Labels for bass frequencies: 20Hz, 30Hz, 50Hz, 70Hz, 100Hz, 150Hz, 200Hz
        let frequencies = ["20", "30", "50", "70", "100", "150", "200"]
        let positions: [CGFloat] = [0.0, 0.18, 0.4, 0.55, 0.7, 0.88, 1.0]
        let plotWidth = size.width - leftMargin - rightMargin

        for (freq, pos) in zip(frequencies, positions) {
            let x = leftMargin + plotWidth * pos
            context.draw(
                Text(freq).font(.system(size: 8)).foregroundColor(.white.opacity(0.5)),
                at: CGPoint(x: x, y: size.height - 5)
            )
        }
    }

    private func drawBassDBLabels(context: GraphicsContext, size: CGSize, leftMargin: CGFloat, topMargin: CGFloat, bottomMargin: CGFloat) {
        let plotHeight = size.height - bottomMargin - topMargin
        // 0dB at top (pos=1.0), -80dB at bottom (pos=0)
        let dbLabels = ["0dB", "-20", "-40", "-60", "-80"]
        let positions: [CGFloat] = [1.0, 0.75, 0.5, 0.25, 0]  // Inverted: top to bottom

        for (label, pos) in zip(dbLabels, positions) {
            let y = topMargin + plotHeight * (1.0 - pos)
            context.draw(
                Text(label).font(.system(size: 8)).foregroundColor(.white.opacity(0.6)),
                at: CGPoint(x: 20, y: y)
            )
        }
    }
}

#Preview {
    SpectrumPanelView(viewModel: AudioViewModel())
        .frame(width: 400, height: 600)
}
