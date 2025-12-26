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
                // Correlation Meter - conditional
                if viewModel.widgetConfig.showCorrelation {
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
                }

                // M/S Metering - conditional
                if viewModel.widgetConfig.showMidSide {
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
