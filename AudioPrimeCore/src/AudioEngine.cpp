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
    , fft_setup_(nullptr)
    , log2n_(0)
    , buffer_write_pos_(0)
    , lufs_momentary_(-23.0f)
    , lufs_shortterm_(-23.0f)
    , lufs_integrated_(-23.0f)
    , true_peak_(0.0f)
    , bpm_(0.0f)
    , stereo_correlation_(1.0f)
    , left_level_(0.0f)
    , right_level_(0.0f)
    , mid_level_(0.0f)
    , side_level_(0.0f)
{
    spectrum_data_.resize(512, 0.0f);
    prev_spectrum_.resize(512, 0.0f);
    audio_buffer_.resize(fft_size_, 0.0f);
    goniometer_x_.resize(kGoniometerPoints, 0.0f);
    goniometer_y_.resize(kGoniometerPoints, 0.0f);
    initializeFFT();
}

AudioEngine::~AudioEngine() {
    cleanupFFT();
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
    buffer_write_pos_ = 0;
    initializeFFT();
}

void AudioEngine::setSmoothing(float smoothing) {
    smoothing_ = std::max(0.0f, std::min(1.0f, smoothing));
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

void AudioEngine::process(const float* audioData, int frameCount, int channelCount) {
    if (!audioData || frameCount <= 0) return;

    // Process stereo analysis on the raw interleaved data
    if (channelCount == 2) {
        processStereoAnalysis(audioData, frameCount);
    }

    // Mix stereo to mono and accumulate into ring buffer
    for (int i = 0; i < frameCount; ++i) {
        float sample;
        if (channelCount == 2) {
            sample = (audioData[i * 2] + audioData[i * 2 + 1]) * 0.5f;
        } else {
            sample = audioData[i];
        }

        audio_buffer_[buffer_write_pos_] = sample;
        buffer_write_pos_++;

        // When buffer is full, perform FFT
        if (buffer_write_pos_ >= static_cast<size_t>(fft_size_)) {
            performFFT(audio_buffer_.data(), fft_size_);

            // Use 50% overlap for smoother updates (keep second half)
            size_t overlap = fft_size_ / 2;
            std::copy(audio_buffer_.begin() + overlap, audio_buffer_.end(), audio_buffer_.begin());
            buffer_write_pos_ = overlap;
        }
    }

    // TODO: Implement LUFS, beat detection, etc.
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

        // Apply smoothing (exponential moving average)
        // smoothing_ = 0 means no smoothing (instant response)
        // smoothing_ = 1 means maximum smoothing (very slow decay)
        float alpha = 1.0f - (smoothing_ * 0.95f);  // Map 0-1 to 1-0.05
        spectrum_data_[i] = alpha * normalized + (1.0f - alpha) * prev_spectrum_[i];
    }

    // Store current spectrum for next frame's smoothing
    prev_spectrum_ = spectrum_data_;
}

void AudioEngine::getSpectrum(float* output, int size) {
    int copySize = std::min(size, static_cast<int>(spectrum_data_.size()));
    std::copy(spectrum_data_.begin(), spectrum_data_.begin() + copySize, output);
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

void audio_engine_get_spectrum(AudioEngineRef engine, float* output, int32_t size) {
    if (engine) {
        engine->engine.getSpectrum(output, size);
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
