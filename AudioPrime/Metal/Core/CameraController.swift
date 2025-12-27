//
//  CameraController.swift
//  AudioPrime
//
//  Orbit camera controller with auto-rotate and manual control
//  Supports mouse drag, scroll wheel, and trackpad gestures
//

import simd
import Foundation

class CameraController {
    // Camera position (spherical coordinates)
    var distance: Float = 12.0     // Further back to see full cylinder
    var azimuth: Float = 0.0       // Horizontal rotation (radians)
    var elevation: Float = 0.4     // Slightly higher angle for better view

    // Auto-rotate settings
    var autoRotate: Bool = true
    var autoRotateSpeed: Float = 0.15  // Radians per second

    // Projection settings
    var fov: Float = 60.0         // Field of view in degrees
    var nearPlane: Float = 0.1
    var farPlane: Float = 100.0
    var aspectRatio: Float = 1.0

    // Target (look-at point)
    var target: simd_float3 = simd_float3(0, 0, 0)

    // Limits
    let minDistance: Float = 2.0
    let maxDistance: Float = 30.0
    let minElevation: Float = -Float.pi / 2.2  // Just above -90 degrees
    let maxElevation: Float = Float.pi / 2.2   // Just below 90 degrees

    // Sensitivity
    let rotateSensitivity: Float = 0.005
    let zoomSensitivity: Float = 0.1

    // Matrices
    private(set) var viewMatrix: simd_float4x4 = matrix_identity_float4x4
    private(set) var projectionMatrix: simd_float4x4 = matrix_identity_float4x4

    // Timing for auto-rotate
    private var lastUpdateTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

    init() {
        updateMatrices()
    }

    // MARK: - Update

    func update() {
        let now = CFAbsoluteTimeGetCurrent()
        let deltaTime = Float(now - lastUpdateTime)
        lastUpdateTime = now

        // Auto-rotate if enabled
        if autoRotate {
            azimuth += autoRotateSpeed * deltaTime
            if azimuth > Float.pi * 2 {
                azimuth -= Float.pi * 2
            }
        }

        updateMatrices()
    }

    func updateProjection(aspectRatio: Float) {
        self.aspectRatio = aspectRatio
        updateMatrices()
    }

    private func updateMatrices() {
        // Calculate camera position from spherical coordinates
        let cosElevation = cos(elevation)
        let sinElevation = sin(elevation)
        let cosAzimuth = cos(azimuth)
        let sinAzimuth = sin(azimuth)

        let cameraPosition = simd_float3(
            target.x + distance * cosElevation * sinAzimuth,
            target.y + distance * sinElevation,
            target.z + distance * cosElevation * cosAzimuth
        )

        // Create view matrix (look-at)
        viewMatrix = lookAt(eye: cameraPosition, center: target, up: simd_float3(0, 1, 0))

        // Create projection matrix
        let fovRadians = fov * Float.pi / 180.0
        projectionMatrix = perspective(fovyRadians: fovRadians, aspectRatio: aspectRatio,
                                       nearZ: nearPlane, farZ: farPlane)
    }

    // MARK: - Input Handling

    func handleMouseDragged(deltaX: CGFloat, deltaY: CGFloat) {
        // Temporarily disable auto-rotate during manual control
        // (it will resume on next frame if still enabled)

        azimuth -= Float(deltaX) * rotateSensitivity
        elevation += Float(deltaY) * rotateSensitivity

        // Clamp elevation to prevent gimbal lock
        elevation = max(minElevation, min(maxElevation, elevation))

        updateMatrices()
    }

    func handleScrollWheel(deltaY: CGFloat) {
        distance -= Float(deltaY) * zoomSensitivity
        distance = max(minDistance, min(maxDistance, distance))
        updateMatrices()
    }

    func handleMagnify(magnification: CGFloat) {
        distance -= Float(magnification) * distance * 0.5
        distance = max(minDistance, min(maxDistance, distance))
        updateMatrices()
    }

    // MARK: - Matrix Helpers

    private func lookAt(eye: simd_float3, center: simd_float3, up: simd_float3) -> simd_float4x4 {
        let z = normalize(eye - center)
        let x = normalize(cross(up, z))
        let y = cross(z, x)

        return simd_float4x4(columns: (
            simd_float4(x.x, y.x, z.x, 0),
            simd_float4(x.y, y.y, z.y, 0),
            simd_float4(x.z, y.z, z.z, 0),
            simd_float4(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
        ))
    }

    private func perspective(fovyRadians: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> simd_float4x4 {
        let ys = 1 / tan(fovyRadians * 0.5)
        let xs = ys / aspectRatio
        let zs = farZ / (nearZ - farZ)

        return simd_float4x4(columns: (
            simd_float4(xs, 0, 0, 0),
            simd_float4(0, ys, 0, 0),
            simd_float4(0, 0, zs, -1),
            simd_float4(0, 0, zs * nearZ, 0)
        ))
    }
}
