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
import CoreAudio

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

    // Input gain (linear multiplier, set from dB value)
    nonisolated(unsafe) private var inputGainLinear: Float = 1.0

    // Performance tracking (thread-safe via DispatchQueue)
    private let metricsQueue = DispatchQueue(label: "com.audioprime.metrics")
    nonisolated(unsafe) private var _frameCount: Int64 = 0
    nonisolated(unsafe) private var _lastFrameTime: Date?
    nonisolated(unsafe) private var _droppedFrames: Int = 0

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
        guard !isCapturing else {
            print("⚠️ Already capturing, ignoring start request")
            return
        }

        print("🎤 AudioCaptureService.startCapture() called")

        // Check permission first
        print("📋 Checking screen recording permission...")
        let hasPermission = await checkPermission()
        print("📋 Permission status: \(hasPermission ? "✅ Granted" : "❌ Denied")")
        guard hasPermission else {
            throw AudioCaptureError.permissionDenied
        }

        // Get available content
        print("📺 Getting available content...")
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        print("📺 Found \(content.displays.count) displays, \(content.windows.count) windows")

        guard let display = content.displays.first else {
            print("❌ No display found!")
            throw AudioCaptureError.noDisplayAvailable
        }
        print("📺 Using display: \(display.displayID) - \(display.width)x\(display.height)")

        // Create content filter (capture entire display)
        let filter = SCContentFilter(display: display, excludingWindows: [])
        print("📺 Filter created for display")

        // Configure stream
        let config = SCStreamConfiguration()

        // Audio settings - THIS IS THE KEY: STEREO CAPTURE!
        config.capturesAudio = true
        config.sampleRate = Int(sampleRate)
        config.channelCount = channelCount
        config.excludesCurrentProcessAudio = false  // Capture everything
        print("🔊 Audio config: \(sampleRate)Hz, \(channelCount) channels")

        // Minimal video capture (required for ScreenCaptureKit)
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)  // 1 FPS minimum
        config.queueDepth = 3
        config.showsCursor = false
        print("📹 Video config: 2x2 @ 1fps (minimal)")

        // Create stream
        print("🎬 Creating SCStream...")
        stream = SCStream(filter: filter, configuration: config, delegate: self)

        guard let stream = stream else {
            print("❌ SCStream creation returned nil!")
            throw AudioCaptureError.streamCreationFailed
        }
        print("✅ SCStream created successfully")

        // Add audio output handler
        print("🔊 Adding audio output handler...")
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        print("✅ Audio output handler added")

        // Start capture
        print("▶️ Starting capture...")
        try await stream.startCapture()
        print("✅ Capture started!")

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

    /// Set input gain in dB (-24 to +12 dB range)
    func setInputGain(_ gainDB: Float) {
        // Convert dB to linear multiplier
        // dB = 20 * log10(linear), so linear = 10^(dB/20)
        let clampedGain = max(-24.0, min(12.0, gainDB))
        inputGainLinear = pow(10.0, clampedGain / 20.0)
        print("🔊 Input gain set to \(clampedGain) dB (linear: \(inputGainLinear))")
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

        // Process audio directly from CMSampleBuffer
        processAudioSampleBuffer(sampleBuffer)
    }

    private nonisolated func processAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        let numFrames = CMSampleBufferGetNumSamples(sampleBuffer)
        guard numFrames > 0 else { return }

        // Get format description
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else {
            print("❌ No format description")
            return
        }

        let format = asbd.pointee
        let isNonInterleaved = (format.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0

        // Debug: Print format description once
        metricsQueue.async {
            if self._frameCount == 0 {
                print("🎧 Audio Format Details:")
                print("   Sample Rate: \(format.mSampleRate)")
                print("   Channels: \(format.mChannelsPerFrame)")
                print("   Bits/Channel: \(format.mBitsPerChannel)")
                print("   Bytes/Frame: \(format.mBytesPerFrame)")
                print("   Format Flags: \(format.mFormatFlags)")
                print("   Is Non-Interleaved: \(isNonInterleaved)")
            }
        }

        // Convert CMSampleBuffer to AVAudioPCMBuffer for proper handling
        // This is the recommended approach for ScreenCaptureKit audio
        guard let pcmBuffer = createPCMBuffer(from: sampleBuffer) else {
            return
        }

        // Get the float channel data
        guard let floatChannelData = pcmBuffer.floatChannelData else {
            print("❌ No float channel data")
            return
        }

        let frameLength = Int(pcmBuffer.frameLength)
        let channelCount = Int(pcmBuffer.format.channelCount)

        // Debug first buffer
        metricsQueue.async {
            if self._frameCount == 0 {
                print("🎵 PCM Buffer - Frames: \(frameLength), Channels: \(channelCount)")

                // Print first samples from first channel
                var samples: [Float] = []
                for i in 0..<min(10, frameLength) {
                    samples.append(floatChannelData[0][i])
                }
                print("🎵 First 10 samples (ch0): \(samples.map { String(format: "%.6f", $0) }.joined(separator: ", "))")

                // Check if samples are all zeros
                let nonZeroCount = samples.filter { $0 != 0 }.count
                print("🎵 Non-zero samples: \(nonZeroCount)/10")
            }
        }

        // Interleave the channels for our C++ engine and apply input gain
        var interleaved = [Float](repeating: 0, count: frameLength * 2)
        let leftChannel = floatChannelData[0]
        let rightChannel = channelCount > 1 ? floatChannelData[1] : floatChannelData[0]
        let gain = inputGainLinear  // Capture current gain value

        for i in 0..<frameLength {
            interleaved[i * 2] = leftChannel[i] * gain
            interleaved[i * 2 + 1] = rightChannel[i] * gain
        }

        interleaved.withUnsafeBufferPointer { ptr in
            audioEngine.process(audioData: ptr.baseAddress!, frameCount: Int32(frameLength), channelCount: 2)
        }

        // Update metrics (thread-safe via dispatch queue)
        metricsQueue.async {
            self._frameCount += Int64(frameLength)

            // Calculate FPS every second
            if let lastTime = self._lastFrameTime, Date().timeIntervalSince(lastTime) >= 1.0 {
                self._lastFrameTime = Date()
            }
        }
    }

    /// Convert CMSampleBuffer to AVAudioPCMBuffer for proper handling of non-interleaved audio
    private nonisolated func createPCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            print("❌ No format description for PCM buffer")
            return nil
        }

        let format = AVAudioFormat(cmAudioFormatDescription: formatDesc)

        let numFrames = CMSampleBufferGetNumSamples(sampleBuffer)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numFrames)) else {
            print("❌ Could not create PCM buffer")
            return nil
        }

        pcmBuffer.frameLength = AVAudioFrameCount(numFrames)

        // Copy data from CMSampleBuffer to AVAudioPCMBuffer
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(numFrames),
            into: pcmBuffer.mutableAudioBufferList
        )

        guard status == noErr else {
            print("❌ Failed to copy PCM data: \(status)")
            return nil
        }

        return pcmBuffer
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
