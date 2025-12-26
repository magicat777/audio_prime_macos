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
                Text("Tempo").tag(1)
                Text("Voice").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Tab content
            TabView(selection: $selectedTab) {
                StereoAnalysisView(viewModel: viewModel)
                    .tag(0)

                TempoAnalysisView(viewModel: viewModel)
                    .tag(1)

                VoiceAnalysisView(viewModel: viewModel)
                    .tag(2)
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
                // Frequency Bands Panel
                FrequencyBandsPanel(viewModel: viewModel)

                // Comprehensive Stereo Correlation Panel - conditional
                if viewModel.widgetConfig.showCorrelation || viewModel.widgetConfig.showMidSide {
                    StereoCorrelationPanel(viewModel: viewModel)
                }

                // Goniometer/Vectorscope/Polar display - conditional
                if viewModel.widgetConfig.showGoniometer {
                    VStack(alignment: .leading, spacing: 8) {
                        // Header with mode toggle button
                        HStack {
                            Text("Stereo Display")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Spacer()
                            // Mode toggle button
                            Button(action: {
                                viewModel.cycleGoniometerMode()
                            }) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(viewModel.goniometerDisplayMode.color)
                                        .frame(width: 6, height: 6)
                                    Text(viewModel.goniometerDisplayMode.label)
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }

                        GoniometerView(
                            goniometerX: viewModel.goniometerX,  // M/S data for goniometer
                            goniometerY: viewModel.goniometerY,
                            waveformL: viewModel.waveformLeft,   // Raw L/R for vectorscope/polar
                            waveformR: viewModel.waveformRight,
                            displayMode: viewModel.goniometerDisplayMode
                        )
                        .frame(minHeight: 200)
                        .frame(maxHeight: 300)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                }

                Spacer()
            }
            .padding(12)
        }
    }
}

// MARK: - Tempo Analysis
struct TempoAnalysisView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Main BPM Panel
                if viewModel.widgetConfig.showBPM {
                    BPMTempoPanel(viewModel: viewModel)
                }

                Spacer()
            }
            .padding(12)
        }
    }
}

// Custom magenta color for BPM display
private let bpmMagenta = Color(red: 1.0, green: 0.0, blue: 0.8)

// MARK: - BPM/Tempo Panel
struct BPMTempoPanel: View {
    @ObservedObject var viewModel: AudioViewModel

