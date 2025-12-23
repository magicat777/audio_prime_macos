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

    // Audio processing
    void process(const float* audioData, int frameCount, int channelCount);

    // Get analysis results
    void getSpectrum(float* output, int size);
    float getLUFSMomentary() const { return lufs_momentary_; }
    float getLUFSShortTerm() const { return lufs_shortterm_; }
    float getLUFSIntegrated() const { return lufs_integrated_; }
    float getTruePeak() const { return true_peak_; }
    float getBPM() const { return bpm_; }

private:
    // Configuration
    double sample_rate_;
    int fft_size_;

    // FFT setup
    FFTSetup fft_setup_;
    int log2n_;
    DSPSplitComplex split_complex_;

    // Analysis results
    std::vector<float> spectrum_data_;
    float lufs_momentary_;
    float lufs_shortterm_;
    float lufs_integrated_;
    float true_peak_;
    float bpm_;

    // Internal methods
    void initializeFFT();
    void cleanupFFT();
    void performFFT(const float* input, int inputSize);
};

} // namespace AudioPrime

#endif /* AudioEngine_hpp */
