//
//  AudioEngine.hpp
//  AudioPrimeCore
//
//  C++ AudioEngine class - Core audio processing
//

#ifndef AudioEngine_hpp
#define AudioEngine_hpp

#include <vector>
#include <array>
#include <memory>
#include <Accelerate/Accelerate.h>

namespace AudioPrime {

class AudioEngine {
public:
    AudioEngine();
    ~AudioEngine();

    // Configuration
    void setSampleRate(double sampleRate);
    void setFFTSize(int size);
    void setSmoothing(float smoothing);
    void setMultiResolutionFFT(bool enabled);
    void setPerceptualWeighting(bool enabled);

    // Bass FFT configuration (dedicated high-resolution FFT for bass detail)
    void setBassFFTSize(int size);
    void setBassSmoothing(float smoothing);
    int getBassFFTSize() const { return bass_fft_size_; }
    float getBassSmoothing() const { return bass_smoothing_; }

    // Audio processing
    void process(const float* audioData, int frameCount, int channelCount);

    // Stereo spectrum mode
    void setStereoSpectrum(bool enabled);
    bool getStereoSpectrum() const { return stereo_spectrum_enabled_; }

    // Get analysis results
    void getSpectrum(float* output, int size);
    void getSpectrumLeft(float* output, int size);
    void getSpectrumRight(float* output, int size);
    void getBassDetail(float* output, int size);
    float getLUFSMomentary() const { return lufs_momentary_; }
    float getLUFSShortTerm() const { return lufs_shortterm_; }
    float getLUFSIntegrated() const { return lufs_integrated_; }
    float getTruePeak() const { return true_peak_; }
    float getBPM() const { return bpm_; }

    // Stereo analysis
    float getStereoCorrelation() const { return stereo_correlation_; }
    float getLeftLevel() const { return left_level_; }
    float getRightLevel() const { return right_level_; }
    float getMidLevel() const { return mid_level_; }
    float getSideLevel() const { return side_level_; }
    void getGoniometerPoints(float* xOut, float* yOut, int size);
    int getGoniometerPointCount() const { return static_cast<int>(goniometer_x_.size()); }

    // VU Metering
    float getVULeft() const { return vu_left_; }
    float getVURight() const { return vu_right_; }
    float getPeakLeft() const { return peak_left_; }
    float getPeakRight() const { return peak_right_; }
    float getPeakHoldLeft() const { return peak_hold_left_; }
    float getPeakHoldRight() const { return peak_hold_right_; }

    // Oscilloscope waveform (time-domain display)
    void getWaveformLeft(float* output, int size);
    void getWaveformRight(float* output, int size);
    int getWaveformSize() const { return static_cast<int>(waveform_left_.size()); }

private:
    // Configuration
    double sample_rate_;
    int fft_size_;
    float smoothing_;  // 0.0 = no smoothing, 1.0 = maximum smoothing
    bool use_multi_resolution_fft_;
    bool use_perceptual_weighting_;
    bool stereo_spectrum_enabled_;  // Show L/R separately

    // FFT setup (main spectrum)
    FFTSetup fft_setup_;
    int log2n_;
    DSPSplitComplex split_complex_;

    // Audio buffer for accumulating samples (main spectrum - mono)
    std::vector<float> audio_buffer_;
    size_t buffer_write_pos_;

    // Stereo audio buffers (for L/R spectrum mode)
    std::vector<float> audio_buffer_left_;
    std::vector<float> audio_buffer_right_;
    size_t buffer_write_pos_left_;
    size_t buffer_write_pos_right_;

    // Dedicated Bass FFT (high-resolution for 20-200Hz)
    int bass_fft_size_;           // Typically 4096 or 8192 for bass detail
    float bass_smoothing_;        // Independent smoothing for bass
    FFTSetup bass_fft_setup_;
    int bass_log2n_;
    DSPSplitComplex bass_split_complex_;
    std::vector<float> bass_audio_buffer_;
    size_t bass_buffer_write_pos_;
    std::vector<float> bass_raw_magnitudes_db_;
    std::vector<float> prev_bass_detail_;

