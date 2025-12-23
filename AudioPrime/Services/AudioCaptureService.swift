//
//  AudioCaptureService.swift
//  AudioPrime
//
//  ScreenCaptureKit-based audio capture service
//  Captures stereo system audio on macOS 13.0+
//

import Foundation
import ScreenCaptureKit
import AVFoundation
import Combine

@MainActor
class AudioCaptureService: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var isCapturing = false
    @Published var error: AudioCaptureError?
    @Published var permissionStatus: PermissionStatus = .unknown

    // MARK: - Private Properties

    private var stream: SCStream?
    nonisolated(unsafe) private let audioEngine: AudioEngineWrapper  // Thread-safe C++ wrapper
    private let audioQueue = DispatchQueue(label: "com.audioprime.audio", qos: .userInteractive)

    // Audio configuration
    private let sampleRate: Double = 48000.0
    private let channelCount: Int = 2  // Stereo
    private let bufferSize: Int = 512

    // Performance tracking (atomic access via DispatchQueue)
    private let metricsQueue = DispatchQueue(label: "com.audioprime.metrics")
    private var _frameCount: Int64 = 0
    private var _lastFrameTime: Date?
    private var _droppedFrames: Int = 0

    private var frameCount: Int64 {
        get { metricsQueue.sync { _frameCount } }
        set { metricsQueue.sync { _frameCount = newValue } }
    }

    private var droppedFrames: Int {
        get { metricsQueue.sync { _droppedFrames } }
        set { metricsQueue.sync { _droppedFrames = newValue } }
    }

    // MARK: - Initialization

    override init() {
        audioEngine = AudioEngineWrapper()
        super.init()
        audioEngine.setSampleRate(sampleRate)
        audioEngine.setFFTSize(Int32(bufferSize))
    }

    // MARK: - Public Methods

    /// Check if screen recording permission is granted
    func checkPermission() async -> Bool {
        permissionStatus = .checking

        // Get available content to trigger permission prompt if needed
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            permissionStatus = .authorized
            return true
        } catch {
            print("Screen recording permission denied: \(error)")
            permissionStatus = .denied
            self.error = .permissionDenied
            return false
        }
    }

    /// Start capturing system audio
    func startCapture() async throws {
        guard !isCapturing else { return }

        print("Starting audio capture...")

        // Check permission first
        let hasPermission = await checkPermission()
        guard hasPermission else {
            throw AudioCaptureError.permissionDenied
        }

        // Get available content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw AudioCaptureError.noDisplayAvailable
        }

        // Create content filter (capture entire display)
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Configure stream
        let config = SCStreamConfiguration()

        // Audio settings - THIS IS THE KEY: STEREO CAPTURE!
        config.capturesAudio = true
        config.sampleRate = Int(sampleRate)
        config.channelCount = channelCount
        config.excludesCurrentProcessAudio = false  // Capture everything

        // Disable video capture (we only want audio)
        config.width = 1
        config.height = 1
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 3

        // Create stream
        stream = SCStream(filter: filter, configuration: config, delegate: self)

        guard let stream = stream else {
            throw AudioCaptureError.streamCreationFailed
        }

        // Add audio output handler
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)

        // Start capture
        try await stream.startCapture()

        isCapturing = true
        metricsQueue.sync {
            _frameCount = 0
            _lastFrameTime = Date()
            _droppedFrames = 0
        }

        print("✅ Audio capture started - \(sampleRate)Hz, \(channelCount) channels")
    }

    /// Stop capturing audio
    func stopCapture() async {
        guard isCapturing else { return }

        print("Stopping audio capture...")

        do {
            try await stream?.stopCapture()
        } catch {
            print("Error stopping capture: \(error)")
        }

        stream = nil
        isCapturing = false

        print("✅ Audio capture stopped - Processed \(frameCount) frames, dropped \(droppedFrames)")
    }

    /// Get current audio engine for data retrieval
    func getAudioEngine() -> AudioEngineWrapper {
        return audioEngine
    }

    // MARK: - Performance Metrics

    func getLatency() -> Double {
        // Calculate approximate latency based on buffer size
        return Double(bufferSize) / sampleRate * 1000.0  // in milliseconds
    }

    func getDroppedFrameCount() -> Int {
        return droppedFrames
    }
}

// MARK: - SCStreamDelegate

extension AudioCaptureService: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("❌ Stream stopped with error: \(error)")

        Task { @MainActor [weak self] in
            self?.isCapturing = false
            self?.error = .streamStopped(error.localizedDescription)
        }
    }
}

// MARK: - SCStreamOutput (Audio Processing)

extension AudioCaptureService: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }

        // Extract audio data from sample buffer
        guard let audioBufferList = getAudioBufferList(from: sampleBuffer) else {
            return
        }

        // Process audio on background queue
        processAudioBuffer(audioBufferList, sampleBuffer: sampleBuffer)
    }

    private nonisolated func getAudioBufferList(from sampleBuffer: CMSampleBuffer) -> AudioBufferList? {
        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?

        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr else {
            print("❌ Failed to get audio buffer list: \(status)")
            return nil
        }

        return audioBufferList
    }

    private nonisolated func processAudioBuffer(_ audioBufferList: AudioBufferList, sampleBuffer: CMSampleBuffer) {
        // Get number of frames
        let numFrames = CMSampleBufferGetNumSamples(sampleBuffer)

        guard numFrames > 0 else { return }

        // Access the audio buffer
        let audioBuffer = audioBufferList.mBuffers

        guard let data = audioBuffer.mData else {
            print("❌ No audio data in buffer")
            metricsQueue.async {
                self._droppedFrames += 1
            }
            return
        }

        // Cast to Float pointer (assuming Float32 PCM format)
        let samples = data.assumingMemoryBound(to: Float.self)

        // Pass to C++ audio engine (thread-safe)
        audioEngine.process(audioData: samples, frameCount: Int32(numFrames), channelCount: Int32(channelCount))

        // Update metrics (thread-safe via dispatch queue)
        metricsQueue.async {
            self._frameCount += Int64(numFrames)

            // Calculate FPS every second
            if let lastTime = self._lastFrameTime, Date().timeIntervalSince(lastTime) >= 1.0 {
                self._lastFrameTime = Date()
            }
        }
    }
}

// MARK: - Supporting Types

enum PermissionStatus {
    case unknown
    case checking
    case authorized
    case denied
}

enum AudioCaptureError: LocalizedError {
    case permissionDenied
    case noDisplayAvailable
    case streamCreationFailed
    case streamStopped(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission denied. Please grant access in System Settings > Privacy & Security > Screen Recording."
        case .noDisplayAvailable:
            return "No display available for audio capture."
        case .streamCreationFailed:
            return "Failed to create audio capture stream."
        case .streamStopped(let reason):
            return "Audio capture stopped: \(reason)"
        }
    }
}
