//
//  AudioViewModel.swift
//  AudioPrime
//
//  Central ViewModel managing audio state and coordination
//  Bridges Swift UI layer with C++ audio processing core
//

import SwiftUI
import Combine

// MARK: - Peak Hold Mode

enum PeakHoldMode: String, CaseIterable {
    case off = "Off"
    case fast = "Fast"
    case medium = "Medium"
    case slow = "Slow"

    /// Decay rate per frame at 60fps
    var decayRate: Float {
        switch self {
        case .off: return 0
        case .fast: return 0.008    // ~0.48/sec - drops quickly
        case .medium: return 0.003  // ~0.18/sec - moderate decay
        case .slow: return 0.001    // ~0.06/sec - very slow decay
        }
    }

    var icon: String {
        switch self {
        case .off: return "chart.line.uptrend.xyaxis"
        case .fast: return "hare.fill"
        case .medium: return "figure.walk"
        case .slow: return "tortoise.fill"
        }
    }

    var color: Color {
        switch self {
        case .off: return .gray
        case .fast: return .orange
        case .medium: return .cyan
        case .slow: return .green
        }
    }

    var next: PeakHoldMode {
        switch self {
        case .off: return .fast
        case .fast: return .medium
        case .medium: return .slow
        case .slow: return .off
        }
    }
}

@MainActor
class AudioViewModel: ObservableObject {
    // MARK: - Published Properties

    // Note: Real-time data uses nonisolated(unsafe) to avoid triggering
    // individual @Published updates. We manually call objectWillChange.send()
    // once per frame to batch all updates together.

    // Audio capture state
    @Published var isCapturing = false

    // Performance metrics (updated once per second, can stay @Published)
    @Published var currentFPS: Int = 60

    // Real-time data - use nonisolated(unsafe) to avoid per-property updates
    // These are updated every frame and batched with manual objectWillChange
    nonisolated(unsafe) var latency: Double = 0.0  // milliseconds

    // Spectrum data (512 bars)
    nonisolated(unsafe) var spectrumData: [Float] = Array(repeating: 0.0, count: 512)

    // Stereo spectrum data (L/R channels)
    @Published var showStereoSpectrum: Bool = false {
        didSet {
            if let service = audioCaptureService {
                service.getAudioEngine().setStereoSpectrum(showStereoSpectrum)
                print("🔧 Stereo Spectrum: \(showStereoSpectrum ? "ON" : "OFF")")
            }
        }
    }
    nonisolated(unsafe) var spectrumDataLeft: [Float] = Array(repeating: 0.0, count: 512)
    nonisolated(unsafe) var spectrumDataRight: [Float] = Array(repeating: 0.0, count: 512)

    // Peak hold for spectrum visualizer
    @Published var peakHoldMode: PeakHoldMode = .medium
    nonisolated(unsafe) var spectrumPeakHold: [Float] = Array(repeating: 0.0, count: 512)
    nonisolated(unsafe) var spectrumPeakHoldLeft: [Float] = Array(repeating: 0.0, count: 512)
    nonisolated(unsafe) var spectrumPeakHoldRight: [Float] = Array(repeating: 0.0, count: 512)
    nonisolated(unsafe) var bassPeakHold: [Float] = Array(repeating: 0.0, count: 64)

    var showPeakHold: Bool { peakHoldMode != .off }

    // Cycle through peak hold modes
    func cyclePeakHoldMode() {
        peakHoldMode = peakHoldMode.next
        // Reset peak hold when turning off or changing modes
        if peakHoldMode == .off {
            spectrumPeakHold = Array(repeating: 0.0, count: 512)
            spectrumPeakHoldLeft = Array(repeating: 0.0, count: 512)
            spectrumPeakHoldRight = Array(repeating: 0.0, count: 512)
            bassPeakHold = Array(repeating: 0.0, count: 64)
        }
    }

    // Input gain (dB) - adjusts incoming signal level
    @Published var inputGain: Float = 0.0 {  // -24 to +12 dB
        didSet {
            if let service = audioCaptureService {
                service.setInputGain(inputGain)
                print("🔧 Input gain changed to \(inputGain) dB")
            }
        }
    }

