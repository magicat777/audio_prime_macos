//
//  CylindricalBars.metal
//  AudioPrime
//
//  Cylindrical bars visualization - 512 bars arranged in a cylinder
//  Each bar height driven by spectrum data, with beat reactivity
//

#include <metal_stdlib>
using namespace metal;

// Include common definitions
#include "Common.metal"

// MARK: - Vertex Shader

vertex VertexOut cylindricalBars_vertex(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant Uniforms &uniforms [[buffer(0)]],
    constant float *spectrum [[buffer(1)]],
    constant float3 *vertices [[buffer(2)]],
    constant float3 *normals [[buffer(3)]]
) {
    VertexOut out;

    // Get spectrum value for this bar (512 bars total)
    float audioValue = spectrum[instanceID];

    // Calculate bar position on cylinder
    float numBars = 512.0;
    float angle = float(instanceID) / numBars * 2.0 * M_PI_F;
    float radius = 3.0;

    // Bar dimensions
    float barWidth = 2.0 * M_PI_F * radius / numBars * 0.8;  // 80% width for gaps
    float barDepth = 0.1;
    float barHeight = 0.1 + audioValue * 4.0;  // Scale height by audio

    // Beat reactivity - pulse all bars outward
    float beatPulse = 1.0 + uniforms.beatStrength * 0.2;
    radius *= beatPulse;
    barHeight *= beatPulse;

    // Get base vertex position (unit cube centered at origin)
    float3 localPos = vertices[vertexID];

    // Scale to bar dimensions
    localPos.x *= barWidth * 0.5;
    localPos.y *= barHeight;
    localPos.z *= barDepth * 0.5;

    // Position at bottom of bar (y=0 to y=height)
    localPos.y += barHeight * 0.5;

    // Rotate around Y axis to position on cylinder
    float cosA = cos(angle);
    float sinA = sin(angle);

    float3 rotatedPos;
    rotatedPos.x = localPos.x * cosA - localPos.z * sinA;
    rotatedPos.y = localPos.y;
    rotatedPos.z = localPos.x * sinA + localPos.z * cosA;

    // Translate to cylinder radius
    rotatedPos.x += radius * sinA;
    rotatedPos.z += radius * cosA;

    // Move cylinder down so it's centered
    rotatedPos.y -= 2.0;

    // Transform to world space
    float4 worldPos = uniforms.modelMatrix * float4(rotatedPos, 1.0);
    out.worldPosition = worldPos.xyz;

    // Transform normal
    float3 localNormal = normals[vertexID];
    float3 rotatedNormal;
    rotatedNormal.x = localNormal.x * cosA - localNormal.z * sinA;
    rotatedNormal.y = localNormal.y;
    rotatedNormal.z = localNormal.x * sinA + localNormal.z * cosA;
    out.normal = normalize((uniforms.modelMatrix * float4(rotatedNormal, 0.0)).xyz);

    // Final position
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;

    // Color based on frequency position (rainbow spectrum)
    float t = float(instanceID) / numBars;
    float3 baseColor = spectrumColor(t);

    // Intensity based on audio value
    float intensity = 0.3 + audioValue * 0.7;
    out.color = float4(baseColor * intensity, 1.0);

    // Add glow effect for loud bars
    if (audioValue > 0.6) {
        out.color.rgb += float3(1.0, 1.0, 1.0) * (audioValue - 0.6) * 0.5;
    }

    out.audioValue = audioValue;
    out.texcoord = float2(t, audioValue);

    return out;
}

// MARK: - Fragment Shader

fragment float4 cylindricalBars_fragment(VertexOut in [[stage_in]]) {
    // Simple lit shading
    float3 lightDir = normalize(float3(0.5, 1.0, 0.3));
    float diffuse = max(dot(in.normal, lightDir), 0.0) * 0.5 + 0.5;

    float3 finalColor = in.color.rgb * diffuse;

    // Add subtle ambient
    finalColor += in.color.rgb * 0.1;

    // Slight glow at top of tall bars
    if (in.audioValue > 0.7 && in.texcoord.y > 0.8) {
        finalColor += float3(1.0, 1.0, 1.0) * 0.2;
    }

    return float4(finalColor, 1.0);
}
