//
//  Common.metal
//  AudioPrime
//
//  Shared shader functions for all visualizations
//  Includes color palettes, noise functions, and utilities
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Shared Types (must match Swift definitions)

struct Uniforms {
    float4x4 projectionMatrix;
    float4x4 viewMatrix;
    float4x4 modelMatrix;
    float time;
    float beatPhase;
    float beatStrength;
    int beatDetected;
    float bpm;
    float2 resolution;
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
    float2 texcoord;
    float4 color;
    float audioValue;
};

// MARK: - Color Palettes

// OMEGA color palette - rainbow spectrum for frequency visualization
// purple -> red -> orange -> yellow -> green -> cyan -> blue
float3 spectrumColor(float t) {
    t = clamp(t, 0.0, 1.0);

    // 6-band color palette
    if (t < 0.167) {
        // Purple to red
        float s = t / 0.167;
        return mix(float3(0.6, 0.0, 0.8), float3(1.0, 0.0, 0.3), s);
    } else if (t < 0.333) {
        // Red to orange
        float s = (t - 0.167) / 0.166;
        return mix(float3(1.0, 0.0, 0.3), float3(1.0, 0.5, 0.0), s);
    } else if (t < 0.5) {
        // Orange to yellow
        float s = (t - 0.333) / 0.167;
        return mix(float3(1.0, 0.5, 0.0), float3(1.0, 1.0, 0.0), s);
    } else if (t < 0.667) {
        // Yellow to green
        float s = (t - 0.5) / 0.167;
        return mix(float3(1.0, 1.0, 0.0), float3(0.0, 1.0, 0.3), s);
    } else if (t < 0.833) {
        // Green to cyan
        float s = (t - 0.667) / 0.166;
        return mix(float3(0.0, 1.0, 0.3), float3(0.0, 1.0, 1.0), s);
    } else {
        // Cyan to blue
        float s = (t - 0.833) / 0.167;
        return mix(float3(0.0, 1.0, 1.0), float3(0.3, 0.5, 1.0), s);
    }
}

// Heat color palette - for intensity visualization
float3 heatColor(float t) {
    t = clamp(t, 0.0, 1.0);

    if (t < 0.25) {
        return mix(float3(0.0, 0.0, 0.0), float3(0.0, 0.0, 1.0), t * 4.0);
    } else if (t < 0.5) {
        return mix(float3(0.0, 0.0, 1.0), float3(1.0, 0.0, 0.5), (t - 0.25) * 4.0);
    } else if (t < 0.75) {
        return mix(float3(1.0, 0.0, 0.5), float3(1.0, 1.0, 0.0), (t - 0.5) * 4.0);
    } else {
        return mix(float3(1.0, 1.0, 0.0), float3(1.0, 1.0, 1.0), (t - 0.75) * 4.0);
    }
}

// MARK: - Utility Functions

// Beat pulse effect - returns scale multiplier
float beatPulse(float beatStrength, float intensity) {
    return 1.0 + beatStrength * intensity;
}

// Fresnel edge glow
float fresnel(float3 normal, float3 viewDir, float power) {
    return pow(1.0 - max(dot(normal, viewDir), 0.0), power);
}

// Simple fog
float fog(float distance, float density) {
    return 1.0 - exp(-distance * density);
}

// Glow boost for bright areas
float glow(float value, float threshold, float intensity) {
    return value > threshold ? (value - threshold) * intensity : 0.0;
}

// MARK: - Noise Functions

// Simple hash function
float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

// 2D noise
float noise2D(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// MARK: - Matrix Helpers

float4x4 rotationY(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float4x4(
        float4(c, 0, s, 0),
        float4(0, 1, 0, 0),
        float4(-s, 0, c, 0),
        float4(0, 0, 0, 1)
    );
}

float4x4 rotationX(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float4x4(
        float4(1, 0, 0, 0),
        float4(0, c, -s, 0),
        float4(0, s, c, 0),
        float4(0, 0, 0, 1)
    );
}

float4x4 translation(float3 t) {
    return float4x4(
        float4(1, 0, 0, 0),
        float4(0, 1, 0, 0),
        float4(0, 0, 1, 0),
        float4(t.x, t.y, t.z, 1)
    );
}

float4x4 scale(float3 s) {
    return float4x4(
        float4(s.x, 0, 0, 0),
        float4(0, s.y, 0, 0),
        float4(0, 0, s.z, 0),
        float4(0, 0, 0, 1)
    );
}