    // Spectrum settings
    @Published var fftSize: Int = 512 {
        didSet {
            if let service = audioCaptureService {
                service.getAudioEngine().setFFTSize(Int32(fftSize))
                print("🔧 FFT size changed to \(fftSize)")
            }
        }
    }
    @Published var smoothing: Double = 0.5 {
        didSet {
            if let service = audioCaptureService {
                service.getAudioEngine().setSmoothing(Float(smoothing))
                print("🔧 Smoothing changed to \(Int(smoothing * 100))%")
            }
        }
    }
    @Published var useMultiResolutionFFT: Bool = false {
        didSet {
            if let service = audioCaptureService {
                service.getAudioEngine().setMultiResolutionFFT(useMultiResolutionFFT)
                print("🔧 Multi-Resolution FFT: \(useMultiResolutionFFT ? "ON" : "OFF")")
            }
        }
    }
    @Published var usePerceptualWeighting: Bool = false {
        didSet {
            if let service = audioCaptureService {
                service.getAudioEngine().setPerceptualWeighting(usePerceptualWeighting)
                print("🔧 Perceptual Weighting: \(usePerceptualWeighting ? "ON" : "OFF")")
            }
        }
    }

    // Bass detail data (20-200Hz, 64 bars)
    nonisolated(unsafe) var bassDetailData: [Float] = Array(repeating: 0.0, count: 64)

    // Bass FFT settings (independent from main spectrum)
    @Published var bassFFTSize: Int = 4096 {  // 2048, 4096, 8192
        didSet {
            if let service = audioCaptureService {
                service.getAudioEngine().setBassFFTSize(Int32(bassFFTSize))
                print("🔧 Bass FFT size changed to \(bassFFTSize) (~\(String(format: "%.1f", 48000.0 / Double(bassFFTSize)))Hz resolution)")
            }
        }
    }

    // Loudness metering (ITU-R BS.1770-4) - real-time, batched updates
    nonisolated(unsafe) var momentaryLoudness: Float = -23.0  // LUFS
    nonisolated(unsafe) var shortTermLoudness: Float = -23.0
    nonisolated(unsafe) var integratedLoudness: Float = -23.0
    nonisolated(unsafe) var truePeak: Float = 0.0  // dBTP

    // Beat detection - real-time
    nonisolated(unsafe) var currentBPM: Float = 0.0
    nonisolated(unsafe) var beatDetected = false

    // Stereo analysis - real-time
    nonisolated(unsafe) var stereoCorrelation: Float = 1.0  // -1 to +1
    nonisolated(unsafe) var stereoWidth: Float = 0.0
    nonisolated(unsafe) var leftLevel: Float = 0.0
    nonisolated(unsafe) var rightLevel: Float = 0.0
    nonisolated(unsafe) var midLevel: Float = 0.0
    nonisolated(unsafe) var sideLevel: Float = 0.0
    nonisolated(unsafe) var goniometerX: [Float] = Array(repeating: 0.0, count: 512)
    nonisolated(unsafe) var goniometerY: [Float] = Array(repeating: 0.0, count: 512)

    // Oscilloscope waveform data (time-domain) - real-time
    nonisolated(unsafe) var waveformLeft: [Float] = Array(repeating: 0.0, count: 1024)
    nonisolated(unsafe) var waveformRight: [Float] = Array(repeating: 0.0, count: 1024)

    // VU metering - real-time
    nonisolated(unsafe) var vuLeft: Float = 0.0
    nonisolated(unsafe) var vuRight: Float = 0.0
    nonisolated(unsafe) var peakLeft: Float = -100.0
    nonisolated(unsafe) var peakRight: Float = -100.0
    nonisolated(unsafe) var peakHoldLeft: Float = -100.0
    nonisolated(unsafe) var peakHoldRight: Float = -100.0

    // Voice analysis - real-time
    nonisolated(unsafe) var voiceDetected = false
    nonisolated(unsafe) var fundamentalFrequency: Float = 0.0  // Hz
    nonisolated(unsafe) var formants: [Float] = [0, 0, 0, 0]  // F1, F2, F3, F4
    nonisolated(unsafe) var vibratoRate: Float = 0.0  // Hz

