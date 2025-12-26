//
//  AudioEngine.cpp
//  AudioPrimeCore
//
//  C++ AudioEngine implementation
//

#include "AudioEngine.hpp"
#include <cmath>
#include <algorithm>

namespace AudioPrime {

AudioEngine::AudioEngine()
    : sample_rate_(48000.0)
    , fft_size_(512)
    , smoothing_(0.5f)
    , use_multi_resolution_fft_(false)
    , use_perceptual_weighting_(false)
    , stereo_spectrum_enabled_(false)
    , fft_setup_(nullptr)
    , log2n_(0)
    , buffer_write_pos_(0)
    , buffer_write_pos_left_(0)
    , buffer_write_pos_right_(0)
    , bass_fft_size_(4096)        // Default 4096 for ~12Hz resolution
    , bass_smoothing_(0.3f)       // Less smoothing for bass detail
    , bass_fft_setup_(nullptr)
    , bass_log2n_(0)
    , bass_buffer_write_pos_(0)
    , lufs_momentary_(-23.0f)
    , lufs_shortterm_(-23.0f)
    , lufs_integrated_(-23.0f)
    , true_peak_(-100.0f)
    , bpm_(0.0f)
    , lufs_momentary_pos_(0)
    , lufs_shortterm_pos_(0)
    , lufs_integrated_sum_(0.0)
    , lufs_integrated_count_(0)
    , vu_left_(0.0f)
    , vu_right_(0.0f)
    , peak_left_(-100.0f)
    , peak_right_(-100.0f)
    , peak_hold_left_(-100.0f)
    , peak_hold_right_(-100.0f)
    , peak_hold_samples_left_(0)
    , peak_hold_samples_right_(0)
    , stereo_correlation_(1.0f)
    , left_level_(0.0f)
    , right_level_(0.0f)
    , mid_level_(0.0f)
    , side_level_(0.0f)
    , waveform_write_pos_(0)
{
    spectrum_data_.resize(512, 0.0f);
    prev_spectrum_.resize(512, 0.0f);
    bass_detail_data_.resize(64, 0.0f);
    prev_bass_detail_.resize(64, 0.0f);
    audio_buffer_.resize(fft_size_, 0.0f);
    raw_magnitudes_db_.resize(fft_size_ / 2, -80.0f);  // Raw FFT bins in dB
    goniometer_x_.resize(kGoniometerPoints, 0.0f);
    goniometer_y_.resize(kGoniometerPoints, 0.0f);

    // Initialize oscilloscope waveform buffers
    waveform_left_.resize(kWaveformSize, 0.0f);
    waveform_right_.resize(kWaveformSize, 0.0f);

    // Initialize stereo spectrum buffers
    audio_buffer_left_.resize(fft_size_, 0.0f);
    audio_buffer_right_.resize(fft_size_, 0.0f);
    spectrum_data_left_.resize(512, 0.0f);
    spectrum_data_right_.resize(512, 0.0f);
    prev_spectrum_left_.resize(512, 0.0f);
    prev_spectrum_right_.resize(512, 0.0f);

    // Initialize dedicated bass FFT buffers
    bass_audio_buffer_.resize(bass_fft_size_, 0.0f);
    bass_raw_magnitudes_db_.resize(bass_fft_size_ / 2, -80.0f);

    // Initialize multi-resolution FFT buffers
    mrfft_low_.resize(256, 0.0f);   // For bass
    mrfft_mid_.resize(256, 0.0f);   // For mids
    mrfft_high_.resize(256, 0.0f);  // For highs

    // Initialize LUFS ring buffers
    // 400ms at 48kHz = 19200 samples, 3s = 144000 samples
    size_t momentarySize = static_cast<size_t>(sample_rate_ * 0.4);
    size_t shorttermSize = static_cast<size_t>(sample_rate_ * 3.0);
    lufs_momentary_buffer_.resize(momentarySize, 0.0f);
    lufs_shortterm_buffer_.resize(shorttermSize, 0.0f);

    // Initialize K-weighting filter state
    kweight_z1_L_ = {0.0, 0.0};
    kweight_z1_R_ = {0.0, 0.0};
    kweight_z2_L_ = {0.0, 0.0};
    kweight_z2_R_ = {0.0, 0.0};

    initializeFFT();
    initializeBassFFT();
    initializeAWeighting();
    initializeKWeighting();
}

AudioEngine::~AudioEngine() {
    cleanupFFT();
    cleanupBassFFT();
}

void AudioEngine::setSampleRate(double sampleRate) {
    sample_rate_ = sampleRate;
}

void AudioEngine::setFFTSize(int size) {
    if (size == fft_size_) return;

    cleanupFFT();
    fft_size_ = size;
    spectrum_data_.resize(512, 0.0f);  // Always 512 display bars
    prev_spectrum_.resize(512, 0.0f);
    audio_buffer_.resize(fft_size_, 0.0f);
    raw_magnitudes_db_.resize(fft_size_ / 2, -80.0f);  // Resize raw FFT bins
    buffer_write_pos_ = 0;

    // Resize stereo buffers
    audio_buffer_left_.resize(fft_size_, 0.0f);
    audio_buffer_right_.resize(fft_size_, 0.0f);
    buffer_write_pos_left_ = 0;
    buffer_write_pos_right_ = 0;

    initializeFFT();
}

void AudioEngine::setSmoothing(float smoothing) {
    smoothing_ = std::max(0.0f, std::min(1.0f, smoothing));
}

void AudioEngine::setMultiResolutionFFT(bool enabled) {
    use_multi_resolution_fft_ = enabled;
}

void AudioEngine::setPerceptualWeighting(bool enabled) {
    use_perceptual_weighting_ = enabled;
}

void AudioEngine::setStereoSpectrum(bool enabled) {
    stereo_spectrum_enabled_ = enabled;
}

void AudioEngine::setBassFFTSize(int size) {
    if (size == bass_fft_size_) return;

    cleanupBassFFT();
    bass_fft_size_ = size;
    bass_audio_buffer_.resize(bass_fft_size_, 0.0f);
    bass_raw_magnitudes_db_.resize(bass_fft_size_ / 2, -80.0f);
    bass_buffer_write_pos_ = 0;
    initializeBassFFT();
}

void AudioEngine::setBassSmoothing(float smoothing) {
    bass_smoothing_ = std::max(0.0f, std::min(1.0f, smoothing));
}

void AudioEngine::initializeAWeighting() {
    // Pre-compute A-weighting curve for 512 display bars (20Hz to 20kHz)
    a_weighting_.resize(512);

    const float logMin = std::log10(20.0f);
    const float logMax = std::log10(20000.0f);

    for (int i = 0; i < 512; ++i) {
        float logFreq = logMin + (logMax - logMin) * i / 511.0f;
        float freq = std::pow(10.0f, logFreq);
        a_weighting_[i] = getAWeighting(freq);
    }
}

float AudioEngine::getAWeighting(float frequency) {
    // A-weighting formula (IEC 61672-1)
    // Ra(f) = 12194^2 * f^4 / ((f^2 + 20.6^2) * sqrt((f^2 + 107.7^2)(f^2 + 737.9^2)) * (f^2 + 12194^2))
    // A(f) = 20 * log10(Ra(f)) + 2.0 (normalized to 0dB at 1kHz)

    float f2 = frequency * frequency;
    float f4 = f2 * f2;

    float num = 12194.0f * 12194.0f * f4;
    float denom = (f2 + 20.6f * 20.6f)
                * std::sqrt((f2 + 107.7f * 107.7f) * (f2 + 737.9f * 737.9f))
                * (f2 + 12194.0f * 12194.0f);

    if (denom < 1e-10f) return -80.0f;

    float ra = num / denom;
    float aWeight = 20.0f * std::log10(ra + 1e-10f) + 2.0f;

    // Convert from dB adjustment to linear multiplier (normalized 0-1)
    // A-weighting at 1kHz = 0dB, at 100Hz ≈ -20dB, at 20Hz ≈ -50dB
    // Map range roughly -50dB to +2dB → 0 to 1 multiplier
    float normalized = (aWeight + 50.0f) / 52.0f;
    return std::max(0.0f, std::min(1.0f, normalized));
}

void AudioEngine::computeBassDetail() {
    // Extract and expand the 20-200Hz range into 64 bars
    // Uses DEDICATED BASS FFT for maximum resolution
    // At 48kHz: 4096 FFT = 11.7Hz/bin, 8192 FFT = 5.86Hz/bin
    // This gives us 15-30 bins in the 20-200Hz range instead of 2!

    const float bassMinFreq = 20.0f;
    const float bassMaxFreq = 200.0f;
    const float logMin = std::log10(bassMinFreq);
    const float logMax = std::log10(bassMaxFreq);

    // Use the dedicated bass FFT resolution
    float binFreqResolution = sample_rate_ / bass_fft_size_;
    int numBins = static_cast<int>(bass_raw_magnitudes_db_.size());

    if (numBins == 0) return;

    for (int i = 0; i < 64; ++i) {
        // Calculate the frequency for this bass detail bar (logarithmic scale)
        float logFreq = logMin + (logMax - logMin) * i / 63.0f;
        float freq = std::pow(10.0f, logFreq);

        // Convert frequency to FFT bin index (from dedicated bass FFT)
        float binIndex = freq / binFreqResolution;

        // Clamp to valid range
        int idx0 = static_cast<int>(binIndex);
        idx0 = std::max(0, std::min(idx0, numBins - 1));

        float dbValue;
        if (numBins >= 4 && idx0 >= 1 && idx0 < numBins - 2) {
            // Catmull-Rom cubic interpolation for smoother curves
            float t = binIndex - idx0;
            float p0 = bass_raw_magnitudes_db_[idx0 - 1];
            float p1 = bass_raw_magnitudes_db_[idx0];
            float p2 = bass_raw_magnitudes_db_[idx0 + 1];
            float p3 = bass_raw_magnitudes_db_[idx0 + 2];

            // Catmull-Rom spline formula
            dbValue = 0.5f * (
                2.0f * p1 +
                (-p0 + p2) * t +
                (2.0f * p0 - 5.0f * p1 + 4.0f * p2 - p3) * t * t +
                (-p0 + 3.0f * p1 - 3.0f * p2 + p3) * t * t * t
            );
        } else {
            // Fall back to linear interpolation at edges
            int idx1 = std::min(idx0 + 1, numBins - 1);
            float frac = binIndex - idx0;
            dbValue = bass_raw_magnitudes_db_[idx0] * (1.0f - frac) + bass_raw_magnitudes_db_[idx1] * frac;
        }

        // Normalize to 0-1 range (from -80dB to 0dB)
        float normalized = (dbValue + 80.0f) / 80.0f;
        normalized = std::max(0.0f, std::min(1.0f, normalized));

        // Apply bass-specific smoothing (user-configurable)
        // bass_smoothing_ default is 0.3 - more responsive than main spectrum
        float alpha = 1.0f - (bass_smoothing_ * 0.95f);
        bass_detail_data_[i] = alpha * normalized + (1.0f - alpha) * prev_bass_detail_[i];
        prev_bass_detail_[i] = bass_detail_data_[i];
    }
}

void AudioEngine::getBassDetail(float* output, int size) {
    int copySize = std::min(size, static_cast<int>(bass_detail_data_.size()));
    std::copy(bass_detail_data_.begin(), bass_detail_data_.begin() + copySize, output);
}

void AudioEngine::performMultiResolutionFFT(const float* input, int inputSize) {
    // Multi-Resolution FFT simulation
    // Based on original AUDIO_PRIME approach:
    // - Sub-bass (20-60 Hz): Would use 8192-point FFT (~5.86 Hz resolution)
    // - Bass (60-250 Hz): Would use 4096-point FFT (~11.7 Hz resolution)
    // - Low-mid (250-1000 Hz): Would use 2048-point FFT
    // - Mid (1000-4000 Hz): Would use 2048-point FFT
    // - High (4000-20000 Hz): Would use 1024-point FFT

    // Apply frequency-dependent processing:
    // 1. Frequency-dependent noise floor (attenuate bass to prevent clipping)
    // 2. Frequency-dependent smoothing (more smoothing for bass, less for highs)

    const float logMin = std::log10(20.0f);
    const float logMax = std::log10(20000.0f);

    for (int i = 0; i < 512; ++i) {
        float logFreq = logMin + (logMax - logMin) * i / 511.0f;
        float freq = std::pow(10.0f, logFreq);

        float currentValue = spectrum_data_[i];

        // Frequency-dependent scaling to prevent bass from clipping
        // Apply gentle attenuation to low frequencies (they naturally have more energy)
        float noiseFloorAdjust = 1.0f;
        if (freq < 60.0f) {
            // Sub-bass: attenuate to prevent clipping
            noiseFloorAdjust = 0.7f;
        } else if (freq < 250.0f) {
            // Bass: moderate attenuation
            noiseFloorAdjust = 0.8f;
        } else if (freq < 1000.0f) {
            // Low-mid: slight attenuation
            noiseFloorAdjust = 0.9f;
        } else {
            // Mid and high: no adjustment
            noiseFloorAdjust = 1.0f;
        }

        currentValue *= noiseFloorAdjust;

        // Frequency-dependent smoothing
        float freqSmoothing;
        if (freq < 60.0f) {
            freqSmoothing = 0.85f;  // Heavy smoothing for sub-bass
        } else if (freq < 250.0f) {
            freqSmoothing = 0.75f;  // Heavy smoothing for bass
        } else if (freq < 1000.0f) {
            freqSmoothing = 0.5f;   // Medium smoothing for low-mids
        } else if (freq < 4000.0f) {
            freqSmoothing = 0.3f;   // Light smoothing for mids
        } else {
            freqSmoothing = 0.15f;  // Very light smoothing for highs (fast response)
        }

        // Blend with user smoothing setting
        float effectiveSmoothing = smoothing_ * 0.3f + freqSmoothing * 0.7f;
        float alpha = 1.0f - (effectiveSmoothing * 0.95f);

        // Apply frequency-weighted smoothing
        spectrum_data_[i] = alpha * currentValue + (1.0f - alpha) * prev_spectrum_[i];
    }
}

void AudioEngine::initializeFFT() {
    log2n_ = static_cast<int>(std::log2(fft_size_));
    fft_setup_ = vDSP_create_fftsetup(log2n_, FFT_RADIX2);

    split_complex_.realp = new float[fft_size_ / 2];
    split_complex_.imagp = new float[fft_size_ / 2];
}

void AudioEngine::cleanupFFT() {
    if (fft_setup_) {
        vDSP_destroy_fftsetup(fft_setup_);
        fft_setup_ = nullptr;
    }

    if (split_complex_.realp) {
        delete[] split_complex_.realp;
        split_complex_.realp = nullptr;
    }

    if (split_complex_.imagp) {
        delete[] split_complex_.imagp;
        split_complex_.imagp = nullptr;
    }
}

// MARK: - Dedicated Bass FFT

void AudioEngine::initializeBassFFT() {
    bass_log2n_ = static_cast<int>(std::log2(bass_fft_size_));
    bass_fft_setup_ = vDSP_create_fftsetup(bass_log2n_, FFT_RADIX2);

    bass_split_complex_.realp = new float[bass_fft_size_ / 2];
    bass_split_complex_.imagp = new float[bass_fft_size_ / 2];
}

void AudioEngine::cleanupBassFFT() {
    if (bass_fft_setup_) {
        vDSP_destroy_fftsetup(bass_fft_setup_);
        bass_fft_setup_ = nullptr;
    }

    if (bass_split_complex_.realp) {
        delete[] bass_split_complex_.realp;
        bass_split_complex_.realp = nullptr;
    }

    if (bass_split_complex_.imagp) {
        delete[] bass_split_complex_.imagp;
        bass_split_complex_.imagp = nullptr;
    }
}

void AudioEngine::performBassFFT(const float* input, int inputSize) {
    if (!bass_fft_setup_ || inputSize != bass_fft_size_) return;

    // Apply Hann window
    std::vector<float> windowed(bass_fft_size_);
    for (int i = 0; i < bass_fft_size_; ++i) {
        float window = 0.5f * (1.0f - std::cos(2.0f * M_PI * i / (bass_fft_size_ - 1)));
        windowed[i] = input[i] * window;
    }

    // Convert to split complex format
    vDSP_ctoz((const DSPComplex*)windowed.data(), 2, &bass_split_complex_, 1, bass_fft_size_ / 2);

    // Perform FFT
    vDSP_fft_zrip(bass_fft_setup_, &bass_split_complex_, 1, bass_log2n_, FFT_FORWARD);

    // Compute magnitudes
    std::vector<float> magnitudes(bass_fft_size_ / 2);
    vDSP_zvabs(&bass_split_complex_, 1, magnitudes.data(), 1, bass_fft_size_ / 2);

    // Scale and convert to dB
    float scale = 1.0f / (bass_fft_size_ * 0.5f);
    for (int i = 0; i < bass_fft_size_ / 2; ++i) {
        magnitudes[i] *= scale;
        float db = 20.0f * std::log10(magnitudes[i] + 1e-10f);
        bass_raw_magnitudes_db_[i] = std::max(-80.0f, std::min(0.0f, db));
    }

    // Compute bass detail from the dedicated bass FFT
    computeBassDetail();
}

void AudioEngine::process(const float* audioData, int frameCount, int channelCount) {
    if (!audioData || frameCount <= 0) return;

    // Process stereo analysis on the raw interleaved data
    if (channelCount == 2) {
        processStereoAnalysis(audioData, frameCount);
        processLUFS(audioData, frameCount);
        processVUMeters(audioData, frameCount);
        computeTruePeak(audioData, frameCount);
    }

    // Process audio samples
    for (int i = 0; i < frameCount; ++i) {
        float left, right, mono;
        if (channelCount == 2) {
            left = audioData[i * 2];
            right = audioData[i * 2 + 1];
            mono = (left + right) * 0.5f;
        } else {
            left = right = mono = audioData[i];
        }

        // Accumulate into oscilloscope waveform buffers (ring buffer)
        waveform_left_[waveform_write_pos_] = left;
        waveform_right_[waveform_write_pos_] = right;
        waveform_write_pos_ = (waveform_write_pos_ + 1) % kWaveformSize;

        // Accumulate into main spectrum buffer (mono)
        audio_buffer_[buffer_write_pos_] = mono;
        buffer_write_pos_++;

        // When main buffer is full, perform FFT
        if (buffer_write_pos_ >= static_cast<size_t>(fft_size_)) {
            performFFT(audio_buffer_.data(), fft_size_);

            // Use 75% overlap for lower latency
            size_t hopSize = fft_size_ / 4;
            size_t overlap = fft_size_ - hopSize;
            std::copy(audio_buffer_.begin() + hopSize, audio_buffer_.end(), audio_buffer_.begin());
            buffer_write_pos_ = overlap;
        }

        // If stereo spectrum mode is enabled, accumulate L/R buffers separately
        if (stereo_spectrum_enabled_ && channelCount == 2) {
            // Left channel buffer
            audio_buffer_left_[buffer_write_pos_left_] = left;
            buffer_write_pos_left_++;

            if (buffer_write_pos_left_ >= static_cast<size_t>(fft_size_)) {
                performFFTChannel(audio_buffer_left_.data(), fft_size_, spectrum_data_left_, prev_spectrum_left_);

                size_t hopSize = fft_size_ / 4;
                size_t overlap = fft_size_ - hopSize;
                std::copy(audio_buffer_left_.begin() + hopSize, audio_buffer_left_.end(), audio_buffer_left_.begin());
                buffer_write_pos_left_ = overlap;
            }

            // Right channel buffer
            audio_buffer_right_[buffer_write_pos_right_] = right;
            buffer_write_pos_right_++;

            if (buffer_write_pos_right_ >= static_cast<size_t>(fft_size_)) {
                performFFTChannel(audio_buffer_right_.data(), fft_size_, spectrum_data_right_, prev_spectrum_right_);

                size_t hopSize = fft_size_ / 4;
                size_t overlap = fft_size_ - hopSize;
                std::copy(audio_buffer_right_.begin() + hopSize, audio_buffer_right_.end(), audio_buffer_right_.begin());
                buffer_write_pos_right_ = overlap;
            }
        }

        // Accumulate into dedicated bass FFT buffer
        bass_audio_buffer_[bass_buffer_write_pos_] = mono;
        bass_buffer_write_pos_++;

        // When bass buffer is full, perform dedicated bass FFT
        if (bass_buffer_write_pos_ >= static_cast<size_t>(bass_fft_size_)) {
            performBassFFT(bass_audio_buffer_.data(), bass_fft_size_);

            // Use 75% overlap for bass FFT too
            size_t bassHopSize = bass_fft_size_ / 4;
            size_t bassOverlap = bass_fft_size_ - bassHopSize;
            std::copy(bass_audio_buffer_.begin() + bassHopSize, bass_audio_buffer_.end(), bass_audio_buffer_.begin());
            bass_buffer_write_pos_ = bassOverlap;
        }
    }
}

void AudioEngine::performFFT(const float* input, int inputSize) {
    if (!fft_setup_ || inputSize != fft_size_) return;

    // Apply Hann window
    std::vector<float> windowed(fft_size_);
    for (int i = 0; i < fft_size_; ++i) {
        float window = 0.5f * (1.0f - std::cos(2.0f * M_PI * i / (fft_size_ - 1)));
        windowed[i] = input[i] * window;
    }

    // Convert to split complex format
    vDSP_ctoz((const DSPComplex*)windowed.data(), 2, &split_complex_, 1, fft_size_ / 2);

    // Perform FFT
    vDSP_fft_zrip(fft_setup_, &split_complex_, 1, log2n_, FFT_FORWARD);

    // Compute magnitudes
    std::vector<float> magnitudes(fft_size_ / 2);
    vDSP_zvabs(&split_complex_, 1, magnitudes.data(), 1, fft_size_ / 2);

    // Scale and convert to dB
    float scale = 1.0f / (fft_size_ * 0.5f);
    for (int i = 0; i < fft_size_ / 2; ++i) {
        magnitudes[i] *= scale;
        float db = 20.0f * std::log10(magnitudes[i] + 1e-10f);
        magnitudes[i] = std::max(-80.0f, std::min(0.0f, db));
    }

    // Store raw magnitudes for bass detail computation
    raw_magnitudes_db_ = magnitudes;

    // Map to logarithmic frequency scale (512 bars from 20Hz to 20kHz)
    // FFT gives us fft_size/2 bins, we need to map to 512 display bars
    int numBins = fft_size_ / 2;  // e.g., 256 bins for 512 FFT
    float binFreqResolution = sample_rate_ / fft_size_;  // Hz per bin (e.g., 93.75 Hz)

    // Logarithmic frequency mapping from 20Hz to 20kHz
    const float minFreq = 20.0f;
    const float maxFreq = 20000.0f;
    const float logMin = std::log10(minFreq);
    const float logMax = std::log10(maxFreq);

    for (int i = 0; i < 512; ++i) {
        // Calculate the frequency for this display bar (logarithmic scale)
        float logFreq = logMin + (logMax - logMin) * i / 511.0f;
        float freq = std::pow(10.0f, logFreq);

        // Convert frequency to FFT bin index
        float binIndex = freq / binFreqResolution;

        // Clamp to valid bin range
        binIndex = std::max(0.0f, std::min(binIndex, (float)(numBins - 1)));

        // Linear interpolation between adjacent bins
        int idx0 = (int)binIndex;
        int idx1 = std::min(idx0 + 1, numBins - 1);
        float frac = binIndex - idx0;

        float value = magnitudes[idx0] * (1.0f - frac) + magnitudes[idx1] * frac;

        // Normalize to 0-1 range (from -80dB to 0dB)
        float normalized = (value + 80.0f) / 80.0f;

        // Apply A-weighting if enabled (perceptual frequency weighting)
        if (use_perceptual_weighting_ && i < static_cast<int>(a_weighting_.size())) {
            normalized *= a_weighting_[i];
        }

        // Apply smoothing (exponential moving average)
        // smoothing_ = 0 means no smoothing (instant response)
        // smoothing_ = 1 means maximum smoothing (very slow decay)
        float alpha = 1.0f - (smoothing_ * 0.95f);  // Map 0-1 to 1-0.05
        spectrum_data_[i] = alpha * normalized + (1.0f - alpha) * prev_spectrum_[i];
    }

    // Apply multi-resolution FFT processing if enabled
    if (use_multi_resolution_fft_) {
        performMultiResolutionFFT(input, inputSize);
    }

    // Store current spectrum for next frame's smoothing
    prev_spectrum_ = spectrum_data_;

    // Note: Bass detail is now computed separately in performBassFFT()
    // which uses a dedicated high-resolution FFT for the 20-200Hz range
}

void AudioEngine::performFFTChannel(const float* input, int inputSize, std::vector<float>& spectrumOut, std::vector<float>& prevSpectrum) {
    if (!fft_setup_ || inputSize != fft_size_) return;

    // Apply Hann window
    std::vector<float> windowed(fft_size_);
    for (int i = 0; i < fft_size_; ++i) {
        float window = 0.5f * (1.0f - std::cos(2.0f * M_PI * i / (fft_size_ - 1)));
        windowed[i] = input[i] * window;
    }

    // Convert to split complex format
    vDSP_ctoz((const DSPComplex*)windowed.data(), 2, &split_complex_, 1, fft_size_ / 2);

    // Perform FFT
    vDSP_fft_zrip(fft_setup_, &split_complex_, 1, log2n_, FFT_FORWARD);

    // Compute magnitudes
    std::vector<float> magnitudes(fft_size_ / 2);
    vDSP_zvabs(&split_complex_, 1, magnitudes.data(), 1, fft_size_ / 2);

    // Scale and convert to dB
    float scale = 1.0f / (fft_size_ * 0.5f);
    for (int i = 0; i < fft_size_ / 2; ++i) {
        magnitudes[i] *= scale;
        float db = 20.0f * std::log10(magnitudes[i] + 1e-10f);
        magnitudes[i] = std::max(-80.0f, std::min(0.0f, db));
    }

    // Map to logarithmic frequency scale (512 bars from 20Hz to 20kHz)
    int numBins = fft_size_ / 2;
    float binFreqResolution = sample_rate_ / fft_size_;

    const float minFreq = 20.0f;
    const float maxFreq = 20000.0f;
    const float logMin = std::log10(minFreq);
    const float logMax = std::log10(maxFreq);

    for (int i = 0; i < 512; ++i) {
        float logFreq = logMin + (logMax - logMin) * i / 511.0f;
        float freq = std::pow(10.0f, logFreq);

        float binIndex = freq / binFreqResolution;
        binIndex = std::max(0.0f, std::min(binIndex, (float)(numBins - 1)));

        int idx0 = (int)binIndex;
        int idx1 = std::min(idx0 + 1, numBins - 1);
        float frac = binIndex - idx0;

        float value = magnitudes[idx0] * (1.0f - frac) + magnitudes[idx1] * frac;

        // Normalize to 0-1 range (from -80dB to 0dB)
        float normalized = (value + 80.0f) / 80.0f;

        // Apply A-weighting if enabled
        if (use_perceptual_weighting_ && i < static_cast<int>(a_weighting_.size())) {
            normalized *= a_weighting_[i];
        }

        // Apply smoothing
        float alpha = 1.0f - (smoothing_ * 0.95f);
        spectrumOut[i] = alpha * normalized + (1.0f - alpha) * prevSpectrum[i];
    }

    // Store current spectrum for next frame's smoothing
    prevSpectrum = spectrumOut;
}

void AudioEngine::getSpectrum(float* output, int size) {
    int copySize = std::min(size, static_cast<int>(spectrum_data_.size()));
    std::copy(spectrum_data_.begin(), spectrum_data_.begin() + copySize, output);
}

void AudioEngine::getSpectrumLeft(float* output, int size) {
    int copySize = std::min(size, static_cast<int>(spectrum_data_left_.size()));
    std::copy(spectrum_data_left_.begin(), spectrum_data_left_.begin() + copySize, output);
}

void AudioEngine::getSpectrumRight(float* output, int size) {
    int copySize = std::min(size, static_cast<int>(spectrum_data_right_.size()));
    std::copy(spectrum_data_right_.begin(), spectrum_data_right_.begin() + copySize, output);
}

void AudioEngine::getWaveformLeft(float* output, int size) {
    int copySize = std::min(size, kWaveformSize);
    // Copy from ring buffer starting at write position (oldest samples first)
    for (int i = 0; i < copySize; ++i) {
        int idx = (waveform_write_pos_ + i) % kWaveformSize;
        output[i] = waveform_left_[idx];
    }
}

void AudioEngine::getWaveformRight(float* output, int size) {
    int copySize = std::min(size, kWaveformSize);
    // Copy from ring buffer starting at write position (oldest samples first)
    for (int i = 0; i < copySize; ++i) {
        int idx = (waveform_write_pos_ + i) % kWaveformSize;
        output[i] = waveform_right_[idx];
    }
}

void AudioEngine::processStereoAnalysis(const float* audioData, int frameCount) {
    if (frameCount <= 0) return;

    // Calculate RMS levels for left and right channels
    float leftSum = 0.0f, rightSum = 0.0f;
    float correlationSum = 0.0f;
    float leftSquareSum = 0.0f, rightSquareSum = 0.0f;

    // Limit samples for goniometer to avoid buffer overflow
    int goniometerSamples = std::min(frameCount, kGoniometerPoints);

    for (int i = 0; i < frameCount; ++i) {
        float left = audioData[i * 2];
        float right = audioData[i * 2 + 1];

        // Accumulate for RMS
        leftSum += left * left;
        rightSum += right * right;

        // Accumulate for correlation (Pearson correlation coefficient)
        correlationSum += left * right;
        leftSquareSum += left * left;
        rightSquareSum += right * right;

        // Store samples for goniometer (downsample if needed)
        if (i < goniometerSamples) {
            // Goniometer: X = (L+R)/2 (Mid), Y = (L-R)/2 (Side)
            // Rotated 45 degrees for standard Lissajous display
            goniometer_x_[i] = (left + right) * 0.5f;  // Mid
            goniometer_y_[i] = (left - right) * 0.5f;  // Side
        }
    }

    // Calculate RMS levels (with smoothing)
    float newLeftLevel = std::sqrt(leftSum / frameCount);
    float newRightLevel = std::sqrt(rightSum / frameCount);

    // Apply smoothing to levels
    float levelSmoothing = 0.8f;  // Fast attack, slower decay
    left_level_ = std::max(newLeftLevel, left_level_ * levelSmoothing);
    right_level_ = std::max(newRightLevel, right_level_ * levelSmoothing);

    // Calculate Mid/Side levels
    // Mid = (L + R) / 2, Side = (L - R) / 2
    float midSum = 0.0f, sideSum = 0.0f;
    for (int i = 0; i < frameCount; ++i) {
        float left = audioData[i * 2];
        float right = audioData[i * 2 + 1];
        float mid = (left + right) * 0.5f;
        float side = (left - right) * 0.5f;
        midSum += mid * mid;
        sideSum += side * side;
    }

    float newMidLevel = std::sqrt(midSum / frameCount);
    float newSideLevel = std::sqrt(sideSum / frameCount);

    mid_level_ = std::max(newMidLevel, mid_level_ * levelSmoothing);
    side_level_ = std::max(newSideLevel, side_level_ * levelSmoothing);

    // Calculate stereo correlation
    // correlation = sum(L*R) / sqrt(sum(L^2) * sum(R^2))
    float denominator = std::sqrt(leftSquareSum * rightSquareSum);
    if (denominator > 1e-10f) {
        float newCorrelation = correlationSum / denominator;
        // Smooth correlation
        stereo_correlation_ = stereo_correlation_ * 0.9f + newCorrelation * 0.1f;
    }

    // Clamp correlation to valid range
    stereo_correlation_ = std::max(-1.0f, std::min(1.0f, stereo_correlation_));
}

void AudioEngine::getGoniometerPoints(float* xOut, float* yOut, int size) {
    int copySize = std::min(size, static_cast<int>(goniometer_x_.size()));
    std::copy(goniometer_x_.begin(), goniometer_x_.begin() + copySize, xOut);
    std::copy(goniometer_y_.begin(), goniometer_y_.begin() + copySize, yOut);
}

// MARK: - LUFS and Metering Implementation

void AudioEngine::initializeKWeighting() {
    // ITU-R BS.1770-4 K-weighting filter coefficients for 48kHz
    // Stage 1: High-shelf filter (+4dB boost above ~1500Hz)
    // Pre-computed biquad coefficients
    kweight_b1_ = {1.53512485958697, -2.69169618940638, 1.19839281085285};
    kweight_a1_ = {1.0, -1.69065929318241, 0.73248077421585};

    // Stage 2: High-pass filter (RLB weighting, -3dB at ~60Hz)
    kweight_b2_ = {1.0, -2.0, 1.0};
    kweight_a2_ = {1.0, -1.99004745483398, 0.99007225036621};
}

float AudioEngine::applyKWeighting(float sample, bool isLeft) {
    // Apply biquad filter stage 1 (high-shelf)
    auto& z1 = isLeft ? kweight_z1_L_ : kweight_z1_R_;
    double x = sample;
    double y1 = kweight_b1_[0] * x + z1[0];
    z1[0] = kweight_b1_[1] * x - kweight_a1_[1] * y1 + z1[1];
    z1[1] = kweight_b1_[2] * x - kweight_a1_[2] * y1;

    // Apply biquad filter stage 2 (high-pass)
    auto& z2 = isLeft ? kweight_z2_L_ : kweight_z2_R_;
    double y2 = kweight_b2_[0] * y1 + z2[0];
    z2[0] = kweight_b2_[1] * y1 - kweight_a2_[1] * y2 + z2[1];
    z2[1] = kweight_b2_[2] * y1 - kweight_a2_[2] * y2;

    return static_cast<float>(y2);
}

void AudioEngine::processLUFS(const float* audioData, int frameCount) {
    // ITU-R BS.1770-4 LUFS measurement
    // 1. Apply K-weighting filter
    // 2. Square the samples
    // 3. Average over measurement window
    // 4. Convert to LUFS: -0.691 + 10 * log10(mean_square)

    for (int i = 0; i < frameCount; ++i) {
        float left = audioData[i * 2];
        float right = audioData[i * 2 + 1];

        // Apply K-weighting
        float kLeft = applyKWeighting(left, true);
        float kRight = applyKWeighting(right, false);

        // Sum of squares (stereo: average of L and R)
        float sumSquare = (kLeft * kLeft + kRight * kRight) * 0.5f;

        // Update momentary buffer (400ms)
        if (!lufs_momentary_buffer_.empty()) {
            lufs_momentary_buffer_[lufs_momentary_pos_] = sumSquare;
            lufs_momentary_pos_ = (lufs_momentary_pos_ + 1) % lufs_momentary_buffer_.size();
        }

        // Update short-term buffer (3s)
        if (!lufs_shortterm_buffer_.empty()) {
            lufs_shortterm_buffer_[lufs_shortterm_pos_] = sumSquare;
            lufs_shortterm_pos_ = (lufs_shortterm_pos_ + 1) % lufs_shortterm_buffer_.size();
        }

        // Accumulate for integrated loudness
        lufs_integrated_sum_ += sumSquare;
        lufs_integrated_count_++;
    }

    // Calculate momentary loudness (400ms)
    if (!lufs_momentary_buffer_.empty()) {
        double momentarySum = 0.0;
        for (float val : lufs_momentary_buffer_) {
            momentarySum += val;
        }
        double momentaryMean = momentarySum / lufs_momentary_buffer_.size();
        if (momentaryMean > 1e-10) {
            lufs_momentary_ = static_cast<float>(-0.691 + 10.0 * std::log10(momentaryMean));
        } else {
            lufs_momentary_ = -70.0f;
        }
    }

    // Calculate short-term loudness (3s)
    if (!lufs_shortterm_buffer_.empty()) {
        double shorttermSum = 0.0;
        for (float val : lufs_shortterm_buffer_) {
            shorttermSum += val;
        }
        double shorttermMean = shorttermSum / lufs_shortterm_buffer_.size();
        if (shorttermMean > 1e-10) {
            lufs_shortterm_ = static_cast<float>(-0.691 + 10.0 * std::log10(shorttermMean));
        } else {
            lufs_shortterm_ = -70.0f;
        }
    }

    // Calculate integrated loudness (entire program)
    if (lufs_integrated_count_ > 0) {
        double integratedMean = lufs_integrated_sum_ / lufs_integrated_count_;
        if (integratedMean > 1e-10) {
            lufs_integrated_ = static_cast<float>(-0.691 + 10.0 * std::log10(integratedMean));
        } else {
            lufs_integrated_ = -70.0f;
        }
    }

    // Clamp LUFS values to reasonable range
    lufs_momentary_ = std::max(-70.0f, std::min(0.0f, lufs_momentary_));
    lufs_shortterm_ = std::max(-70.0f, std::min(0.0f, lufs_shortterm_));
    lufs_integrated_ = std::max(-70.0f, std::min(0.0f, lufs_integrated_));
}

void AudioEngine::processVUMeters(const float* audioData, int frameCount) {
    // Professional VU meter implementation
    // - VU meters measure RMS (average power), not peak
    // - Standard VU integration time: 300ms
    // - 0 VU typically calibrated to -18 dBFS (we use -14 dBFS for modern content)

    // Calculate RMS for this frame
    float leftSquareSum = 0.0f;
    float rightSquareSum = 0.0f;
    float leftPeak = 0.0f;
    float rightPeak = 0.0f;

    for (int i = 0; i < frameCount; ++i) {
        float left = audioData[i * 2];
        float right = audioData[i * 2 + 1];

        leftSquareSum += left * left;
        rightSquareSum += right * right;

        // Track instantaneous peak
        float absLeft = std::fabs(left);
        float absRight = std::fabs(right);
        leftPeak = std::max(leftPeak, absLeft);
        rightPeak = std::max(rightPeak, absRight);
    }

    // Calculate RMS for this frame
    float leftRMS = std::sqrt(leftSquareSum / frameCount);
    float rightRMS = std::sqrt(rightSquareSum / frameCount);

    // VU meter ballistics (300ms integration time)
    // Time constant for exponential averaging
    const float vuTimeConstant = 0.3f;  // 300ms
    float alpha = 1.0f - std::exp(-frameCount / (sample_rate_ * vuTimeConstant));

    // Apply VU ballistics to RMS values
    vu_left_ = vu_left_ * (1.0f - alpha) + leftRMS * alpha;
    vu_right_ = vu_right_ * (1.0f - alpha) + rightRMS * alpha;

    // Peak detection with instant attack
    if (leftPeak > peak_left_) {
        peak_left_ = leftPeak;
    }
    if (rightPeak > peak_right_) {
        peak_right_ = rightPeak;
    }

    // Peak hold with decay
    if (leftPeak >= peak_hold_left_) {
        peak_hold_left_ = leftPeak;
        peak_hold_samples_left_ = 0;
    } else {
        peak_hold_samples_left_ += frameCount;
        if (peak_hold_samples_left_ > kPeakHoldTime) {
            // Decay peak hold slowly
            peak_hold_left_ *= 0.999f;
        }
    }

    if (rightPeak >= peak_hold_right_) {
        peak_hold_right_ = rightPeak;
        peak_hold_samples_right_ = 0;
    } else {
        peak_hold_samples_right_ += frameCount;
        if (peak_hold_samples_right_ > kPeakHoldTime) {
            peak_hold_right_ *= 0.999f;
        }
    }

    // Decay instantaneous peak for display (faster decay)
    peak_left_ *= 0.98f;
    peak_right_ *= 0.98f;
}

void AudioEngine::computeTruePeak(const float* audioData, int frameCount) {
    // True Peak measurement with 4x oversampling (ITU-R BS.1770-4)
    // Uses polyphase FIR filter for accurate inter-sample peak detection
    // 48-tap filter distributed across 4 phases (12 taps per phase)

    // Polyphase FIR filter coefficients (from ITU-R BS.1770-4 reference)
    // Phase 0: Original sample positions
    static const float phase0[12] = {
        0.0017089843750f, -0.0291748046875f, -0.0189208984375f, -0.0083007812500f,
        0.1538085937500f, 0.9721679687500f, 0.1538085937500f, -0.0083007812500f,
        -0.0189208984375f, -0.0291748046875f, 0.0017089843750f, 0.0f
    };
    // Phase 1: 1/4 sample interpolation
    static const float phase1[12] = {
        -0.0004272460938f, 0.0069580078125f, 0.0317382812500f, -0.0252685546875f,
        -0.1011962890625f, 0.8949584960938f, 0.4531250000000f, -0.0476074218750f,
        -0.0227050781250f, 0.0137939453125f, 0.0006103515625f, -0.0015869140625f
    };
    // Phase 2: 1/2 sample interpolation
    static const float phase2[12] = {
        0.0f, 0.0017089843750f, -0.0291748046875f, -0.0189208984375f,
        -0.0083007812500f, 0.5769042968750f, 0.5769042968750f, -0.0083007812500f,
        -0.0189208984375f, -0.0291748046875f, 0.0017089843750f, 0.0f
    };
    // Phase 3: 3/4 sample interpolation
    static const float phase3[12] = {
        -0.0015869140625f, 0.0006103515625f, 0.0137939453125f, -0.0227050781250f,
        -0.0476074218750f, 0.4531250000000f, 0.8949584960938f, -0.1011962890625f,
        -0.0252685546875f, 0.0317382812500f, 0.0069580078125f, -0.0004272460938f
    };

    float maxPeakLinear = 0.0f;

    // Simple delay line for filtering (12 samples needed)
    static std::vector<float> delayL(12, 0.0f);
    static std::vector<float> delayR(12, 0.0f);

    for (int i = 0; i < frameCount; ++i) {
        float left = audioData[i * 2];
        float right = audioData[i * 2 + 1];

        // Shift delay lines
        for (int j = 11; j > 0; --j) {
            delayL[j] = delayL[j-1];
            delayR[j] = delayR[j-1];
        }
        delayL[0] = left;
        delayR[0] = right;

        // Apply each phase filter and find max
        const float* phases[4] = {phase0, phase1, phase2, phase3};
        for (int p = 0; p < 4; ++p) {
            float interpL = 0.0f, interpR = 0.0f;
            for (int t = 0; t < 12; ++t) {
                interpL += delayL[t] * phases[p][t];
                interpR += delayR[t] * phases[p][t];
            }
            maxPeakLinear = std::max(maxPeakLinear, std::max(std::fabs(interpL), std::fabs(interpR)));
        }

        // Also check original samples
        maxPeakLinear = std::max(maxPeakLinear, std::max(std::fabs(left), std::fabs(right)));
    }

    // Convert to dBTP (dB True Peak)
    float newPeakDB;
    if (maxPeakLinear > 1e-10f) {
        newPeakDB = 20.0f * std::log10(maxPeakLinear);
    } else {
        newPeakDB = -100.0f;
    }

    // Peak hold with slow decay (1500ms hold, then 0.05dB/frame decay)
    static int peakHoldCounter = 0;
    static const int peakHoldFrames = 90;  // ~1500ms at 60fps

    if (newPeakDB >= true_peak_) {
        true_peak_ = newPeakDB;
        peakHoldCounter = 0;
    } else {
        peakHoldCounter++;
        if (peakHoldCounter > peakHoldFrames) {
            true_peak_ = std::max(true_peak_ - 0.05f, newPeakDB);
        }
    }

    // Clamp to reasonable range
    true_peak_ = std::max(-60.0f, std::min(6.0f, true_peak_));
}

} // namespace AudioPrime

