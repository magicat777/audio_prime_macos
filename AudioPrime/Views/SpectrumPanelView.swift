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

            // Spectrum visualization
            GeometryReader { geometry in
                Canvas { context, size in
                    let barWidth = size.width / CGFloat(viewModel.spectrumData.count)
                    let maxHeight = size.height - 20

                    for (index, value) in viewModel.spectrumData.enumerated() {
                        let x = CGFloat(index) * barWidth
                        let height = CGFloat(value) * maxHeight
                        let y = size.height - height

                        let rect = CGRect(x: x, y: y, width: max(1, barWidth - 1), height: height)

                        // Color gradient based on frequency
                        let hue = Double(index) / Double(viewModel.spectrumData.count)
                        let color = Color(hue: hue * 0.6, saturation: 0.8, brightness: 0.9)

                        context.fill(Path(rect), with: .color(color))
                    }

                    // Draw frequency labels
                    drawFrequencyLabels(context: context, size: size)
                }
            }
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            .padding(12)

            // Controls
            SpectrumControlsView(viewModel: viewModel)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func drawFrequencyLabels(context: GraphicsContext, size: CGSize) {
        let frequencies = ["20Hz", "100Hz", "1kHz", "10kHz", "20kHz"]
        let positions = [0.0, 0.15, 0.45, 0.85, 1.0]

        for (freq, pos) in zip(frequencies, positions) {
            let x = size.width * pos
            context.draw(
                Text(freq).font(.caption).foregroundColor(.white.opacity(0.5)),
                at: CGPoint(x: x, y: size.height - 8)
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
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}

#Preview {
    SpectrumPanelView(viewModel: AudioViewModel())
        .frame(width: 400, height: 600)
}