    // Spotify integration
    @Published var spotifyConnected = false
    @Published var currentTrack: SpotifyTrack?

    // MARK: - Widget Visibility Configuration
    @Published var widgetConfig = WidgetConfiguration()
    @Published var widgetPreset: WidgetPreset = .full {
        didSet {
            if widgetPreset != .custom {
                widgetConfig = widgetPreset.configuration
            }
        }
    }

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private var audioCaptureService: AudioCaptureService?
    private var debugSpectrumCount = 0

    // FPS tracking
    private var frameCount = 0
    private var lastFPSUpdate = Date()
    private let sampleRate: Double = 48000.0

    // MARK: - Initialization

    init() {
        // Initialize audio capture service
        audioCaptureService = AudioCaptureService()

        // Initialize with test data for UI development
        setupTestData()
        startUpdateTimer()
    }

    // MARK: - Public Methods

    func toggleCapture() async {
        print("🎵 toggleCapture called - isCapturing: \(isCapturing)")
        if isCapturing {
            await stopCapture()
        } else {
            await startCapture()
        }
    }

    func startCapture() async {
        print("🎬 Starting audio capture...")

        guard let service = audioCaptureService else {
            print("❌ Audio capture service not initialized")
            return
        }

        do {
            try await service.startCapture()
            isCapturing = service.isCapturing
            print("✅ Audio capture started successfully")
            print("   └─ service.isCapturing: \(service.isCapturing)")
            print("   └─ viewModel.isCapturing: \(isCapturing)")
        } catch {
            print("❌ Failed to start audio capture: \(error.localizedDescription)")
            print("   └─ Error: \(error)")
            isCapturing = false
        }
    }

    func stopCapture() async {
        print("Stopping audio capture...")

        guard let service = audioCaptureService else {
            return
        }

        await service.stopCapture()
        isCapturing = service.isCapturing
        print("✅ Audio capture stopped")
    }

    // MARK: - Private Methods