    // Tempo classification based on BPM
    private var tempoClass: (label: String, color: Color) {
        let bpm = viewModel.currentBPM
        if bpm <= 0 { return ("---", .gray) }
        if bpm < 60 { return ("LARGO", .blue) }
        if bpm < 80 { return ("ADAGIO", .cyan) }
        if bpm < 100 { return ("ANDANTE", .green) }
        if bpm < 120 { return ("MODERATO", .green) }
        if bpm < 140 { return ("ALLEGRO", .yellow) }
        if bpm < 180 { return ("VIVACE", .orange) }
        return ("PRESTO", .red)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("BPM / TEMPO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                // Tempo classification badge
                Text(tempoClass.label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(tempoClass.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tempoClass.color.opacity(0.2))
                    .cornerRadius(3)
            }

            // Main BPM Display with beat flash
            ZStack {
                // Beat flash background
                RoundedRectangle(cornerRadius: 12)
                    .fill(viewModel.beatDetected ?
                          bpmMagenta.opacity(0.3) :
                          Color.black.opacity(0.4))
                    .animation(.easeOut(duration: 0.1), value: viewModel.beatDetected)

                VStack(spacing: 4) {
                    // BPM Value
                    if viewModel.currentBPM > 0 {
                        Text(String(format: "%.1f", viewModel.currentBPM))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(bpmMagenta)
                    } else {
                        Text("---")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.gray.opacity(0.5))
                    }

                    Text("BPM")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
            }

            // Beat Phase Visualization (circular)
            BeatPhaseCircle(phase: viewModel.beatPhase, beatDetected: viewModel.beatDetected)
                .frame(height: 100)

            // Metrics Row: Confidence, Strength, Phase
            HStack(spacing: 12) {
                // Confidence meter
                MetricGauge(
                    label: "CONFIDENCE",
                    value: viewModel.beatConfidence,
                    color: confidenceColor(viewModel.beatConfidence),
                    format: "%.0f%%",
                    multiplier: 100
                )

                // Beat strength meter
                MetricGauge(
                    label: "STRENGTH",
                    value: viewModel.beatStrength,
                    color: .orange,
                    format: "%.0f%%",
                    multiplier: 100
                )

                // Beat phase
                VStack(spacing: 2) {
                    Text("PHASE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)

                    Text(String(format: "%.2f", viewModel.beatPhase))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                .frame(maxWidth: .infinity)
            }

            // Reset button for new track
            Button(action: {
                viewModel.resetBeatDetector()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .medium))
                    Text("Reset for New Track")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(12)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
    }

    private func confidenceColor(_ value: Float) -> Color {
        if value > 0.7 { return .green }
        if value > 0.4 { return .yellow }
        return .orange
    }
}

// MARK: - Beat Phase Circle
struct BeatPhaseCircle: View {
    let phase: Float
    let beatDetected: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size / 2 - 10

            Canvas { context, _ in
                // Draw background circle
                let bgPath = Path(ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                context.stroke(bgPath, with: .color(.gray.opacity(0.3)), lineWidth: 2)

                // Draw tick marks (quarters)
                for i in 0..<4 {
                    let angle = CGFloat(i) * .pi / 2 - .pi / 2
                    let innerR = radius - 8
                    let outerR = radius
                    var tickPath = Path()
                    tickPath.move(to: CGPoint(
                        x: center.x + cos(angle) * innerR,
                        y: center.y + sin(angle) * innerR
                    ))
                    tickPath.addLine(to: CGPoint(
                        x: center.x + cos(angle) * outerR,
                        y: center.y + sin(angle) * outerR
                    ))
                    context.stroke(tickPath, with: .color(.gray.opacity(0.5)), lineWidth: i == 0 ? 3 : 1)
                }

                // Draw phase arc (filled portion)
                let phaseAngle = CGFloat(phase) * 2 * .pi - .pi / 2
                var arcPath = Path()
                arcPath.addArc(
                    center: center,
                    radius: radius - 4,
                    startAngle: .radians(-.pi / 2),
                    endAngle: .radians(Double(phaseAngle)),
                    clockwise: false
                )
                context.stroke(arcPath, with: .color(Color(red: 1.0, green: 0.0, blue: 0.8).opacity(0.6)), lineWidth: 6)

                // Draw phase indicator dot
                let dotX = center.x + cos(phaseAngle) * (radius - 4)
                let dotY = center.y + sin(phaseAngle) * (radius - 4)
                let dotSize: CGFloat = beatDetected ? 14 : 10
                let dotPath = Path(ellipseIn: CGRect(
                    x: dotX - dotSize / 2,
                    y: dotY - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                ))
                context.fill(dotPath, with: .color(Color(red: 1.0, green: 0.0, blue: 0.8)))

                // Draw center beat indicator
                if beatDetected {
                    let centerDot = Path(ellipseIn: CGRect(
                        x: center.x - 8,
                        y: center.y - 8,
                        width: 16,
                        height: 16
                    ))
                    context.fill(centerDot, with: .color(Color(red: 1.0, green: 0.0, blue: 0.8).opacity(0.8)))
                }

                // Draw "1" label at top
                context.draw(
                    Text("1").font(.system(size: 10, weight: .bold)).foregroundColor(.white),
                    at: CGPoint(x: center.x, y: center.y - radius + 20)
                )
            }
        }
    }
}

// MARK: - Metric Gauge (reusable)
struct MetricGauge: View {
    let label: String
    let value: Float
    let color: Color
    let format: String
    let multiplier: Float

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.7))
                        .frame(width: geometry.size.width * CGFloat(min(1, value)))
                }
            }
            .frame(height: 8)

            Text(String(format: format, value * multiplier))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
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

