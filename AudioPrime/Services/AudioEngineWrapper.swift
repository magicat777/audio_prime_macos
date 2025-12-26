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

    func setMultiResolutionFFT(_ enabled: Bool) {
        guard let ref = engineRef else { return }
        audio_engine_set_multi_resolution_fft(ref, enabled)
    }

    func setPerceptualWeighting(_ enabled: Bool) {
        guard let ref = engineRef else { return }
        audio_engine_set_perceptual_weighting(ref, enabled)
    }

    // MARK: - Stereo Spectrum Mode

    func setStereoSpectrum(_ enabled: Bool) {
        guard let ref = engineRef else { return }
        audio_engine_set_stereo_spectrum(ref, enabled)
    }

    func getStereoSpectrum() -> Bool {
        guard let ref = engineRef else { return false }
        return audio_engine_get_stereo_spectrum(ref)
    }

    // MARK: - Bass FFT Configuration (dedicated high-resolution FFT for bass detail)

    func setBassFFTSize(_ size: Int32) {
        guard let ref = engineRef else { return }
        audio_engine_set_bass_fft_size(ref, size)
    }

    func setBassSmoothing(_ smoothing: Float) {
        guard let ref = engineRef else { return }
        audio_engine_set_bass_smoothing(ref, smoothing)
    }

    func getBassFFTSize() -> Int32 {
        guard let ref = engineRef else { return 4096 }
        return audio_engine_get_bass_fft_size(ref)
    }

    func getBassSmoothing() -> Float {
        guard let ref = engineRef else { return 0.3 }
        return audio_engine_get_bass_smoothing(ref)
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

    func getSpectrumLeft(size: Int = 512) -> [Float] {
        guard let ref = engineRef else { return Array(repeating: 0, count: size) }

        var spectrum = [Float](repeating: 0, count: size)
        audio_engine_get_spectrum_left(ref, &spectrum, Int32(size))
        return spectrum
    }

    func getSpectrumRight(size: Int = 512) -> [Float] {
        guard let ref = engineRef else { return Array(repeating: 0, count: size) }

        var spectrum = [Float](repeating: 0, count: size)
        audio_engine_get_spectrum_right(ref, &spectrum, Int32(size))
        return spectrum
    }

    func getBassDetail(size: Int = 64) -> [Float] {
        guard let ref = engineRef else { return Array(repeating: 0, count: size) }

        var bassDetail = [Float](repeating: 0, count: size)
        audio_engine_get_bass_detail(ref, &bassDetail, Int32(size))
        return bassDetail
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

    // MARK: - VU Metering

    func getVULeft() -> Float {
        guard let ref = engineRef else { return 0.0 }
        return audio_engine_get_vu_left(ref)
    }

    func getVURight() -> Float {
        guard let ref = engineRef else { return 0.0 }
        return audio_engine_get_vu_right(ref)
    }

    func getPeakLeft() -> Float {
        guard let ref = engineRef else { return -100.0 }
        return audio_engine_get_peak_left(ref)
    }

    func getPeakRight() -> Float {
        guard let ref = engineRef else { return -100.0 }
        return audio_engine_get_peak_right(ref)
    }

    func getPeakHoldLeft() -> Float {
        guard let ref = engineRef else { return -100.0 }
        return audio_engine_get_peak_hold_left(ref)
    }

    func getPeakHoldRight() -> Float {
        guard let ref = engineRef else { return -100.0 }
        return audio_engine_get_peak_hold_right(ref)
    }

    // MARK: - Oscilloscope Waveform

    func getWaveformLeft(size: Int = 1024) -> [Float] {
        guard let ref = engineRef else { return Array(repeating: 0, count: size) }

        var waveform = [Float](repeating: 0, count: size)
        audio_engine_get_waveform_left(ref, &waveform, Int32(size))
        return waveform
    }

    func getWaveformRight(size: Int = 1024) -> [Float] {
        guard let ref = engineRef else { return Array(repeating: 0, count: size) }

        var waveform = [Float](repeating: 0, count: size)
        audio_engine_get_waveform_right(ref, &waveform, Int32(size))
        return waveform
    }

    func getWaveformSize() -> Int {
        guard let ref = engineRef else { return 1024 }
        return Int(audio_engine_get_waveform_size(ref))
    }
}
