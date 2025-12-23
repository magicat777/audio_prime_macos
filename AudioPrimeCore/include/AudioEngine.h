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

// Get analysis results
void audio_engine_get_spectrum(AudioEngineRef engine, float* output, int32_t size);
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

// Configuration
void audio_engine_set_sample_rate(AudioEngineRef engine, double sampleRate);
void audio_engine_set_fft_size(AudioEngineRef engine, int32_t size);
void audio_engine_set_smoothing(AudioEngineRef engine, float smoothing);

#ifdef __cplusplus
}
#endif

#endif /* AudioEngine_h */
