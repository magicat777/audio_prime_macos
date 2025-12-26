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