    // Analysis results
    std::vector<float> spectrum_data_;
    std::vector<float> prev_spectrum_;  // For smoothing
    std::vector<float> bass_detail_data_;  // 20-200Hz zoomed view
    std::vector<float> raw_magnitudes_db_;  // Raw FFT magnitudes in dB (for bass detail)

    // Stereo spectrum data (L/R channels)
    std::vector<float> spectrum_data_left_;
    std::vector<float> spectrum_data_right_;
    std::vector<float> prev_spectrum_left_;
    std::vector<float> prev_spectrum_right_;

    // Multi-resolution FFT storage
    std::vector<float> mrfft_low_;   // Large FFT for low frequencies
    std::vector<float> mrfft_mid_;   // Medium FFT for mid frequencies
    std::vector<float> mrfft_high_;  // Small FFT for high frequencies

    // A-weighting lookup table
    std::vector<float> a_weighting_;

    // LUFS metering (ITU-R BS.1770-4)
    float lufs_momentary_;      // 400ms window
    float lufs_shortterm_;      // 3s window
    float lufs_integrated_;     // Program duration
    float true_peak_;           // dBTP with 4x oversampling
    float bpm_;

    // LUFS K-weighting filter state (biquad coefficients)
    // Stage 1: High-shelf filter (+4dB at high frequencies)
    // Stage 2: High-pass filter (removes <60Hz rumble)
    std::array<double, 3> kweight_b1_, kweight_a1_;  // High-shelf
    std::array<double, 3> kweight_b2_, kweight_a2_;  // High-pass
    std::array<double, 2> kweight_z1_L_, kweight_z1_R_;  // Filter state L/R stage 1
    std::array<double, 2> kweight_z2_L_, kweight_z2_R_;  // Filter state L/R stage 2

    // LUFS ring buffers for gated measurement
    std::vector<float> lufs_momentary_buffer_;   // 400ms of squared samples
    std::vector<float> lufs_shortterm_buffer_;   // 3s of squared samples
    size_t lufs_momentary_pos_;
    size_t lufs_shortterm_pos_;
    double lufs_integrated_sum_;
    size_t lufs_integrated_count_;

    // VU metering with peak hold
    float vu_left_;
    float vu_right_;
    float peak_left_;
    float peak_right_;
    float peak_hold_left_;
    float peak_hold_right_;
    int peak_hold_samples_left_;
    int peak_hold_samples_right_;
    static constexpr int kPeakHoldTime = 48000;  // 1 second at 48kHz

    // Stereo analysis results
    float stereo_correlation_;
    float left_level_;
    float right_level_;
    float mid_level_;
    float side_level_;
    std::vector<float> goniometer_x_;
    std::vector<float> goniometer_y_;
    static constexpr int kGoniometerPoints = 512;  // Points for Lissajous display

    // Oscilloscope waveform buffers (time-domain display)
    std::vector<float> waveform_left_;
    std::vector<float> waveform_right_;
    size_t waveform_write_pos_;
    static constexpr int kWaveformSize = 1024;  // ~21ms at 48kHz

    // Internal methods
    void initializeFFT();
    void cleanupFFT();
    void performFFT(const float* input, int inputSize);
    void performFFTChannel(const float* input, int inputSize, std::vector<float>& spectrumOut, std::vector<float>& prevSpectrum);
    void performMultiResolutionFFT(const float* input, int inputSize);
    void processStereoAnalysis(const float* audioData, int frameCount);
    void initializeAWeighting();
    float getAWeighting(float frequency);

    // Dedicated bass FFT methods
    void initializeBassFFT();
    void cleanupBassFFT();
    void performBassFFT(const float* input, int inputSize);
    void computeBassDetail();

    // LUFS and metering methods
    void initializeKWeighting();
    void processLUFS(const float* audioData, int frameCount);
    void processVUMeters(const float* audioData, int frameCount);
    float applyKWeighting(float sample, bool isLeft);
    void computeTruePeak(const float* audioData, int frameCount);
};

} // namespace AudioPrime

#endif /* AudioEngine_hpp */
