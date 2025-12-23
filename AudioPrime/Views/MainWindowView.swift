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
    @StateObject private var viewModel = AudioViewModel()
    @State private var showSpotifyPanel = true

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            ToolbarView(viewModel: viewModel, showSpotifyPanel: $showSpotifyPanel)
                .frame(height: 44)

            // Main content with resizable panels
            MainSplitView(viewModel: viewModel, showSpotifyPanel: $showSpotifyPanel)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Main Split View Container
struct MainSplitView: NSViewRepresentable {
    @ObservedObject var viewModel: AudioViewModel
    @Binding var showSpotifyPanel: Bool

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.autoresizingMask = [.width, .height]

        // Left Panel: Spectrum Analyzer (25% width)
        let leftPanel = createPanel(SpectrumPanelView(viewModel: viewModel), minWidth: 300)

        // Center Panel: 3D Visualization + Meters (50% width)
        let centerPanel = createCenterPanel()

        // Right Panel: Analysis Tools (25% width)
        let rightPanel = createPanel(AnalysisPanelView(viewModel: viewModel), minWidth: 280)

        splitView.addArrangedSubview(leftPanel)
        splitView.addArrangedSubview(centerPanel)
        splitView.addArrangedSubview(rightPanel)

        // Configure initial proportions (following Apple HIG for pro apps)
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 0)   // Left can compress
        splitView.setHoldingPriority(.required, forSubviewAt: 1)     // Center gets priority
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 2)   // Right can compress

        return splitView
    }

    func updateNSView(_ nsView: NSSplitView, context: Context) {
        // Update panel visibility based on state
        // (Future: add/remove panels dynamically)
    }

    // MARK: - Helper Methods

    private func createPanel<Content: View>(_ content: Content, minWidth: CGFloat = 250) -> NSView {
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        // Set minimum width constraint
        NSLayoutConstraint.activate([
            hostingView.widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth)
        ])

        return hostingView
    }

    private func createCenterPanel() -> NSView {
        // Center panel has nested vertical split
        let centerSplit = NSSplitView()
        centerSplit.isVertical = false  // Vertical layout (top/bottom)
        centerSplit.dividerStyle = .thin

        // Top: 3D Visualization (70% height)
        let vizPanel = createPanel(VisualizationPanelView(viewModel: viewModel), minWidth: 400)

        // Bottom: Meters Grid (30% height)
        let metersPanel = createPanel(MetersPanelView(viewModel: viewModel), minWidth: 400)

        centerSplit.addArrangedSubview(vizPanel)
        centerSplit.addArrangedSubview(metersPanel)

        centerSplit.setHoldingPriority(.required, forSubviewAt: 0)  // Viz gets priority
        centerSplit.setHoldingPriority(.defaultLow, forSubviewAt: 1)

        return centerSplit
    }
}

// MARK: - Toolbar
struct ToolbarView: View {
    @ObservedObject var viewModel: AudioViewModel
    @Binding var showSpotifyPanel: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Audio capture controls
            Button(action: {
                Task { await viewModel.toggleCapture() }
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

            Spacer()

            // Spotify status (if connected)
            if viewModel.spotifyConnected {
                SpotifyNowPlayingBadge(viewModel: viewModel)
            }

            // Panel visibility toggles
            Menu {
                Toggle("Spotify Panel", isOn: $showSpotifyPanel)
            } label: {
                Image(systemName: "sidebar.right")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
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