    private func startUpdateTimer() {
        // Update UI at 60 FPS
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateData()
            }
        }
    }

    private func updateData() {
        guard isCapturing else {
            // If not capturing, show test data
            updateTestData()
            return
        }

        // Get real data from C++ audio engine
        guard let service = audioCaptureService else {
            print("⚠️ No audioCaptureService in updateData")
            return
        }

        let engine = service.getAudioEngine()

        // Update spectrum data
        spectrumData = engine.getSpectrum(size: 512)

        // Update stereo spectrum data (if enabled)
        if showStereoSpectrum {
            spectrumDataLeft = engine.getSpectrumLeft(size: 512)
            spectrumDataRight = engine.getSpectrumRight(size: 512)
        }

        // Update bass detail data (20-200Hz range)
        bassDetailData = engine.getBassDetail(size: 64)

        // Update peak hold for spectrum (using mode-specific decay rate)
        if showPeakHold {
            let decay = peakHoldMode.decayRate

            if showStereoSpectrum {
                // Stereo mode: track L/R peak hold separately
                for i in 0..<min(spectrumDataLeft.count, spectrumPeakHoldLeft.count) {
                    if spectrumDataLeft[i] > spectrumPeakHoldLeft[i] {
                        spectrumPeakHoldLeft[i] = spectrumDataLeft[i]
                    } else {
                        spectrumPeakHoldLeft[i] = max(0, spectrumPeakHoldLeft[i] - decay)
                    }
                }
                for i in 0..<min(spectrumDataRight.count, spectrumPeakHoldRight.count) {
                    if spectrumDataRight[i] > spectrumPeakHoldRight[i] {
                        spectrumPeakHoldRight[i] = spectrumDataRight[i]
                    } else {
                        spectrumPeakHoldRight[i] = max(0, spectrumPeakHoldRight[i] - decay)
                    }
                }
            } else {
                // Mono mode: track single peak hold
                for i in 0..<min(spectrumData.count, spectrumPeakHold.count) {
                    if spectrumData[i] > spectrumPeakHold[i] {
                        spectrumPeakHold[i] = spectrumData[i]
                    } else {
                        spectrumPeakHold[i] = max(0, spectrumPeakHold[i] - decay)
                    }
                }
            }

            // Bass peak hold (always mono)
            for i in 0..<min(bassDetailData.count, bassPeakHold.count) {
                if bassDetailData[i] > bassPeakHold[i] {
                    bassPeakHold[i] = bassDetailData[i]
                } else {
                    bassPeakHold[i] = max(0, bassPeakHold[i] - decay)
                }
            }
        }

        // Debug: Print first few values
        if debugSpectrumCount < 3 {
            print("📊 Spectrum data: [\(spectrumData.prefix(10).map { String(format: "%.2f", $0) }.joined(separator: ", "))]")
            debugSpectrumCount += 1
        }

        // Update metering data
        momentaryLoudness = engine.getLUFSMomentary()
        shortTermLoudness = engine.getLUFSShortTerm()
        integratedLoudness = engine.getLUFSIntegrated()
        truePeak = engine.getTruePeak()
        currentBPM = engine.getBPM()

        // Update stereo analysis
        stereoCorrelation = engine.getStereoCorrelation()
        leftLevel = engine.getLeftLevel()
        rightLevel = engine.getRightLevel()
        midLevel = engine.getMidLevel()
        sideLevel = engine.getSideLevel()

        // Update goniometer data
        let goniometerData = engine.getGoniometerPoints(size: 512)
        goniometerX = goniometerData.x
        goniometerY = goniometerData.y

        // Update oscilloscope waveform data
        waveformLeft = engine.getWaveformLeft(size: 1024)
        waveformRight = engine.getWaveformRight(size: 1024)

        // Update VU meters
        vuLeft = engine.getVULeft()
        vuRight = engine.getVURight()
        peakLeft = engine.getPeakLeft()
        peakRight = engine.getPeakRight()
        peakHoldLeft = engine.getPeakHoldLeft()
        peakHoldRight = engine.getPeakHoldRight()

        // Update performance metrics
        // Latency is based on hop size (75% overlap = fftSize/4 new samples per frame)
        let hopSize = fftSize / 4
        latency = Double(hopSize) / sampleRate * 1000.0  // in milliseconds

        // Calculate actual FPS
        frameCount += 1
        let now = Date()
        let elapsed = now.timeIntervalSince(lastFPSUpdate)
        if elapsed >= 1.0 {
            currentFPS = Int(Double(frameCount) / elapsed)
            frameCount = 0
            lastFPSUpdate = now
        }

        // Trigger ONE SwiftUI update for all the real-time data changes
        // This replaces ~25 individual @Published updates with a single notification
        objectWillChange.send()
    }

    // MARK: - Test Data (for UI development)

    private func setupTestData() {
        // Initialize with realistic test values
        for i in 0..<512 {
            spectrumData[i] = Float.random(in: 0.0...0.3)
        }
    }

    private func updateTestData() {
        // Simulate spectrum animation
        for i in 0..<512 {
            let freq = Float(i) / 512.0
            let time = Date().timeIntervalSinceReferenceDate
            let value = sin(freq * 10 + Float(time)) * 0.3 + 0.3
            spectrumData[i] = max(0, min(1, value))
        }

        // Simulate beat detection
        if Int(Date().timeIntervalSinceReferenceDate * 2) % 2 == 0 {
            beatDetected = true
        } else {
            beatDetected = false
        }

        // Update metrics
        latency = Double.random(in: 2.5...4.5)

        // Trigger ONE SwiftUI update
        objectWillChange.send()
    }

    nonisolated deinit {
        // Note: Cannot invalidate timer from deinit due to MainActor isolation
        // Timer will be cleaned up when object is deallocated
    }
}

// MARK: - Spotify Track Model

struct SpotifyTrack: Identifiable {
    let id: String
    let name: String
    let artist: String
    let album: String
    let albumArtURL: URL?
    let duration: TimeInterval
    let progress: TimeInterval
}
