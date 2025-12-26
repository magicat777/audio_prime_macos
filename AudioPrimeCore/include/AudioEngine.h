//
//  AudioEngine.h
//  AudioPrimeCore
//
//  C-compatible header for Swift/C++ bridging
//  Core audio processing engine
//

#ifndef AudioEngine_h
#define AudioEngine_h

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer to C++ AudioEngine instance
typedef struct AudioEngineImpl* AudioEngineRef;

// Create/destroy engine
AudioEngineRef audio_engine_create(void);
void audio_engine_destroy(AudioEngineRef engine);

// Audio processing
void audio_engine_process(AudioEngineRef engine, const float* audioData, int32_t frameCount, int32_t channelCount);

// Stereo spectrum mode
void audio_engine_set_stereo_spectrum(AudioEngineRef engine, bool enabled);
bool audio_engine_get_stereo_spectrum(AudioEngineRef engine);

// Get analysis results
void audio_engine_get_spectrum(AudioEngineRef engine, float* output, int32_t size);
void audio_engine_get_spectrum_left(AudioEngineRef engine, float* output, int32_t size);
void audio_engine_get_spectrum_right(AudioEngineRef engine, float* output, int32_t size);
float audio_engine_get_lufs_momentary(AudioEngineRef engine);
float audio_engine_get_lufs_shortterm(AudioEngineRef engine);
float audio_engine_get_lufs_integrated(AudioEngineRef engine);
float audio_engine_get_true_peak(AudioEngineRef engine);
float audio_engine_get_bpm(AudioEngineRef engine);

// Stereo analysis
float audio_engine_get_stereo_correlation(AudioEngineRef engine);
float audio_engine_get_left_level(AudioEngineRef engine);
float audio_engine_get_right_level(AudioEngineRef engine);
float audio_engine_get_mid_level(AudioEngineRef engine);
float audio_engine_get_side_level(AudioEngineRef engine);
void audio_engine_get_goniometer_points(AudioEngineRef engine, float* xOut, float* yOut, int32_t size);
int32_t audio_engine_get_goniometer_point_count(AudioEngineRef engine);

// VU Metering
float audio_engine_get_vu_left(AudioEngineRef engine);
float audio_engine_get_vu_right(AudioEngineRef engine);
float audio_engine_get_peak_left(AudioEngineRef engine);
float audio_engine_get_peak_right(AudioEngineRef engine);
float audio_engine_get_peak_hold_left(AudioEngineRef engine);
float audio_engine_get_peak_hold_right(AudioEngineRef engine);

// Configuration
void audio_engine_set_sample_rate(AudioEngineRef engine, double sampleRate);
void audio_engine_set_fft_size(AudioEngineRef engine, int32_t size);
void audio_engine_set_smoothing(AudioEngineRef engine, float smoothing);
void audio_engine_set_multi_resolution_fft(AudioEngineRef engine, bool enabled);
void audio_engine_set_perceptual_weighting(AudioEngineRef engine, bool enabled);

// Bass detail (20-200Hz zoomed view with dedicated high-resolution FFT)
void audio_engine_get_bass_detail(AudioEngineRef engine, float* output, int32_t size);
void audio_engine_set_bass_fft_size(AudioEngineRef engine, int32_t size);
void audio_engine_set_bass_smoothing(AudioEngineRef engine, float smoothing);
int32_t audio_engine_get_bass_fft_size(AudioEngineRef engine);
float audio_engine_get_bass_smoothing(AudioEngineRef engine);

// Oscilloscope waveform (time-domain display)
void audio_engine_get_waveform_left(AudioEngineRef engine, float* output, int32_t size);
void audio_engine_get_waveform_right(AudioEngineRef engine, float* output, int32_t size);
int32_t audio_engine_get_waveform_size(AudioEngineRef engine);

#ifdef __cplusplus
}
#endif

#endif /* AudioEngine_h */