// MARK: - Comprehensive Stereo Correlation Panel
struct StereoCorrelationPanel: View {
    @ObservedObject var viewModel: AudioViewModel

    // Correlation status based on value
    private var correlationStatus: (label: String, color: Color) {
        let corr = viewModel.stereoCorrelation
        if corr > 0.95 { return ("MONO", .green) }
        if corr > 0.5 { return ("CORR", .green) }
        if corr > 0.0 { return ("WIDE", .yellow) }
        if corr > -0.5 { return ("DIFF", .orange) }
        return ("OUT", .red)
    }

    // Calculate stereo width (0-100%)
    private var stereoWidth: Float {
        // Width = Side / Mid ratio, clamped to 0-1
        let mid = max(viewModel.midLevel, 0.001)
        let side = viewModel.sideLevel
        return min(1.0, side / mid)
    }

    // Calculate balance (-1 = full left, 0 = center, +1 = full right)
    private var stereoBalance: Float {
        let left = max(viewModel.leftLevel, 0.001)
        let right = max(viewModel.rightLevel, 0.001)
        let total = left + right
        return (right - left) / total
    }

    // Color for correlation value
    private func correlationColor(_ value: Float) -> Color {
        if value > 0.5 { return .green }
        if value > 0.0 { return .yellow }
        if value > -0.5 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and status
            HStack {
                Text("STEREO CORRELATION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                // Status indicator
                Text(correlationStatus.label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(correlationStatus.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(correlationStatus.color.opacity(0.2))
                    .cornerRadius(3)
            }

            // Main Correlation Meter Bar
            VStack(spacing: 4) {
                // Scale labels
                HStack {
                    Text("-1")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("0")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("+1")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                // Correlation bar with position indicator
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height: CGFloat = 20
                    let centerX = width / 2
                    let position = CGFloat((viewModel.stereoCorrelation + 1) / 2) * width

                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: height)

                        // Center line
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 1, height: height)
                            .position(x: centerX, y: height / 2)

                        // Fill from center to position
                        let fillStart = min(centerX, position)
                        let fillWidth = abs(position - centerX)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(correlationColor(viewModel.stereoCorrelation).opacity(0.6))
                            .frame(width: fillWidth, height: height - 4)
                            .position(x: fillStart + fillWidth / 2, y: height / 2)

                        // Position indicator
                        RoundedRectangle(cornerRadius: 2)
                            .fill(correlationColor(viewModel.stereoCorrelation))
                            .frame(width: 4, height: height)
                            .position(x: position, y: height / 2)
                    }
                }
                .frame(height: 20)

                // Correlation value display
                Text(String(format: "%+.2f", viewModel.stereoCorrelation))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(correlationColor(viewModel.stereoCorrelation))
                    .frame(maxWidth: .infinity)
            }

            // Statistics Row: Width, Balance, Mid/Side
            HStack(spacing: 12) {
                // Width meter
                VStack(spacing: 2) {
                    Text("WIDTH")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.3))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearGradient(
                                    colors: [.green, .yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: geometry.size.width * CGFloat(stereoWidth))
                        }
                    }
                    .frame(height: 8)

                    Text(String(format: "%.0f%%", stereoWidth * 100))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                .frame(maxWidth: .infinity)

                // Balance indicator
                VStack(spacing: 2) {
                    Text("BALANCE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)

                    GeometryReader { geometry in
                        let width = geometry.size.width
                        let centerX = width / 2
                        let indicatorPos = centerX + CGFloat(stereoBalance) * (width / 2)

                        ZStack {
                            // Background
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.3))

                            // Center marker
                            Rectangle()
                                .fill(Color.white.opacity(0.4))
                                .frame(width: 1, height: 8)
                                .position(x: centerX, y: 4)

                            // Balance indicator
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.cyan)
                                .frame(width: 6, height: 8)
                                .position(x: indicatorPos, y: 4)
                        }
                    }
                    .frame(height: 8)

                    // Balance label
                    let balanceLabel = stereoBalance < -0.1 ? "L" : (stereoBalance > 0.1 ? "R" : "C")
                    Text(balanceLabel)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                .frame(maxWidth: .infinity)

                // Mid/Side Levels
                VStack(spacing: 2) {
                    Text("MID/SIDE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        // Mid level
                        VStack(spacing: 0) {
                            Text("M")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.blue)
                            Text(formatDB(viewModel.midLevel))
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.blue)
                        }

                        // Side level
                        VStack(spacing: 0) {
                            Text("S")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.orange)
                            Text(formatDB(viewModel.sideLevel))
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
    }

    private func formatDB(_ level: Float) -> String {
        if level < 0.001 { return "---" }
        let db = 20 * log10(level)
        return String(format: "%.1f", db)
    }
}

