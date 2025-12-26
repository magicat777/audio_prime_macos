//
//  MainWindowView.swift
//  AudioPrime
//
//  Main window with resizable panel layout following Apple HIG
//  Uses NSSplitView for native macOS panel behavior
//

import SwiftUI
import AppKit

struct MainWindowView: View {
    @ObservedObject var viewModel: AudioViewModel
    @State private var showSpotifyPanel = true

    // Convenience init for previews
    init(viewModel: AudioViewModel? = nil) {
        self.viewModel = viewModel ?? AudioViewModel()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            ToolbarView(viewModel: viewModel, showSpotifyPanel: $showSpotifyPanel, showDebug: .constant(true))
                .frame(height: 44)

            HStack(spacing: 0) {
                // Main content area
                VStack(spacing: 0) {
                    // Main content with resizable panels
                    MainSplitView(viewModel: viewModel, showSpotifyPanel: $showSpotifyPanel)

                    // Bottom info bar (BPM + status) - conditional
                    if viewModel.widgetConfig.showBottomBar {
                        BottomInfoBar(viewModel: viewModel)
                            .frame(height: 44)
                    }
                }

                // Full-height debug panel on right - conditional
                if viewModel.widgetConfig.showDebug {
                    Divider()
                    DebugPanelView(viewModel: viewModel)
                        .frame(width: 220)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Full Height Debug Panel
struct DebugPanelView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "ladybug.fill")
                    .foregroundColor(.orange)
                Text("Debug Values")
                    .font(.caption.bold())
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    DebugSection(title: "LUFS Metering") {
                        DebugRow(label: "Momentary", value: String(format: "%.2f LUFS", viewModel.momentaryLoudness))
                        DebugRow(label: "Short-term", value: String(format: "%.2f LUFS", viewModel.shortTermLoudness))
                        DebugRow(label: "Integrated", value: String(format: "%.2f LUFS", viewModel.integratedLoudness))
                        DebugRow(label: "True Peak", value: String(format: "%.2f dBTP", viewModel.truePeak))
                    }

                    DebugSection(title: "VU Meters (Linear)") {
                        DebugRow(label: "VU Left", value: String(format: "%.6f", viewModel.vuLeft))
                        DebugRow(label: "VU Right", value: String(format: "%.6f", viewModel.vuRight))
                        DebugRow(label: "Peak Left", value: String(format: "%.6f", viewModel.peakLeft))
                        DebugRow(label: "Peak Right", value: String(format: "%.6f", viewModel.peakRight))
                        DebugRow(label: "Peak Hold L", value: String(format: "%.6f", viewModel.peakHoldLeft))
                        DebugRow(label: "Peak Hold R", value: String(format: "%.6f", viewModel.peakHoldRight))
                    }

                    DebugSection(title: "VU Meters (dB)") {
                        DebugRow(label: "VU Left", value: String(format: "%.1f dB", vuToDB(viewModel.vuLeft)))
                        DebugRow(label: "VU Right", value: String(format: "%.1f dB", vuToDB(viewModel.vuRight)))
                        DebugRow(label: "Peak Hold L", value: String(format: "%.1f dB", vuToDB(viewModel.peakHoldLeft)))
                        DebugRow(label: "Peak Hold R", value: String(format: "%.1f dB", vuToDB(viewModel.peakHoldRight)))
                    }

                    DebugSection(title: "Stereo Analysis") {
                        DebugRow(label: "Correlation", value: String(format: "%.4f", viewModel.stereoCorrelation))
                        DebugRow(label: "Mid Level", value: String(format: "%.4f", viewModel.midLevel))
                        DebugRow(label: "Side Level", value: String(format: "%.4f", viewModel.sideLevel))
                        DebugRow(label: "M/S Ratio", value: viewModel.sideLevel > 0 ? String(format: "%.2f", viewModel.midLevel / viewModel.sideLevel) : "N/A")
                    }

                    DebugSection(title: "Tempo Detection") {
                        DebugRow(label: "BPM", value: String(format: "%.1f", viewModel.currentBPM))
                        DebugRow(label: "Beat Detected", value: viewModel.beatDetected ? "YES" : "no")
                    }

                    DebugSection(title: "Performance") {
                        DebugRow(label: "FPS", value: "\(viewModel.currentFPS)")
                        DebugRow(label: "Latency", value: String(format: "%.2f ms", viewModel.latency))
                        DebugRow(label: "Capturing", value: viewModel.isCapturing ? "ACTIVE" : "stopped")
                    }

                    DebugSection(title: "Spectrum") {
                        DebugRow(label: "FFT Size", value: "\(viewModel.fftSize)")
                        DebugRow(label: "Bins", value: "\(viewModel.spectrumData.count)")
                        let maxBin = viewModel.spectrumData.max() ?? 0
                        DebugRow(label: "Max Bin", value: String(format: "%.4f", maxBin))
                    }
                }
                .padding(8)
            }
        }
        .background(Color.black.opacity(0.4))
        .font(.system(size: 10, design: .monospaced))
    }

    private func vuToDB(_ level: Float) -> Float {
        level > 0 ? 20.0 * log10(level) : -96.0
    }
}

