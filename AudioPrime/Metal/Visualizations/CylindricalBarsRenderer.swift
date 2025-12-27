//
//  CylindricalBarsRenderer.swift
//  AudioPrime
//
//  Cylindrical bars visualization renderer
//  512 bars arranged in a cylinder, heights driven by spectrum
//

import MetalKit
import simd

class CylindricalBarsRenderer: VisualizationRenderer {
    let name = "Cylindrical Bars"

    // Metal objects
    private var device: MTLDevice?
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    private var normalBuffer: MTLBuffer?
    private var spectrumBuffer: MTLBuffer?

    // Geometry
    private let verticesPerBar = 36  // 6 faces * 2 triangles * 3 vertices

    // Dynamic bar count
    var barCount: Int = 128 {
        didSet {
            if barCount != oldValue {
                resizeBuffers()
            }
        }
    }

    // Audio data
    private var spectrumData: [Float] = Array(repeating: 0, count: 512)  // Max size buffer

    // MARK: - Setup

    func setup(device: MTLDevice, library: MTLLibrary) throws {
        self.device = device

        // Create pipeline
        try createPipeline(device: device, library: library)

        // Create geometry buffers
        createGeometry(device: device)

        // Create spectrum buffer (max size to avoid reallocating)
        spectrumBuffer = device.makeBuffer(length: MemoryLayout<Float>.stride * 512,
                                           options: .storageModeShared)
    }

    private func resizeBuffers() {
        // Buffer is already max size, no need to resize
        // Just clear the spectrum data
        spectrumData = Array(repeating: 0, count: 512)
    }

    private func createPipeline(device: MTLDevice, library: MTLLibrary) throws {
        guard let vertexFunction = library.makeFunction(name: "cylindricalBars_vertex"),
              let fragmentFunction = library.makeFunction(name: "cylindricalBars_fragment") else {
            throw NSError(domain: "CylindricalBarsRenderer", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to find shader functions"])
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        // Enable blending for glow effects
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    private func createGeometry(device: MTLDevice) {
        // Create a unit cube (will be scaled per-instance in shader)
        // Cube vertices centered at origin, size 2x2x2
        let vertices: [simd_float3] = [
            // Front face
            simd_float3(-1, -1,  1), simd_float3( 1, -1,  1), simd_float3( 1,  1,  1),
            simd_float3(-1, -1,  1), simd_float3( 1,  1,  1), simd_float3(-1,  1,  1),
            // Back face
            simd_float3( 1, -1, -1), simd_float3(-1, -1, -1), simd_float3(-1,  1, -1),
            simd_float3( 1, -1, -1), simd_float3(-1,  1, -1), simd_float3( 1,  1, -1),
            // Top face
            simd_float3(-1,  1,  1), simd_float3( 1,  1,  1), simd_float3( 1,  1, -1),
            simd_float3(-1,  1,  1), simd_float3( 1,  1, -1), simd_float3(-1,  1, -1),
            // Bottom face
            simd_float3(-1, -1, -1), simd_float3( 1, -1, -1), simd_float3( 1, -1,  1),
            simd_float3(-1, -1, -1), simd_float3( 1, -1,  1), simd_float3(-1, -1,  1),
            // Right face
            simd_float3( 1, -1,  1), simd_float3( 1, -1, -1), simd_float3( 1,  1, -1),
            simd_float3( 1, -1,  1), simd_float3( 1,  1, -1), simd_float3( 1,  1,  1),
            // Left face
            simd_float3(-1, -1, -1), simd_float3(-1, -1,  1), simd_float3(-1,  1,  1),
            simd_float3(-1, -1, -1), simd_float3(-1,  1,  1), simd_float3(-1,  1, -1)
        ]

        let normals: [simd_float3] = [
            // Front face
            simd_float3(0, 0, 1), simd_float3(0, 0, 1), simd_float3(0, 0, 1),
            simd_float3(0, 0, 1), simd_float3(0, 0, 1), simd_float3(0, 0, 1),
            // Back face
            simd_float3(0, 0, -1), simd_float3(0, 0, -1), simd_float3(0, 0, -1),
            simd_float3(0, 0, -1), simd_float3(0, 0, -1), simd_float3(0, 0, -1),
            // Top face
            simd_float3(0, 1, 0), simd_float3(0, 1, 0), simd_float3(0, 1, 0),
            simd_float3(0, 1, 0), simd_float3(0, 1, 0), simd_float3(0, 1, 0),
            // Bottom face
            simd_float3(0, -1, 0), simd_float3(0, -1, 0), simd_float3(0, -1, 0),
            simd_float3(0, -1, 0), simd_float3(0, -1, 0), simd_float3(0, -1, 0),
            // Right face
            simd_float3(1, 0, 0), simd_float3(1, 0, 0), simd_float3(1, 0, 0),
            simd_float3(1, 0, 0), simd_float3(1, 0, 0), simd_float3(1, 0, 0),
            // Left face
            simd_float3(-1, 0, 0), simd_float3(-1, 0, 0), simd_float3(-1, 0, 0),
            simd_float3(-1, 0, 0), simd_float3(-1, 0, 0), simd_float3(-1, 0, 0)
        ]

        vertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: MemoryLayout<simd_float3>.stride * vertices.count,
                                         options: .storageModeShared)

        normalBuffer = device.makeBuffer(bytes: normals,
                                         length: MemoryLayout<simd_float3>.stride * normals.count,
                                         options: .storageModeShared)
    }

    // MARK: - Audio Data Update

    func updateAudioData(spectrum: [Float], waveformL: [Float], waveformR: [Float]) {
        // Downsample 512-bin spectrum to current bar count
        let binsPerBar = 512 / barCount
        for i in 0..<barCount {
            let idx = i * binsPerBar
            var sum: Float = 0
            var count: Float = 0
            for j in 0..<binsPerBar {
                if idx + j < spectrum.count {
                    sum += spectrum[idx + j]
                    count += 1
                }
            }
            spectrumData[i] = count > 0 ? sum / count : 0
        }

        // Update buffer
        if let buffer = spectrumBuffer {
            memcpy(buffer.contents(), &spectrumData, MemoryLayout<Float>.stride * barCount)
        }
    }

    // MARK: - Draw

    func draw(encoder: MTLRenderCommandEncoder, uniforms: inout Uniforms) {
        guard let pipelineState = pipelineState,
              let vertexBuffer = vertexBuffer,
              let normalBuffer = normalBuffer,
              let spectrumBuffer = spectrumBuffer else {
            return
        }

        encoder.setRenderPipelineState(pipelineState)

        // Set bar count in uniforms
        uniforms.barCount = Int32(barCount)

        // Set buffers
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setVertexBuffer(spectrumBuffer, offset: 0, index: 1)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 2)
        encoder.setVertexBuffer(normalBuffer, offset: 0, index: 3)

        // Draw instanced - dynamic bar count
        encoder.drawPrimitives(type: .triangle,
                               vertexStart: 0,
                               vertexCount: verticesPerBar,
                               instanceCount: barCount)
    }
}