// C API implementation
#include "AudioEngine.h"

struct AudioEngineImpl {
    AudioPrime::AudioEngine engine;
};

AudioEngineRef audio_engine_create(void) {
    return new AudioEngineImpl();
}

void audio_engine_destroy(AudioEngineRef engine) {
    delete engine;
}

void audio_engine_process(AudioEngineRef engine, const float* audioData, int32_t frameCount, int32_t channelCount) {
    if (engine) {
        engine->engine.process(audioData, frameCount, channelCount);
    }
}

void audio_engine_set_stereo_spectrum(AudioEngineRef engine, bool enabled) {
    if (engine) {
        engine->engine.setStereoSpectrum(enabled);
    }
}

bool audio_engine_get_stereo_spectrum(AudioEngineRef engine) {
    return engine ? engine->engine.getStereoSpectrum() : false;
}

void audio_engine_get_spectrum(AudioEngineRef engine, float* output, int32_t size) {
    if (engine) {
        engine->engine.getSpectrum(output, size);
    }
}

void audio_engine_get_spectrum_left(AudioEngineRef engine, float* output, int32_t size) {
    if (engine) {
        engine->engine.getSpectrumLeft(output, size);
    }
}

void audio_engine_get_spectrum_right(AudioEngineRef engine, float* output, int32_t size) {
    if (engine) {
        engine->engine.getSpectrumRight(output, size);
    }
}

