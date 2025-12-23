//
//  AudioViewModel.swift
//  AudioPrime
//
//  Central ViewModel managing audio state and coordination
//  Bridges Swift UI layer with C++ audio processing core
//

import SwiftUI
import Combine

@MainActor
class AudioViewModel: ObservableObject {
    // MARK: - Published Properties

    // Audio capture state
    @Published var isCapturing = false

    // Performance metrics
    @Published var currentFPS: Int = 60
    @Published var latency: Double = 0.0  // milliseconds

    // Spectrum data (512 bars)
    @Published var spectrumData: [Float] = Array(repeating: 0.0, count: 512)

    // Loudness metering (ITU-R BS.1770-4)
    @Published var momentaryLoudness: Float = -23.0  // LUFS
    @Published var shortTermLoudness: Float = -23.0
    @Published var integratedLoudness: Float = -23.0
    @Published var truePeak: Float = 0.0  // dBTP

    // Beat detection
    @Published var currentBPM: Float = 0.0
    @Published var beatDetected = false

    // Stereo analysis
    @Published var stereoCorrelation: Float = 1.0  // -1 to +1
    @Published var stereoWidth: Float = 0.0
    @Published var leftLevel: Float = 0.0
    @Published var rightLevel: Float = 0.0
    @Published var midLevel: Float = 0.0
    @Published var sideLevel: Float = 0.0

    // Voice analysis
    @Published var voiceDetected = false
    @Published var fundamentalFrequency: Float = 0.0  // Hz
    @Published var formants: [Float] = [0, 0, 0, 0]  // F1, F2, F3, F4
    @Published var vibratoRate: Float = 0.0  // Hz

    // Spotify integration
    @Published var spotifyConnected = false
    @Published var currentTrack: SpotifyTrack?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private var audioCaptureService: AudioCaptureService?

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
        if isCapturing {
            await stopCapture()
        } else {
            await startCapture()
        }
    }

    func startCapture() async {
        print("Starting audio capture...")

        guard let service = audioCaptureService else {
            print("❌ Audio capture service not initialized")
            return
        }

        do {
            try await service.startCapture()
            isCapturing = service.isCapturing
            print("✅ Audio capture started successfully")
        } catch {
            print("❌ Failed to start audio capture: \(error)")
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
            return
        }

        let engine = service.getAudioEngine()

        // Update spectrum data
        spectrumData = engine.getSpectrum(size: 512)

        // Update metering data
        momentaryLoudness = engine.getLUFSMomentary()
        shortTermLoudness = engine.getLUFSShortTerm()
        integratedLoudness = engine.getLUFSIntegrated()
        truePeak = engine.getTruePeak()
        currentBPM = engine.getBPM()

        // Update performance metrics
        latency = service.getLatency()

        // Calculate actual FPS (simplified)
        currentFPS = 60  // Will be more accurate after profiling
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
        currentFPS = Int.random(in: 58...60)
        latency = Double.random(in: 2.5...4.5)
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
