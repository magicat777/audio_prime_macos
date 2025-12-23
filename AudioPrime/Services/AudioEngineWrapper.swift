//
//  AudioEngineWrapper.swift
//  AudioPrime
//
//  Swift wrapper around C++ AudioEngine
//  Provides safe Swift interface to C++ audio processing core
//

import Foundation
import AudioPrimeCore

class AudioEngineWrapper {
    private var engineRef: AudioEngineRef?

    init() {
        engineRef = audio_engine_create()
        print("AudioEngine initialized")
    }

    deinit {
        if let ref = engineRef {
            audio_engine_destroy(ref)
        }
    }

    // MARK: - Configuration

    func setSampleRate(_ sampleRate: Double) {
        guard let ref = engineRef else { return }
        audio_engine_set_sample_rate(ref, sampleRate)
    }

    func setFFTSize(_ size: Int32) {
        guard let ref = engineRef else { return }
        audio_engine_set_fft_size(ref, size)
    }

    func setSmoothing(_ smoothing: Float) {
        guard let ref = engineRef else { return }
        audio_engine_set_smoothing(ref, smoothing)
    }

    // MARK: - Audio Processing

    func process(audioData: UnsafePointer<Float>, frameCount: Int32, channelCount: Int32) {
        guard let ref = engineRef else { return }
        audio_engine_process(ref, audioData, frameCount, channelCount)
    }

    // MARK: - Get Analysis Results

    func getSpectrum(size: Int = 512) -> [Float] {
        guard let ref = engineRef else { return Array(repeating: 0, count: size) }

        var spectrum = [Float](repeating: 0, count: size)
        audio_engine_get_spectrum(ref, &spectrum, Int32(size))
        return spectrum
    }

    func getLUFSMomentary() -> Float {
        guard let ref = engineRef else { return -23.0 }
        return audio_engine_get_lufs_momentary(ref)
    }

    func getLUFSShortTerm() -> Float {
        guard let ref = engineRef else { return -23.0 }
        return audio_engine_get_lufs_shortterm(ref)
    }

    func getLUFSIntegrated() -> Float {
        guard let ref = engineRef else { return -23.0 }
        return audio_engine_get_lufs_integrated(ref)
    }

    func getTruePeak() -> Float {
        guard let ref = engineRef else { return 0.0 }
        return audio_engine_get_true_peak(ref)
    }

    func getBPM() -> Float {
        guard let ref = engineRef else { return 0.0 }
        return audio_engine_get_bpm(ref)
    }

    // MARK: - Stereo Analysis

    func getStereoCorrelation() -> Float {
        guard let ref = engineRef else { return 1.0 }
        return audio_engine_get_stereo_correlation(ref)
    }

    func getLeftLevel() -> Float {
        guard let ref = engineRef else { return 0.0 }
        return audio_engine_get_left_level(ref)
    }

    func getRightLevel() -> Float {
        guard let ref = engineRef else { return 0.0 }
        return audio_engine_get_right_level(ref)
    }

    func getMidLevel() -> Float {
        guard let ref = engineRef else { return 0.0 }
        return audio_engine_get_mid_level(ref)
    }

    func getSideLevel() -> Float {
        guard let ref = engineRef else { return 0.0 }
        return audio_engine_get_side_level(ref)
    }

    func getGoniometerPoints(size: Int = 512) -> (x: [Float], y: [Float]) {
        guard let ref = engineRef else {
            return (Array(repeating: 0, count: size), Array(repeating: 0, count: size))
        }

        var xPoints = [Float](repeating: 0, count: size)
        var yPoints = [Float](repeating: 0, count: size)
        audio_engine_get_goniometer_points(ref, &xPoints, &yPoints, Int32(size))
        return (xPoints, yPoints)
    }

    func getGoniometerPointCount() -> Int {
        guard let ref = engineRef else { return 0 }
        return Int(audio_engine_get_goniometer_point_count(ref))
    }
}