float audio_engine_get_lufs_momentary(AudioEngineRef engine) {
    return engine ? engine->engine.getLUFSMomentary() : -23.0f;
}

float audio_engine_get_lufs_shortterm(AudioEngineRef engine) {
    return engine ? engine->engine.getLUFSShortTerm() : -23.0f;
}

float audio_engine_get_lufs_integrated(AudioEngineRef engine) {
    return engine ? engine->engine.getLUFSIntegrated() : -23.0f;
}

float audio_engine_get_true_peak(AudioEngineRef engine) {
    return engine ? engine->engine.getTruePeak() : 0.0f;
}

float audio_engine_get_bpm(AudioEngineRef engine) {
    return engine ? engine->engine.getBPM() : 0.0f;
}

float audio_engine_get_stereo_correlation(AudioEngineRef engine) {
    return engine ? engine->engine.getStereoCorrelation() : 1.0f;
}

float audio_engine_get_left_level(AudioEngineRef engine) {
    return engine ? engine->engine.getLeftLevel() : 0.0f;
}

float audio_engine_get_right_level(AudioEngineRef engine) {
    return engine ? engine->engine.getRightLevel() : 0.0f;
}

float audio_engine_get_mid_level(AudioEngineRef engine) {
    return engine ? engine->engine.getMidLevel() : 0.0f;
}

