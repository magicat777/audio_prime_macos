//
//  ShaderTypes.h
//  AudioPrime
//
//  Shared types between Swift and Metal shaders
//  Used for uniforms, vertices, and audio data
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Buffer indices for vertex function
typedef enum {
    BufferIndexVertices = 0,
    BufferIndexUniforms = 1,
    BufferIndexAudioData = 2,
    BufferIndexInstanceData = 3
} BufferIndex;

// Vertex attribute indices
typedef enum {
    VertexAttributePosition = 0,
    VertexAttributeNormal = 1,
    VertexAttributeTexcoord = 2
} VertexAttribute;

// Uniform data passed to shaders each frame
typedef struct {
    simd_float4x4 projectionMatrix;
    simd_float4x4 viewMatrix;
    simd_float4x4 modelMatrix;
    float time;
    float beatPhase;
    float beatStrength;
    int beatDetected;
    float bpm;
    simd_float2 resolution;
} Uniforms;

// Vertex structure for 3D geometry
typedef struct {
    simd_float3 position;
    simd_float3 normal;
    simd_float2 texcoord;
} Vertex;

// Per-instance data for instanced rendering
typedef struct {
    simd_float4x4 modelMatrix;
    simd_float4 color;
    float audioValue;
    float instanceIndex;
    simd_float2 padding;
} InstanceData;

// Audio data buffer (spectrum + waveform)
// Note: Metal doesn't support variable-length arrays in structs
// We pass spectrum as a separate buffer
#define SPECTRUM_SIZE 512
#define WAVEFORM_SIZE 1024

#endif /* ShaderTypes_h */
