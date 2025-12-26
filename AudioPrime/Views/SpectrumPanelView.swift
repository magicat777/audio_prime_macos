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

    // Check if left column has any content to show
    private var showLeftColumn: Bool {
        viewModel.widgetConfig.showSpectrum ||
        viewModel.widgetConfig.showOscilloscope ||
        viewModel.widgetConfig.showBassDetail
    }

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            PanelHeader(title: "Spectrum Analyzer", icon: "waveform")

            // Main content: Left column (spectrum + bass) and Right column (meters)
            HStack(spacing: 8) {
                // Left column: Spectrum + Controls + Bass Detail + Bass Controls stacked vertically
                if showLeftColumn {
                    VStack(spacing: 8) {
                        // Main spectrum display - conditional
                        if viewModel.widgetConfig.showSpectrum {
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

                                    if viewModel.showStereoSpectrum {
                                        // Stereo mode: Draw L/R with transparency overlay
                                        // Left channel (magenta/pink) - drawn first
                                        for (index, value) in viewModel.spectrumDataLeft.enumerated() {
                                            let x = leftMargin + CGFloat(index) * barWidth
                                            let height = CGFloat(value) * plotHeight
                                            let y = topMargin + plotHeight - height

                                            let rect = CGRect(x: x, y: y, width: max(1, barWidth - 1), height: height)
                                            // Magenta/pink for left channel
                                            let color = Color(red: 0.9, green: 0.3, blue: 0.6).opacity(0.7)
                                            context.fill(Path(rect), with: .color(color))
                                        }

                                        // Right channel (blue) - drawn on top with transparency
                                        for (index, value) in viewModel.spectrumDataRight.enumerated() {
                                            let x = leftMargin + CGFloat(index) * barWidth
                                            let height = CGFloat(value) * plotHeight
                                            let y = topMargin + plotHeight - height

                                            let rect = CGRect(x: x, y: y, width: max(1, barWidth - 1), height: height)
                                            // Blue for right channel
                                            let color = Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.7)
                                            context.fill(Path(rect), with: .color(color))
                                        }
                                    } else {
                                        // Mono mode: Normal rainbow gradient
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
                                    }

                                    // Draw peak hold line (if enabled)
                                    if viewModel.showPeakHold {
                                        if viewModel.showStereoSpectrum {
                                            // Stereo mode: Draw separate L/R peak hold lines
                                            // Left channel peak hold (magenta)
                                            var peakPathLeft = Path()
                                            var startedLeft = false
                                            for (index, peakValue) in viewModel.spectrumPeakHoldLeft.enumerated() {
                                                let x = leftMargin + CGFloat(index) * barWidth + barWidth / 2
                                                let peakHeight = CGFloat(peakValue) * plotHeight
                                                let y = topMargin + plotHeight - peakHeight
                                                if !startedLeft {
                                                    peakPathLeft.move(to: CGPoint(x: x, y: y))
                                                    startedLeft = true
                                                } else {
                                                    peakPathLeft.addLine(to: CGPoint(x: x, y: y))
                                                }
                                            }
                                            context.stroke(peakPathLeft, with: .color(Color(red: 1.0, green: 0.4, blue: 0.7).opacity(0.9)), lineWidth: 1.5)

                                            // Right channel peak hold (cyan/light blue)
                                            var peakPathRight = Path()
                                            var startedRight = false
                                            for (index, peakValue) in viewModel.spectrumPeakHoldRight.enumerated() {
                                                let x = leftMargin + CGFloat(index) * barWidth + barWidth / 2
                                                let peakHeight = CGFloat(peakValue) * plotHeight
                                                let y = topMargin + plotHeight - peakHeight
                                                if !startedRight {
                                                    peakPathRight.move(to: CGPoint(x: x, y: y))
                                                    startedRight = true
                                                } else {
                                                    peakPathRight.addLine(to: CGPoint(x: x, y: y))
                                                }
                                            }
                                            context.stroke(peakPathRight, with: .color(Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.9)), lineWidth: 1.5)
                                        } else {
                                            // Mono mode: single peak hold line
                                            var peakPath = Path()
                                            var started = false

                                            for (index, peakValue) in viewModel.spectrumPeakHold.enumerated() {
                                                let x = leftMargin + CGFloat(index) * barWidth + barWidth / 2
                                                let peakHeight = CGFloat(peakValue) * plotHeight
                                                let y = topMargin + plotHeight - peakHeight

                                                if !started {
                                                    peakPath.move(to: CGPoint(x: x, y: y))
                                                    started = true
                                                } else {
                                                    peakPath.addLine(to: CGPoint(x: x, y: y))
                                                }
                                            }

                                            context.stroke(peakPath, with: .color(viewModel.peakHoldMode.color.opacity(0.9)), lineWidth: 1.5)
                                        }
                                    }

                                    // Draw labels
                                    drawFrequencyLabels(context: context, size: size, leftMargin: leftMargin, rightMargin: rightMargin, bottomMargin: bottomMargin)
                                    drawDBLabels(context: context, size: size, leftMargin: leftMargin, topMargin: topMargin, bottomMargin: bottomMargin)
                                }
                            }
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(8)

                        }

                        // Oscilloscope panel - conditional (between spectrum and bass)
                        if viewModel.widgetConfig.showOscilloscope {
                            OscilloscopePanelView(viewModel: viewModel)
                                .frame(height: 120)
                        }

                        // Bass detail panel - conditional (same width as spectrum)
                        if viewModel.widgetConfig.showBassDetail {
                            BassDetailPanelView(viewModel: viewModel)
                                .frame(height: 140)
                        }
                    }
                }

                // Right column: Vertical meters panel (full height) - conditional, scalable
                if viewModel.widgetConfig.showVerticalMeters {
                    VerticalMetersPanel(viewModel: viewModel)
                        .frame(minWidth: 120, idealWidth: 160, maxWidth: 200)
                }
            }
            .padding(12)
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