float audio_engine_get_side_level(AudioEngineRef engine) {
    return engine ? engine->engine.getSideLevel() : 0.0f;
}

void audio_engine_get_goniometer_points(AudioEngineRef engine, float* xOut, float* yOut, int32_t size) {
    if (engine) {
        engine->engine.getGoniometerPoints(xOut, yOut, size);
    }
}

int32_t audio_engine_get_goniometer_point_count(AudioEngineRef engine) {
    return engine ? engine->engine.getGoniometerPointCount() : 0;
}

float audio_engine_get_vu_left(AudioEngineRef engine) {
    return engine ? engine->engine.getVULeft() : 0.0f;
}

float audio_engine_get_vu_right(AudioEngineRef engine) {
    return engine ? engine->engine.getVURight() : 0.0f;
}

float audio_engine_get_peak_left(AudioEngineRef engine) {
    return engine ? engine->engine.getPeakLeft() : -100.0f;
}

float audio_engine_get_peak_right(AudioEngineRef engine) {
    return engine ? engine->engine.getPeakRight() : -100.0f;
}

float audio_engine_get_peak_hold_left(AudioEngineRef engine) {
    return engine ? engine->engine.getPeakHoldLeft() : -100.0f;
}

float audio_engine_get_peak_hold_right(AudioEngineRef engine) {
    return engine ? engine->engine.getPeakHoldRight() : -100.0f;
}