// MARK: - Frequency Bands Panel
struct FrequencyBandsPanel: View {
    @ObservedObject var viewModel: AudioViewModel
    @State private var displayMode: FrequencyBandsDisplayMode = .horizontal
    @StateObject private var peakHoldState = FrequencyBandsPeakHoldState()

    // Spectrum configuration
    private let totalBars = 512
    private let spectrumMinFreq: Float = 20
    private let spectrumMaxFreq: Float = 20000

    enum FrequencyBandsDisplayMode {
        case horizontal
        case vertical

        var label: String {
            switch self {
            case .horizontal: return "HORIZ"
            case .vertical: return "VERT"
            }
        }
    }

    // Band definitions for horizontal mode (7 bands)
    private let horizontalBands: [(name: String, label: String, min: Float, max: Float)] = [
        ("Sub-Bass", "20", 20, 60),
        ("Bass", "60", 60, 250),
        ("Low-Mid", "250", 250, 500),
        ("Mid", "500", 500, 2000),
        ("Upper-Mid", "2k", 2000, 4000),
        ("Presence", "4k", 4000, 6000),
        ("Brilliance", "6k", 6000, 20000)
    ]

    // Band definitions for vertical mode (14 bands)
    private let verticalBands: [(name: String, label: String, min: Float, max: Float)] = [
        ("20-40", "20", 20, 40),
        ("40-63", "40", 40, 63),
        ("63-125", "63", 63, 125),
        ("125-250", "125", 125, 250),
        ("250-500", "250", 250, 500),
        ("500-1k", "500", 500, 1000),
        ("1k-2k", "1k", 1000, 2000),
        ("2k-3k", "2k", 2000, 3000),
        ("3k-4k", "3k", 3000, 4000),
        ("4k-5k", "4k", 4000, 5000),
        ("5k-6k", "5k", 5000, 6000),
        ("6k-10k", "6k", 6000, 10000),
        ("10k-16k", "10k", 10000, 16000),
        ("16k-20k", "16k", 16000, 20000)
    ]

    // Convert frequency to bar index (logarithmic mapping)
    private func freqToBar(_ freq: Float) -> Int {
        let t = log(freq / spectrumMinFreq) / log(spectrumMaxFreq / spectrumMinFreq)
        return max(0, min(totalBars - 1, Int(t * Float(totalBars - 1))))
    }

    // Convert bar index to frequency
    private func barToFreq(_ bar: Int) -> Float {
        let t = Float(bar) / Float(totalBars - 1)
        return spectrumMinFreq * pow(spectrumMaxFreq / spectrumMinFreq, t)
    }

    // Calculate band energy
    private func calculateBandEnergy(minFreq: Float, maxFreq: Float) -> Float {
        let startBar = freqToBar(minFreq)
        let endBar = min(freqToBar(maxFreq), viewModel.spectrumData.count - 1)

        guard endBar > startBar else { return 0 }

        var sum: Float = 0
        var count = 0

        for i in startBar...endBar {
            sum += viewModel.spectrumData[i]
            count += 1
        }

        return count > 0 ? (sum / Float(count)) * 100 : 0
    }

    // Find dominant frequency
    private var dominantFrequency: Float {
        var maxVal: Float = 0
        var maxBar = 0

        // Use stride of 4 for performance
        for i in stride(from: 1, to: viewModel.spectrumData.count, by: 4) {
            if viewModel.spectrumData[i] > maxVal {
                maxVal = viewModel.spectrumData[i]
                maxBar = i
            }
        }

        return barToFreq(maxBar)
    }