// MARK: - Oscilloscope Panel

struct OscilloscopePanelView: View {
    @ObservedObject var viewModel: AudioViewModel

    // Auto-gain state (persisted across frames)
    @State private var currentGain: CGFloat = 1.0

    // Auto-gain parameters (matching AUDIO_PRIME reference)
    private let targetAmplitude: CGFloat = 0.7  // Target 70% of screen height
    private let minGain: CGFloat = 1.0
    private let maxGain: CGFloat = 50.0
    private let attackRate: CGFloat = 0.1   // Gain increase rate
    private let releaseRate: CGFloat = 0.02 // Gain decrease rate
    private let peakThreshold: CGFloat = 0.001

    var body: some View {
        VStack(spacing: 0) {
            // Panel header with ms/div display
            HStack {
                Image(systemName: "waveform.path")
                    .foregroundColor(Color(red: 0.29, green: 0.86, blue: 0.59))  // Cyan-green
                Text("Oscilloscope")
                    .font(.caption.bold())
                Spacer()
                // Time scale display (ms/div)
                let msPerDiv = (1000.0 / 48000.0) * Double(viewModel.waveformLeft.count) / 8.0
                Text(String(format: "%.2f ms/div", msPerDiv))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                // Gain indicator
                Text(String(format: "×%.1f", currentGain))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(currentGain > 10 ? .orange : .secondary)
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))

            // Oscilloscope waveform visualization
            GeometryReader { geometry in
                Canvas { context, size in
                    let leftMargin: CGFloat = 30
                    let rightMargin: CGFloat = 8
                    let topMargin: CGFloat = 4
                    let bottomMargin: CGFloat = 4
                    let plotWidth = size.width - leftMargin - rightMargin
                    let plotHeight = size.height - topMargin - bottomMargin
                    let centerY = topMargin + plotHeight / 2

                    // Draw background (darker)
                    let bgRect = CGRect(x: leftMargin, y: topMargin, width: plotWidth, height: plotHeight)
                    context.fill(Path(bgRect), with: .color(Color(red: 0.03, green: 0.04, blue: 0.06)))

                    // Draw grid
                    drawOscilloscopeGrid(context: context, size: size,
                                         leftMargin: leftMargin, rightMargin: rightMargin,
                                         topMargin: topMargin, bottomMargin: bottomMargin)

                    // Calculate mono waveform and auto-gain
                    let waveformSize = viewModel.waveformLeft.count
                    var monoWaveform = [CGFloat](repeating: 0, count: waveformSize)
                    var peakLevel: CGFloat = 0

                    for i in 0..<waveformSize {
                        let mono = (CGFloat(viewModel.waveformLeft[i]) + CGFloat(viewModel.waveformRight[i])) * 0.5
                        monoWaveform[i] = mono
                        peakLevel = max(peakLevel, abs(mono))
                    }

                    // Find trigger point (zero-crossing with positive slope)
                    var triggerPoint = 0
                    for i in 1..<(waveformSize / 4) {
                        if monoWaveform[i - 1] <= 0 && monoWaveform[i] > 0 {
                            triggerPoint = i
                            break
                        }
                    }

                    // Calculate display gain
                    var displayGain = currentGain
                    if peakLevel > peakThreshold {
                        let neededGain = targetAmplitude / peakLevel
                        let clampedGain = min(max(neededGain, minGain), maxGain)
                        if clampedGain > displayGain {
                            displayGain = displayGain + (clampedGain - displayGain) * attackRate
                        } else {
                            displayGain = displayGain + (clampedGain - displayGain) * releaseRate
                        }
                    }

                    // Draw waveform with glow effect
                    let displaySamples = max(2, min(waveformSize - triggerPoint, Int(plotWidth)))
                    let pointSpacing = plotWidth / CGFloat(max(1, displaySamples - 1))

                    // Create waveform path
                    var waveformPath = Path()
                    for i in 0..<displaySamples {
                        let sampleIdx = triggerPoint + i
                        guard sampleIdx < waveformSize else { break }

                        let x = leftMargin + CGFloat(i) * pointSpacing
                        let sample = monoWaveform[sampleIdx] * displayGain
                        let clampedSample = max(-1.0, min(1.0, sample))
                        let y = centerY - clampedSample * (plotHeight / 2) * 0.95

                        if i == 0 {
                            waveformPath.move(to: CGPoint(x: x, y: y))
                        } else {
                            waveformPath.addLine(to: CGPoint(x: x, y: y))
                        }
                    }

                    // Draw glow (wider, lower opacity stroke behind)
                    let glowColor = Color(red: 0.29, green: 0.86, blue: 0.59).opacity(0.3)
                    context.stroke(waveformPath, with: .color(glowColor), lineWidth: 4)

                    // Draw main waveform (cyan-green like AUDIO_PRIME)
                    let waveformColor = Color(red: 0.29, green: 0.86, blue: 0.59)
                    context.stroke(waveformPath, with: .color(waveformColor), lineWidth: 1.5)

                    // Draw amplitude labels
                    drawOscilloscopeLabels(context: context, size: size,
                                           leftMargin: leftMargin, topMargin: topMargin, bottomMargin: bottomMargin)

                    // Update gain state asynchronously
                    DispatchQueue.main.async {
                        self.currentGain = displayGain
                    }
                }
            }
            .background(Color.black.opacity(0.95))
            .cornerRadius(8)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func drawOscilloscopeGrid(context: GraphicsContext, size: CGSize,
                                       leftMargin: CGFloat, rightMargin: CGFloat,
                                       topMargin: CGFloat, bottomMargin: CGFloat) {
        let plotWidth = size.width - leftMargin - rightMargin
        let plotHeight = size.height - topMargin - bottomMargin
        let centerY = topMargin + plotHeight / 2
        let gridColor = Color.white.opacity(0.06)  // Faint grid like AUDIO_PRIME
        let centerLineColor = Color.white.opacity(0.15)

        // Center line (0 amplitude)
        var centerPath = Path()
        centerPath.move(to: CGPoint(x: leftMargin, y: centerY))
        centerPath.addLine(to: CGPoint(x: size.width - rightMargin, y: centerY))
        context.stroke(centerPath, with: .color(centerLineColor), lineWidth: 1)

        // Horizontal grid lines at ±0.5 amplitude
        let quarterHeight = plotHeight / 4
        for offset: CGFloat in [-2, -1, 1, 2] {
            var path = Path()
            let y = centerY + offset * quarterHeight
            path.move(to: CGPoint(x: leftMargin, y: y))
            path.addLine(to: CGPoint(x: size.width - rightMargin, y: y))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }

        // Vertical grid lines (8 time divisions)
        let numDivisions = 8
        for i in 0...numDivisions {
            let x = leftMargin + plotWidth * CGFloat(i) / CGFloat(numDivisions)
            var path = Path()
            path.move(to: CGPoint(x: x, y: topMargin))
            path.addLine(to: CGPoint(x: x, y: topMargin + plotHeight))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }
    }

    private func drawOscilloscopeLabels(context: GraphicsContext, size: CGSize,
                                         leftMargin: CGFloat, topMargin: CGFloat, bottomMargin: CGFloat) {
        let plotHeight = size.height - topMargin - bottomMargin
        let centerY = topMargin + plotHeight / 2

        // Amplitude labels
        let labels = [("+1", topMargin + 4), ("0", centerY), ("-1", topMargin + plotHeight - 4)]
        for (label, y) in labels {
            context.draw(
                Text(label).font(.system(size: 8)).foregroundColor(.white.opacity(0.5)),
                at: CGPoint(x: 14, y: y)
            )
        }
    }
}

// MARK: - Bass Detail Panel

struct BassDetailPanelView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Panel header (simple)
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.orange)
                Text("Bass Detail (20-200Hz)")
                    .font(.caption.bold())
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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

                    // Draw peak hold bars (if enabled) - individual bars instead of line for narrow display
                    if viewModel.showPeakHold {
                        for (index, peakValue) in viewModel.bassPeakHold.enumerated() {
                            let x = leftMargin + CGFloat(index) * barWidth
                            let peakHeight = CGFloat(peakValue) * plotHeight
                            let y = topMargin + plotHeight - peakHeight

                            // Draw horizontal bar at peak position
                            let peakBarRect = CGRect(
                                x: x,
                                y: y - 1,  // Center the 2px bar on the peak position
                                width: max(1, barWidth - 1),
                                height: 2
                            )
                            context.fill(Path(peakBarRect), with: .color(viewModel.peakHoldMode.color.opacity(0.9)))
                        }
                    }

                    // Draw labels
                    drawBassFrequencyLabels(context: context, size: size, leftMargin: leftMargin, rightMargin: rightMargin, bottomMargin: bottomMargin)
                    drawBassDBLabels(context: context, size: size, leftMargin: leftMargin, topMargin: topMargin, bottomMargin: bottomMargin)
                }
            }
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
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