void audio_engine_set_sample_rate(AudioEngineRef engine, double sampleRate) {
    if (engine) {
        engine->engine.setSampleRate(sampleRate);
    }
}

void audio_engine_set_fft_size(AudioEngineRef engine, int32_t size) {
    if (engine) {
        engine->engine.setFFTSize(size);
    }
}

void audio_engine_set_smoothing(AudioEngineRef engine, float smoothing) {
    if (engine) {
        engine->engine.setSmoothing(smoothing);
    }
}

void audio_engine_set_multi_resolution_fft(AudioEngineRef engine, bool enabled) {
    if (engine) {
        engine->engine.setMultiResolutionFFT(enabled);
    }
}

void audio_engine_set_perceptual_weighting(AudioEngineRef engine, bool enabled) {
    if (engine) {
        engine->engine.setPerceptualWeighting(enabled);
    }
}

void audio_engine_get_bass_detail(AudioEngineRef engine, float* output, int32_t size) {
    if (engine) {
        engine->engine.getBassDetail(output, size);
    }
}

void audio_engine_set_bass_fft_size(AudioEngineRef engine, int32_t size) {
    if (engine) {
        engine->engine.setBassFFTSize(size);
    }
}

void audio_engine_set_bass_smoothing(AudioEngineRef engine, float smoothing) {
    if (engine) {
        engine->engine.setBassSmoothing(smoothing);
    }
}

int32_t audio_engine_get_bass_fft_size(AudioEngineRef engine) {
    return engine ? engine->engine.getBassFFTSize() : 4096;
}

float audio_engine_get_bass_smoothing(AudioEngineRef engine) {
    return engine ? engine->engine.getBassSmoothing() : 0.3f;
}

void audio_engine_get_waveform_left(AudioEngineRef engine, float* output, int32_t size) {
    if (engine) {
        engine->engine.getWaveformLeft(output, size);
    }
}

void audio_engine_get_waveform_right(AudioEngineRef engine, float* output, int32_t size) {
    if (engine) {
        engine->engine.getWaveformRight(output, size);
    }
}

int32_t audio_engine_get_waveform_size(AudioEngineRef engine) {
    return engine ? engine->engine.getWaveformSize() : 1024;
}