    // Check if signal is present
    private var signalPresent: Bool {
        let data = viewModel.spectrumData
        guard data.count > 300 else { return false }
        return data[50] > 0.05 || data[150] > 0.05 || data[300] > 0.05
    }

    // Get current band energies
    private var currentBandEnergies: [Float] {
        let bands = displayMode == .horizontal ? horizontalBands : verticalBands
        return bands.map { calculateBandEnergy(minFreq: $0.min, maxFreq: $0.max) }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header with dominant frequency and mode toggle
            HStack {
                Text(signalPresent ? String(format: "%.0f Hz", dominantFrequency) : "--- Hz")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan)

                Spacer()

                Button(action: {
                    displayMode = displayMode == .horizontal ? .vertical : .horizontal
                    // Reset peak holds on mode change
                    peakHoldState.reset(count: displayMode == .horizontal ? 7 : 14)
                }) {
                    HStack(spacing: 4) {
                        Text(displayMode.label)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Circle()
                            .fill(displayMode == .horizontal ? .purple : .green)
                            .frame(width: 6, height: 6)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }

            // Band meters
            if displayMode == .horizontal {
                horizontalBandsView
            } else {
                verticalBandsView
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
        .onChange(of: viewModel.spectrumData) { _ in
            peakHoldState.update(energies: currentBandEnergies)
        }
    }

    // Horizontal mode view (7 bands)
    private var horizontalBandsView: some View {
        VStack(spacing: 4) {
            ForEach(Array(horizontalBands.enumerated()), id: \.offset) { index, band in
                let energy = calculateBandEnergy(minFreq: band.min, maxFreq: band.max)
                let peakHold = peakHoldState.peakHolds.indices.contains(index) ? peakHoldState.peakHolds[index] : energy

                HStack(spacing: 6) {
                    Text(band.name)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.3))

                            // Energy bar with gradient
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearGradient(
                                    colors: [.green, .yellow, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: geometry.size.width * CGFloat(min(1, energy / 100)))

                            // Peak hold indicator
                            if peakHold > 0.5 {
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: 2, height: geometry.size.height)
                                    .offset(x: geometry.size.width * CGFloat(min(1, peakHold / 100)) - 1)
                                    .shadow(color: .white.opacity(0.6), radius: 2)
                            }
                        }
                    }
                    .frame(height: 10)

                    Text(String(format: "%.0f", peakHold))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
    }

    // Vertical mode view (14 bands)
    private var verticalBandsView: some View {
        HStack(spacing: 3) {
            ForEach(Array(verticalBands.enumerated()), id: \.offset) { index, band in
                let energy = calculateBandEnergy(minFreq: band.min, maxFreq: band.max)
                let peakHold = peakHoldState.peakHolds.indices.contains(index) ? peakHoldState.peakHolds[index] : energy

                VStack(spacing: 2) {
                    Text(String(format: "%.0f", peakHold))
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(height: 12)

                    GeometryReader { geometry in
                        ZStack(alignment: .bottom) {
                            // Background
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.3))

                            // Energy bar with vertical gradient
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearGradient(
                                    colors: [.green, .yellow, .red],
                                    startPoint: .bottom,
                                    endPoint: .top
                                ))
                                .frame(height: geometry.size.height * CGFloat(min(1, energy / 100)))

                            // Peak hold indicator
                            if peakHold > 0.5 {
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: geometry.size.width, height: 2)
                                    .offset(y: -geometry.size.height * CGFloat(min(1, peakHold / 100)) + 1)
                                    .shadow(color: .white.opacity(0.6), radius: 2)
                            }
                        }
                    }

                    Text(band.label)
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)
                        .frame(height: 12)
                }
            }
        }
        .frame(minHeight: 100)
    }
}

// MARK: - Peak Hold State Object
class FrequencyBandsPeakHoldState: ObservableObject {
    @Published var peakHolds: [Float] = Array(repeating: 0, count: 14)
    private var peakHoldTimes: [Date] = Array(repeating: Date.distantPast, count: 14)