// MARK: - Vertical Meters Panel (Full Height, Scalable)
struct VerticalMetersPanel: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        GeometryReader { geometry in
            // Calculate responsive dimensions based on available space
            let availableWidth = geometry.size.width - 16  // Padding
            let numBars = 6  // M, S, I, TP, L, R
            let numDividers = 2
            let dividerSpace: CGFloat = 12
            let sectionSpacing: CGFloat = 6
            let barSpacing: CGFloat = 2

            // Calculate bar width to fit all bars (half the previous width, minimum 16)
            let barWidth = max(16, (availableWidth - CGFloat(numDividers) * dividerSpace - sectionSpacing * 4) / CGFloat(numBars) - barSpacing)

            // Calculate meter height leaving room for labels and values
            let meterHeight = max(80, geometry.size.height - 50)

            HStack(alignment: .top, spacing: sectionSpacing) {
                // LUFS Meters (M, S, I)
                VStack(spacing: 1) {
                    Text("LUFS")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(height: 12)

                    HStack(spacing: barSpacing) {
                        UnifiedMeterBar(
                            label: "M",
                            value: viewModel.momentaryLoudness,
                            minDB: -60, maxDB: 0,
                            height: meterHeight,
                            width: barWidth,
                            thresholds: (-18, -14, -9),
                            targetLines: [(-14, 0.6), (-23, 0.3)]
                        )
                        UnifiedMeterBar(
                            label: "S",
                            value: viewModel.shortTermLoudness,
                            minDB: -60, maxDB: 0,
                            height: meterHeight,
                            width: barWidth,
                            thresholds: (-18, -14, -9),
                            targetLines: [(-14, 0.6), (-23, 0.3)]
                        )
                        UnifiedMeterBar(
                            label: "I",
                            value: viewModel.integratedLoudness,
                            minDB: -60, maxDB: 0,
                            height: meterHeight,
                            width: barWidth,
                            thresholds: (-18, -14, -9),
                            targetLines: [(-14, 0.6), (-23, 0.3)]
                        )
                    }
                }

                Divider()

                // True Peak
                VStack(spacing: 1) {
                    Text("TP")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(height: 12)

                    UnifiedMeterBar(
                        label: "",
                        value: viewModel.truePeak,
                        minDB: -60, maxDB: 3,
                        height: meterHeight,
                        width: barWidth,
                        thresholds: (-6, -3, -1),
                        targetLines: [(0, 0.8), (-1, 0.5)],
                        showClipIndicator: true,
                        unit: "dB"
                    )
                }

                Divider()

                // VU Meters (L/R)
                VStack(spacing: 1) {
                    Text("VU")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(height: 12)

                    HStack(spacing: barSpacing) {
                        UnifiedMeterBar(
                            label: "L",
                            value: vuToDB(viewModel.vuLeft),
                            minDB: -60, maxDB: 0,
                            height: meterHeight,
                            width: barWidth,
                            thresholds: (-12, -6, -3),
                            peakHoldValue: vuToDB(viewModel.peakHoldLeft)
                        )
                        UnifiedMeterBar(
                            label: "R",
                            value: vuToDB(viewModel.vuRight),
                            minDB: -60, maxDB: 0,
                            height: meterHeight,
                            width: barWidth,
                            thresholds: (-12, -6, -3),
                            peakHoldValue: vuToDB(viewModel.peakHoldRight)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.6))
        .cornerRadius(6)
    }

    private func vuToDB(_ level: Float) -> Float {
        level > 0 ? 20.0 * log10(level) : -60.0
    }
}

// MARK: - Unified Meter Bar (consistent dimensions for all meter types)
struct UnifiedMeterBar: View {
    let label: String
    let value: Float
    let minDB: Float
    let maxDB: Float
    let height: CGFloat
    let width: CGFloat
    let thresholds: (yellow: Float, orange: Float, red: Float)  // dB thresholds for color changes
    var targetLines: [(db: Float, opacity: Double)] = []
    var peakHoldValue: Float? = nil
    var showClipIndicator: Bool = false
    var unit: String? = nil

