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
    , fft_setup_(nullptr)
    , log2n_(0)
    , lufs_momentary_(-23.0f)
    , lufs_shortterm_(-23.0f)
    , lufs_integrated_(-23.0f)
    , true_peak_(0.0f)
    , bpm_(0.0f)
{
    spectrum_data_.resize(512, 0.0f);
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
    spectrum_data_.resize(fft_size_, 0.0f);
    initializeFFT();
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
    if (!audioData || frameCount < fft_size_) return;

    // For stereo, mix to mono for FFT (we'll do stereo analysis separately later)
    std::vector<float> monoBuffer(fft_size_);

    if (channelCount == 2) {
        // Mix stereo to mono
        for (int i = 0; i < fft_size_; ++i) {
            monoBuffer[i] = (audioData[i * 2] + audioData[i * 2 + 1]) * 0.5f;
        }
    } else {
        // Copy mono
        std::copy(audioData, audioData + fft_size_, monoBuffer.begin());
    }

    performFFT(monoBuffer.data(), fft_size_);

    // TODO: Implement LUFS, beat detection, etc.
    // For now, just placeholder values
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
    // Simple linear mapping for now, will implement proper log mapping later
    int outputSize = std::min(512, static_cast<int>(magnitudes.size()));
    std::copy(magnitudes.begin(), magnitudes.begin() + outputSize, spectrum_data_.begin());

    // Normalize to 0-1 range
    for (auto& val : spectrum_data_) {
        val = (val + 80.0f) / 80.0f; // Map -80dB to 0dB → 0 to 1
    }
}

void AudioEngine::getSpectrum(float* output, int size) {
    int copySize = std::min(size, static_cast<int>(spectrum_data_.size()));
    std::copy(spectrum_data_.begin(), spectrum_data_.begin() + copySize, output);
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