    // Peak hold settings
    private let peakHoldDuration: TimeInterval = 1.5
    private let peakDecayRate: Float = 0.15

    func reset(count: Int) {
        peakHolds = Array(repeating: 0, count: count)
        peakHoldTimes = Array(repeating: Date.distantPast, count: count)
    }

    func update(energies: [Float]) {
        let now = Date()

        // Resize arrays if needed
        if peakHolds.count != energies.count {
            peakHolds = Array(repeating: 0, count: energies.count)
            peakHoldTimes = Array(repeating: Date.distantPast, count: energies.count)
        }

        for i in 0..<energies.count {
            let energy = energies[i]

            if energy > peakHolds[i] {
                peakHolds[i] = energy
                peakHoldTimes[i] = now
            } else if now.timeIntervalSince(peakHoldTimes[i]) > peakHoldDuration {
                peakHolds[i] = max(energy, peakHolds[i] * (1 - peakDecayRate))
            }
        }
    }
}

// MARK: - Stereo Meter (kept for compatibility)
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

// MARK: - Goniometer View (supports Goniometer, Vectorscope, and Polar modes)
struct GoniometerView: View {
    let goniometerX: [Float]  // M/S X data (Mid) for goniometer mode
    let goniometerY: [Float]  // M/S Y data (Side) for goniometer mode
    let waveformL: [Float]    // Raw Left channel for vectorscope/polar
    let waveformR: [Float]    // Raw Right channel for vectorscope/polar
    let displayMode: GoniometerDisplayMode

    var body: some View {
        Canvas { context, size in
            switch displayMode {
            case .goniometer:
                drawGoniometer(context: context, size: size)
            case .vectorscope:
                drawVectorscope(context: context, size: size)
            case .polar:
                drawPolar(context: context, size: size)
            }
        }
    }

    // MARK: - Goniometer (M/S Lissajous) - uses pre-computed M/S data
    private func drawGoniometer(context: GraphicsContext, size: CGSize) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let radius = min(size.width, size.height) / 2 - 15

        // Draw reference circle
        drawCircle(context: context, center: CGPoint(x: centerX, y: centerY), radius: radius)

        // Draw crosshairs (M/S axes)
        drawCrosshairs(context: context, center: CGPoint(x: centerX, y: centerY), radius: radius)

        // Draw diagonal lines (L and R axes at 45 degrees)
        let diag = radius * 0.707
        drawDiagonals(context: context, center: CGPoint(x: centerX, y: centerY), diag: diag)

        // Find max amplitude for auto-scaling
        var maxAmp: Float = 0.001
        for i in 0..<min(goniometerX.count, goniometerY.count) {
            let amp = sqrt(goniometerX[i] * goniometerX[i] + goniometerY[i] * goniometerY[i])
            maxAmp = max(maxAmp, amp)
        }
        let scaleFactor = radius * 0.85 / CGFloat(maxAmp)

        // Draw Lissajous curve
        guard goniometerX.count > 1 && goniometerY.count > 1 else { return }

        var path = Path()
        var hasStarted = false
        let pointStride = max(1, goniometerX.count / 256)