    private var range: Float { maxDB - minDB }

    private var percentage: CGFloat {
        let clamped = max(minDB, min(maxDB, value))
        return CGFloat((clamped - minDB) / range)
    }

    private var peakHoldPercentage: CGFloat? {
        guard let peak = peakHoldValue else { return nil }
        let clamped = max(minDB, min(maxDB, peak))
        return CGFloat((clamped - minDB) / range)
    }

    // Color based on current level (whole bar changes color)
    private var meterColor: Color {
        if value > thresholds.red { return .red }
        if value > thresholds.orange { return .orange }
        if value > thresholds.yellow { return .yellow }
        return .green
    }

    var body: some View {
        VStack(spacing: 1) {
            // The meter bar
            ZStack(alignment: .bottom) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.3))

                // Meter fill - solid color based on level
                Rectangle()
                    .fill(meterColor)
                    .frame(height: height * percentage)

                // Target/reference lines
                ForEach(targetLines.indices, id: \.self) { index in
                    let line = targetLines[index]
                    let linePos = CGFloat((line.db - minDB) / range)
                    Rectangle()
                        .fill(line.db >= 0 ? Color.red.opacity(line.opacity) : Color.white.opacity(line.opacity))
                        .frame(height: line.db >= 0 ? 2 : 1)
                        .offset(y: -height * linePos + 1)
                }

                // Peak hold indicator (if provided)
                if let peakPct = peakHoldPercentage {
                    Rectangle()
                        .fill(Color.white)
                        .frame(height: 2)
                        .offset(y: -height * peakPct + 1)
                }

                // Clip indicator (red bar at top when clipping)
                if showClipIndicator && value > 0 {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: width, height: 4)
                        .position(x: width / 2, y: 2)
                }
            }
            .frame(width: width, height: height)
            .cornerRadius(2)

            // Label (M, S, I, L, R, or empty for TP) - minimal font
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(height: 10)
            } else {
                // Empty spacer for TP to align with other meters
                Spacer().frame(height: 10)
            }

            // Value display - minimal font, integer for narrow bars
            Text(width < 24 ? String(format: "%.0f", value) : String(format: "%.1f", value))
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(meterColor)
                .frame(width: width, height: 10)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            // Optional unit label (for TP)
            if let unit = unit {
                Text(unit)
                    .font(.system(size: 6))
                    .foregroundColor(.secondary)
                    .frame(height: 8)
            }
        }
    }
}

#Preview {
    SpectrumPanelView(viewModel: AudioViewModel())
        .frame(width: 600, height: 700)
}
