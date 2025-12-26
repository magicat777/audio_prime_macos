//
//  ControlsWindowView.swift
//  AudioPrime
//
//  Separate window for FFT and spectrum controls
//  Uses @State + bindings to completely isolate from 60fps updates
//

import SwiftUI

struct ControlsWindowView: View {
    // Use @State to store local copies - completely isolated from real-time updates
    @State private var fftSize: Int
    @State private var smoothing: Double
    @State private var useMultiResolutionFFT: Bool
    @State private var usePerceptualWeighting: Bool
    @State private var showStereoSpectrum: Bool
    @State private var bassFFTSize: Int
    @State private var inputGain: Float

    // Keep reference to viewModel for syncing changes
    private let viewModel: AudioViewModel

    init(viewModel: AudioViewModel) {
        self.viewModel = viewModel
        // Initialize @State with current values
        _fftSize = State(initialValue: viewModel.fftSize)
        _smoothing = State(initialValue: viewModel.smoothing)
        _useMultiResolutionFFT = State(initialValue: viewModel.useMultiResolutionFFT)
        _usePerceptualWeighting = State(initialValue: viewModel.usePerceptualWeighting)
        _showStereoSpectrum = State(initialValue: viewModel.showStereoSpectrum)
        _bassFFTSize = State(initialValue: viewModel.bassFFTSize)
        _inputGain = State(initialValue: viewModel.inputGain)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Spectrum FFT Controls
            GroupBox("Spectrum Analyzer") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("FFT Size:")
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: $fftSize) {
                            Text("512").tag(512)
                            Text("1024").tag(1024)
                            Text("2048").tag(2048)
                            Text("4096").tag(4096)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .onChange(of: fftSize) { newValue in
                            viewModel.fftSize = newValue
                        }
                    }

                    HStack {
                        Text("Smoothing:")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $smoothing, in: 0...1)
                            .onChange(of: smoothing) { newValue in
                                viewModel.smoothing = newValue
                            }
                        Text("\(Int(smoothing * 100))%")
                            .font(.body.monospacedDigit())
                            .frame(width: 45)
                    }

                    Divider()

                    HStack(spacing: 20) {
                        Toggle("Multi-Resolution FFT", isOn: $useMultiResolutionFFT)
                            .onChange(of: useMultiResolutionFFT) { newValue in
                                viewModel.useMultiResolutionFFT = newValue
                            }
                        Toggle("A-Weighting", isOn: $usePerceptualWeighting)
                            .onChange(of: usePerceptualWeighting) { newValue in
                                viewModel.usePerceptualWeighting = newValue
                            }
                    }

                    Divider()

                    // Stereo spectrum toggle
                    HStack {
                        Toggle("Stereo L/R Display", isOn: $showStereoSpectrum)
                            .onChange(of: showStereoSpectrum) { newValue in
                                viewModel.showStereoSpectrum = newValue
                            }
                        Spacer()
                        // Legend
                        if showStereoSpectrum {
                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Circle().fill(Color(red: 0.9, green: 0.3, blue: 0.6)).frame(width: 10, height: 10)
                                    Text("Left").font(.caption)
                                }
                                HStack(spacing: 4) {
                                    Circle().fill(Color(red: 0.3, green: 0.5, blue: 0.9)).frame(width: 10, height: 10)
                                    Text("Right").font(.caption)
                                }
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
            }

            // Bass FFT Controls
            GroupBox("Bass Detail (20-200Hz)") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("FFT Size:")
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: $bassFFTSize) {
                            Text("2048").tag(2048)
                            Text("4096").tag(4096)
                            Text("8192").tag(8192)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .onChange(of: bassFFTSize) { newValue in
                            viewModel.bassFFTSize = newValue
                        }

                        Text("(\(String(format: "%.1f", 48000.0 / Double(bassFFTSize))) Hz/bin)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
            }

            // Input Gain
            GroupBox("Input") {
                HStack {
                    Text("Gain:")
                        .frame(width: 80, alignment: .leading)
                    Slider(value: Binding(
                        get: { Double(inputGain) },
                        set: { inputGain = Float($0) }
                    ), in: -24...12, step: 1)
                        .onChange(of: inputGain) { newValue in
                            viewModel.inputGain = newValue
                        }
                    Text(String(format: "%+.0f dB", inputGain))
                        .font(.body.monospacedDigit())
                        .frame(width: 55)
                        .foregroundColor(inputGain > 6 ? .orange : .primary)
                }
                .padding(8)
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    ControlsWindowView(viewModel: AudioViewModel())
}