        for i in Swift.stride(from: 0, to: min(goniometerX.count, goniometerY.count), by: pointStride) {
            let x = centerX + CGFloat(goniometerX[i]) * scaleFactor
            let y = centerY - CGFloat(goniometerY[i]) * scaleFactor

            if !hasStarted {
                path.move(to: CGPoint(x: x, y: y))
                hasStarted = true
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(path, with: .color(.green.opacity(0.8)), lineWidth: 1.5)

        // Draw labels
        context.draw(Text("+M").font(.caption2).foregroundColor(.gray.opacity(0.6)),
                     at: CGPoint(x: centerX + radius + 10, y: centerY))
        context.draw(Text("+S").font(.caption2).foregroundColor(.gray.opacity(0.6)),
                     at: CGPoint(x: centerX, y: centerY - radius - 8))
        context.draw(Text("L").font(.caption2).foregroundColor(.gray.opacity(0.6)),
                     at: CGPoint(x: centerX - diag - 8, y: centerY - diag - 8))
        context.draw(Text("R").font(.caption2).foregroundColor(.gray.opacity(0.6)),
                     at: CGPoint(x: centerX + diag + 8, y: centerY - diag - 8))
    }

    // MARK: - Vectorscope (Direct L/R as X/Y) - uses raw waveform data
    private func drawVectorscope(context: GraphicsContext, size: CGSize) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let radius = min(size.width, size.height) / 2 - 15

        // Draw reference circle
        drawCircle(context: context, center: CGPoint(x: centerX, y: centerY), radius: radius)

        // Draw crosshairs
        drawCrosshairs(context: context, center: CGPoint(x: centerX, y: centerY), radius: radius)

        // Draw mono diagonal (45 degrees) - emphasized
        var monoPath = Path()
        monoPath.move(to: CGPoint(x: centerX - radius * 0.707, y: centerY + radius * 0.707))
        monoPath.addLine(to: CGPoint(x: centerX + radius * 0.707, y: centerY - radius * 0.707))
        context.stroke(monoPath, with: .color(.green.opacity(0.4)), lineWidth: 1)

        // Find max amplitude for auto-scaling using raw L/R data
        var maxAmp: Float = 0.001
        for i in 0..<min(waveformL.count, waveformR.count) {
            let amp = max(abs(waveformL[i]), abs(waveformR[i]))
            maxAmp = max(maxAmp, amp)
        }
        let scaleFactor = radius * 0.85 / CGFloat(maxAmp)

        // Draw vectorscope trace (R on X, L on Y) using raw L/R data
        guard waveformL.count > 1 && waveformR.count > 1 else { return }

        var path = Path()
        var hasStarted = false
        let pointStride = max(1, waveformL.count / 256)

        for i in Swift.stride(from: 0, to: min(waveformL.count, waveformR.count), by: pointStride) {
            // X = Right channel, Y = Left channel (inverted for screen)
            let x = centerX + CGFloat(waveformR[i]) * scaleFactor  // R on X
            let y = centerY - CGFloat(waveformL[i]) * scaleFactor  // L on Y (inverted)

            if !hasStarted {
                path.move(to: CGPoint(x: x, y: y))
                hasStarted = true
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(path, with: .color(.cyan.opacity(0.8)), lineWidth: 1.5)

        // Draw labels
        context.draw(Text("+R").font(.caption2).foregroundColor(.gray.opacity(0.6)),
                     at: CGPoint(x: centerX + radius + 10, y: centerY))
        context.draw(Text("-R").font(.caption2).foregroundColor(.gray.opacity(0.6)),
                     at: CGPoint(x: centerX - radius - 10, y: centerY))
        context.draw(Text("+L").font(.caption2).foregroundColor(.gray.opacity(0.6)),
                     at: CGPoint(x: centerX, y: centerY - radius - 8))
        context.draw(Text("-L").font(.caption2).foregroundColor(.gray.opacity(0.6)),
                     at: CGPoint(x: centerX, y: centerY + radius + 10))
    }

    // MARK: - Polar (Semi-circular pan/amplitude display) - uses raw waveform data
    private func drawPolar(context: GraphicsContext, size: CGSize) {
        let centerX = size.width / 2
        let centerY = size.height - 20  // Bottom center
        let radius = min(size.width / 2, size.height) - 30

        // Draw semi-circular grid
        for r in stride(from: radius * 0.25, through: radius, by: radius * 0.25) {
            var arcPath = Path()
            arcPath.addArc(center: CGPoint(x: centerX, y: centerY),
                          radius: r,
                          startAngle: .degrees(180),
                          endAngle: .degrees(0),
                          clockwise: false)
            context.stroke(arcPath, with: .color(.gray.opacity(0.2)), lineWidth: 0.5)
        }

        // Draw radial lines at key angles (-90, -45, 0, 45, 90 degrees)
        let angles: [CGFloat] = [-90, -45, 0, 45, 90]
        for angle in angles {
            let radians = (angle - 90) * .pi / 180  // Offset so 0 is up
            var linePath = Path()
            linePath.move(to: CGPoint(x: centerX, y: centerY))
            linePath.addLine(to: CGPoint(
                x: centerX + Darwin.cos(radians) * radius,
                y: centerY + Darwin.sin(radians) * radius
            ))
            let opacity = angle == 0 ? 0.4 : 0.2
            let color = angle == 0 ? Color.green : Color.gray
            context.stroke(linePath, with: .color(color.opacity(opacity)), lineWidth: angle == 0 ? 1 : 0.5)
        }

        // Find max amplitude for scaling using raw L/R data
        var maxAmp: Float = 0.001
        for i in 0..<min(waveformL.count, waveformR.count) {
            let amp = abs(waveformL[i]) + abs(waveformR[i])
            maxAmp = max(maxAmp, amp)
        }
        let scaleFactor = radius * 0.9 / CGFloat(maxAmp)

        // Draw polar trace using raw L/R data
        guard waveformL.count > 1 && waveformR.count > 1 else { return }

        var path = Path()
        var hasStarted = false
        let pointStride = max(1, waveformL.count / 256)

        for i in Swift.stride(from: 0, to: min(waveformL.count, waveformR.count), by: pointStride) {
            let left = waveformL[i]
            let right = waveformR[i]

            // Calculate pan angle: atan2(R-L, |L+R|) scaled to -90 to +90
            let sum = left + right
            let diff = right - left
            let panAngle = CGFloat(atan2(diff, abs(sum) + 0.001)) * 180 / .pi  // -90 to +90

            // Amplitude is the sum magnitude
            let amplitude = sqrt(left * left + right * right)

            // Convert to screen coordinates (0 degrees is up)
            let radians = (panAngle - 90) * .pi / 180
            let r = CGFloat(amplitude) * scaleFactor
            let x = centerX + Darwin.cos(radians) * r
            let y = centerY + Darwin.sin(radians) * r

            if !hasStarted {
                path.move(to: CGPoint(x: x, y: y))
                hasStarted = true
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(path, with: .color(.orange.opacity(0.8)), lineWidth: 1.5)

        // Draw labels
        context.draw(Text("L").font(.caption2).foregroundColor(.gray.opacity(0.6)),
                     at: CGPoint(x: centerX - radius - 8, y: centerY))
        context.draw(Text("C").font(.caption2).foregroundColor(.green.opacity(0.6)),
                     at: CGPoint(x: centerX, y: centerY - radius - 8))
        context.draw(Text("R").font(.caption2).foregroundColor(.gray.opacity(0.6)),
                     at: CGPoint(x: centerX + radius + 8, y: centerY))
    }

    // MARK: - Helper Drawing Functions
    private func drawCircle(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let circlePath = Path(ellipseIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        context.stroke(circlePath, with: .color(.gray.opacity(0.3)), lineWidth: 1)
    }

    private func drawCrosshairs(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        var crossPath = Path()
        crossPath.move(to: CGPoint(x: center.x - radius, y: center.y))
        crossPath.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        crossPath.move(to: CGPoint(x: center.x, y: center.y - radius))
        crossPath.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        context.stroke(crossPath, with: .color(.gray.opacity(0.3)), lineWidth: 1)
    }

    private func drawDiagonals(context: GraphicsContext, center: CGPoint, diag: CGFloat) {
        var diagPath = Path()
        diagPath.move(to: CGPoint(x: center.x - diag, y: center.y - diag))
        diagPath.addLine(to: CGPoint(x: center.x + diag, y: center.y + diag))
        diagPath.move(to: CGPoint(x: center.x + diag, y: center.y - diag))
        diagPath.addLine(to: CGPoint(x: center.x - diag, y: center.y + diag))
        context.stroke(diagPath, with: .color(.gray.opacity(0.2)), lineWidth: 1)
    }
}

#Preview {
    AnalysisPanelView(viewModel: AudioViewModel())
        .frame(width: 300, height: 600)
}