struct DebugSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.orange)
                .padding(.top, 6)
                .padding(.bottom, 2)

            content
        }
    }
}

struct DebugRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Bottom Info Bar
struct BottomInfoBar: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        HStack(spacing: 20) {
            // BPM Display
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.beatDetected ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .animation(.easeInOut(duration: 0.1), value: viewModel.beatDetected)

                Text(String(format: "%.0f BPM", viewModel.currentBPM))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
            }

            Divider().frame(height: 20)

            // Quick LUFS readout
            HStack(spacing: 12) {
                Text("LUFS:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "M:%.1f", viewModel.momentaryLoudness))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(lufsColor(viewModel.momentaryLoudness))
                Text(String(format: "I:%.1f", viewModel.integratedLoudness))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(lufsColor(viewModel.integratedLoudness))
            }

            Divider().frame(height: 20)

            // True Peak
            HStack(spacing: 4) {
                Text("TP:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f dBTP", viewModel.truePeak))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(viewModel.truePeak > -1 ? .red : .green)
            }

            Divider().frame(height: 20)

            // Peak Hold mode button (cycles through Off → Fast → Medium → Slow)
            Button(action: {
                viewModel.cyclePeakHoldMode()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.peakHoldMode.icon)
                        .font(.caption)
                    Text("Peak: \(viewModel.peakHoldMode.rawValue)")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .tint(viewModel.peakHoldMode.color)
            .help("Cycle peak hold mode: Off → Fast → Medium → Slow")

            Spacer()

            // Capture status
            if viewModel.isCapturing {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("RECORDING")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 16)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func lufsColor(_ value: Float) -> Color {
        if value > -9 { return .red }
        if value > -14 { return .orange }
        if value > -18 { return .yellow }
        return .green
    }
}

// MARK: - Main Split View Container
struct MainSplitView: View {
    @ObservedObject var viewModel: AudioViewModel
    @Binding var showSpotifyPanel: Bool

    // Show left panel if any of its sub-widgets are enabled
    private var showLeftPanel: Bool {
        viewModel.widgetConfig.showSpectrum ||
        viewModel.widgetConfig.showBassDetail ||
        viewModel.widgetConfig.showVerticalMeters
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left Panel: Spectrum + Bass Detail + Meters
                if showLeftPanel {
                    SpectrumPanelView(viewModel: viewModel)
                        .frame(minWidth: 300)

                    Divider()
                }

                // Center Panel: 3D Visualization
                if viewModel.widgetConfig.showVisualization {
                    VisualizationPanelView(viewModel: viewModel)
                        .frame(minWidth: 300)

                    if viewModel.widgetConfig.showAnalysis {
                        Divider()
                    }
                }

                // Right Panel: Analysis Tools
                if viewModel.widgetConfig.showAnalysis {
                    AnalysisPanelView(viewModel: viewModel)
                        .frame(minWidth: 200, maxWidth: 280)
                }
            }
        }
    }
}

