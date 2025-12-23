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

    // Audio processing
    void process(const float* audioData, int frameCount, int channelCount);

    // Get analysis results
    void getSpectrum(float* output, int size);
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

private:
    // Configuration
    double sample_rate_;
    int fft_size_;
    float smoothing_;  // 0.0 = no smoothing, 1.0 = maximum smoothing

    // FFT setup
    FFTSetup fft_setup_;
    int log2n_;
    DSPSplitComplex split_complex_;

    // Audio buffer for accumulating samples
    std::vector<float> audio_buffer_;
    size_t buffer_write_pos_;

    // Analysis results
    std::vector<float> spectrum_data_;
    std::vector<float> prev_spectrum_;  // For smoothing
    float lufs_momentary_;
    float lufs_shortterm_;
    float lufs_integrated_;
    float true_peak_;
    float bpm_;

    // Stereo analysis results
    float stereo_correlation_;
    float left_level_;
    float right_level_;
    float mid_level_;
    float side_level_;
    std::vector<float> goniometer_x_;
    std::vector<float> goniometer_y_;
    static constexpr int kGoniometerPoints = 512;  // Points for Lissajous display

    // Internal methods
    void initializeFFT();
    void cleanupFFT();
    void performFFT(const float* input, int inputSize);
    void processStereoAnalysis(const float* audioData, int frameCount);
};

} // namespace AudioPrime

#endif /* AudioEngine_hpp */