// MARK: - Toolbar
struct ToolbarView: View {
    @ObservedObject var viewModel: AudioViewModel
    @Binding var showSpotifyPanel: Bool
    @Binding var showDebug: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 16) {
            // Audio capture controls
            Button(action: {
                print("🔘 BUTTON CLICKED!") // Simple test - no async needed
                Task {
                    print("🔘 Task started")
                    await viewModel.toggleCapture()
                    print("🔘 Task completed")
                }
            }) {
                Image(systemName: viewModel.isCapturing ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.isCapturing ? .red : .green)
            }
            .buttonStyle(.plain)
            .help(viewModel.isCapturing ? "Stop audio capture" : "Start audio capture")

            Divider()
                .frame(height: 20)

            // Status indicators
            HStack(spacing: 8) {
                StatusBadge(label: "FPS", value: "\(viewModel.currentFPS)", color: viewModel.currentFPS >= 58 ? .green : .orange)
                StatusBadge(label: "Latency", value: String(format: "%.1fms", viewModel.latency), color: viewModel.latency < 10 ? .green : .orange)
            }

            Divider()
                .frame(height: 20)

            // Input gain control
            HStack(spacing: 4) {
                Image(systemName: viewModel.inputGain >= 0 ? "speaker.wave.2.fill" : "speaker.wave.1.fill")
                    .font(.caption)
                    .foregroundColor(viewModel.inputGain > 6 ? .orange : .secondary)

                Slider(value: Binding(
                    get: { Double(viewModel.inputGain) },
                    set: { viewModel.inputGain = Float($0) }
                ), in: -24...12, step: 1)
                .frame(width: 80)
                .help("Input gain: \(String(format: "%.0f", viewModel.inputGain)) dB")

                Text(String(format: "%+.0f", viewModel.inputGain))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(viewModel.inputGain > 6 ? .orange : (viewModel.inputGain < -12 ? .blue : .secondary))
                    .frame(width: 28)
            }
            .help("Adjust input signal level (-24 to +12 dB)")

            Divider()
                .frame(height: 20)

            // Widget preset picker
            Picker("Layout", selection: $viewModel.widgetPreset) {
                ForEach(WidgetPreset.allCases) { preset in
                    Label(preset.rawValue, systemImage: preset.icon)
                        .tag(preset)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            .help("Choose widget layout preset")

            Spacer()

            // Spotify status (if connected)
            if viewModel.spotifyConnected {
                SpotifyNowPlayingBadge(viewModel: viewModel)
            }

            // FFT Controls window button
            Button(action: {
                openWindow(id: "controls")
            }) {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .help("Open FFT Controls (⌘,)")

            // Debug toggle
            Toggle(isOn: Binding(
                get: { viewModel.widgetConfig.showDebug },
                set: { newValue in
                    viewModel.widgetConfig.showDebug = newValue
                    viewModel.widgetPreset = .custom
                }
            )) {
                Image(systemName: "ladybug.fill")
            }
            .toggleStyle(.button)
            .help("Toggle debug panel")

            // Panel visibility menu
            Menu {
                Section("Main Panels") {
                    Toggle("Spectrum Analyzer", isOn: Binding(
                        get: { viewModel.widgetConfig.showSpectrum },
                        set: { viewModel.widgetConfig.showSpectrum = $0; viewModel.widgetPreset = .custom }
                    ))
                    Toggle("3D Visualization", isOn: Binding(
                        get: { viewModel.widgetConfig.showVisualization },
                        set: { viewModel.widgetConfig.showVisualization = $0; viewModel.widgetPreset = .custom }
                    ))
                    Toggle("Analysis Panel", isOn: Binding(
                        get: { viewModel.widgetConfig.showAnalysis },
                        set: { viewModel.widgetConfig.showAnalysis = $0; viewModel.widgetPreset = .custom }
                    ))
                }

                Divider()

                Section("Spectrum Widgets") {
                    Toggle("Oscilloscope", isOn: Binding(
                        get: { viewModel.widgetConfig.showOscilloscope },
                        set: { viewModel.widgetConfig.showOscilloscope = $0; viewModel.widgetPreset = .custom }
                    ))
                    Toggle("Bass Detail", isOn: Binding(
                        get: { viewModel.widgetConfig.showBassDetail },
                        set: { viewModel.widgetConfig.showBassDetail = $0; viewModel.widgetPreset = .custom }
                    ))
                    Toggle("Vertical Meters", isOn: Binding(
                        get: { viewModel.widgetConfig.showVerticalMeters },
                        set: { viewModel.widgetConfig.showVerticalMeters = $0; viewModel.widgetPreset = .custom }
                    ))
                }

                Divider()

                Section("Stereo Analysis") {
                    Toggle("Goniometer", isOn: Binding(
                        get: { viewModel.widgetConfig.showGoniometer },
                        set: { viewModel.widgetConfig.showGoniometer = $0; viewModel.widgetPreset = .custom }
                    ))
                    Toggle("Correlation Meter", isOn: Binding(
                        get: { viewModel.widgetConfig.showCorrelation },
                        set: { viewModel.widgetConfig.showCorrelation = $0; viewModel.widgetPreset = .custom }
                    ))
                    Toggle("Mid/Side Display", isOn: Binding(
                        get: { viewModel.widgetConfig.showMidSide },
                        set: { viewModel.widgetConfig.showMidSide = $0; viewModel.widgetPreset = .custom }
                    ))
                }

                Divider()

                Section("Utility") {
                    Toggle("Debug Panel", isOn: Binding(
                        get: { viewModel.widgetConfig.showDebug },
                        set: { viewModel.widgetConfig.showDebug = $0; viewModel.widgetPreset = .custom }
                    ))
                    Toggle("Bottom Info Bar", isOn: Binding(
                        get: { viewModel.widgetConfig.showBottomBar },
                        set: { viewModel.widgetConfig.showBottomBar = $0; viewModel.widgetPreset = .custom }
                    ))
                }
            } label: {
                Image(systemName: "square.grid.3x3")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
            .help("Configure visible widgets")
        }
        .padding(.horizontal, 16)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Supporting Views
struct StatusBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}

struct SpotifyNowPlayingBadge: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note")
                .foregroundColor(.green)
            Text("Spotify Connected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    MainWindowView()
        .frame(width: 1400, height: 900)
}
