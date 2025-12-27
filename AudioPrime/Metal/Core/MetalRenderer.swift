//
//  MetalRenderer.swift
//  AudioPrime
//
//  Core Metal rendering coordinator
//  Manages device, command queue, and render pipelines
//

import MetalKit
import simd

// MARK: - Shader Types (mirrored from ShaderTypes.h for Swift)

struct Uniforms {
    var projectionMatrix: simd_float4x4
    var viewMatrix: simd_float4x4
    var modelMatrix: simd_float4x4
    var time: Float
    var beatPhase: Float
    var beatStrength: Float
    var beatDetected: Int32
    var bpm: Float
    var resolution: simd_float2
    var barCount: Int32
    var padding: Int32 = 0  // Keep 16-byte alignment
}

struct Vertex {
    var position: simd_float3
    var normal: simd_float3
    var texcoord: simd_float2
}

struct InstanceData {
    var modelMatrix: simd_float4x4
    var color: simd_float4
    var audioValue: Float
    var instanceIndex: Float
    var padding: simd_float2
}

// MARK: - Visualization Protocol

protocol VisualizationRenderer {
    var name: String { get }
    var barCount: Int { get set }
    func setup(device: MTLDevice, library: MTLLibrary) throws
    func updateAudioData(spectrum: [Float], waveformL: [Float], waveformR: [Float])
    func draw(encoder: MTLRenderCommandEncoder, uniforms: inout Uniforms)
}

// MARK: - Metal Renderer

@MainActor
class MetalRenderer: NSObject, MTKViewDelegate, ObservableObject {
    // Metal objects
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var library: MTLLibrary?

    // Current visualization
    private var currentVisualization: VisualizationRenderer?
    @Published var visualizationName: String = "None"

    // Camera
    let camera = CameraController()

    // Timing
    private var startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

    // Audio data source
    private weak var audioViewModel: AudioViewModel?

    // Depth state
    private var depthStencilState: MTLDepthStencilState?

    // MARK: - Initialization

    init?(mtkView: MTKView, viewModel: AudioViewModel) {
        self.audioViewModel = viewModel
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return nil
        }

        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            print("Failed to create command queue")
            return nil
        }
        self.commandQueue = commandQueue

        super.init()

        // Configure the view
        mtkView.device = device
        mtkView.delegate = self
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.clearColor = MTLClearColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1.0)
        mtkView.preferredFramesPerSecond = 60
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false

        // Create depth stencil state
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthDescriptor)

        // Load shader library
        loadShaderLibrary()

        // Set up default visualization
        setupCylindricalBars()
    }

    // MARK: - Shader Library

    private func loadShaderLibrary() {
        // Try to load from default library first
        if let defaultLibrary = device.makeDefaultLibrary() {
            self.library = defaultLibrary
            print("Loaded Metal shader library from default")
            return
        }

        // For Swift Package Manager, compile shaders from source at runtime
        do {
            let shaderSource = try loadShaderSource()
            self.library = try device.makeLibrary(source: shaderSource, options: nil)
            print("Compiled Metal shader library from source")
        } catch {
            print("Failed to compile Metal shaders: \(error)")
        }
    }

    private func loadShaderSource() throws -> String {
        // Combine Common.metal and CylindricalBars.metal source
        let combinedSource = """
        #include <metal_stdlib>
        using namespace metal;

        // MARK: - Shared Types

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
            int barCount;
            int padding;
        };

        struct VertexOut {
            float4 position [[position]];
            float3 worldPosition;
            float3 normal;
            float2 texcoord;
            float4 color;
            float audioValue;
        };

        // MARK: - Color Functions

        float3 spectrumColor(float t) {
            t = clamp(t, 0.0, 1.0);
            if (t < 0.167) {
                float s = t / 0.167;
                return mix(float3(0.6, 0.0, 0.8), float3(1.0, 0.0, 0.3), s);
            } else if (t < 0.333) {
                float s = (t - 0.167) / 0.166;
                return mix(float3(1.0, 0.0, 0.3), float3(1.0, 0.5, 0.0), s);
            } else if (t < 0.5) {
                float s = (t - 0.333) / 0.167;
                return mix(float3(1.0, 0.5, 0.0), float3(1.0, 1.0, 0.0), s);
            } else if (t < 0.667) {
                float s = (t - 0.5) / 0.167;
                return mix(float3(1.0, 1.0, 0.0), float3(0.0, 1.0, 0.3), s);
            } else if (t < 0.833) {
                float s = (t - 0.667) / 0.166;
                return mix(float3(0.0, 1.0, 0.3), float3(0.0, 1.0, 1.0), s);
            } else {
                float s = (t - 0.833) / 0.167;
                return mix(float3(0.0, 1.0, 1.0), float3(0.3, 0.5, 1.0), s);
            }
        }

        // MARK: - Cylindrical Bars Vertex Shader

        vertex VertexOut cylindricalBars_vertex(
            uint vertexID [[vertex_id]],
            uint instanceID [[instance_id]],
            constant Uniforms &uniforms [[buffer(0)]],
            constant float *spectrum [[buffer(1)]],
            constant float3 *vertices [[buffer(2)]],
            constant float3 *normals [[buffer(3)]]
        ) {
            VertexOut out;

            int numBars = uniforms.barCount;
            int idx = int(instanceID);

            // Get audio value with blending at boundaries
            float audioValue = spectrum[idx];

            // Blend the last few bars with the first few for smooth wrap
            int blendRange = 16;  // Number of bars to blend on each end
            if (idx < blendRange) {
                // Blend start with end
                float blendFactor = float(idx) / float(blendRange);
                float endValue = spectrum[numBars - 1 - (blendRange - idx)];
                audioValue = mix(endValue, audioValue, blendFactor * 0.5 + 0.5);
            } else if (idx >= numBars - blendRange) {
                // Blend end with start
                float blendFactor = float(numBars - 1 - idx) / float(blendRange);
                float startValue = spectrum[blendRange - (numBars - 1 - idx)];
                audioValue = mix(startValue, audioValue, blendFactor * 0.5 + 0.5);
            }

            float angle = float(instanceID) / float(numBars) * 2.0 * M_PI_F;
            float radius = 3.5;  // Slightly larger radius

            float barWidth = 2.0 * M_PI_F * radius / float(numBars) * 0.85;
            float barDepth = 0.12;
            float barHeight = 0.15 + audioValue * 3.5;

            float beatPulse = 1.0 + uniforms.beatStrength * 0.25;
            radius *= beatPulse;
            barHeight *= beatPulse;

            float3 localPos = vertices[vertexID];
            localPos.x *= barWidth * 0.5;
            localPos.y *= barHeight;
            localPos.z *= barDepth * 0.5;
            localPos.y += barHeight * 0.5;

            float cosA = cos(angle);
            float sinA = sin(angle);

            float3 rotatedPos;
            rotatedPos.x = localPos.x * cosA - localPos.z * sinA;
            rotatedPos.y = localPos.y;
            rotatedPos.z = localPos.x * sinA + localPos.z * cosA;

            rotatedPos.x += radius * sinA;
            rotatedPos.z += radius * cosA;
            rotatedPos.y -= 1.5;  // Center vertically

            float4 worldPos = uniforms.modelMatrix * float4(rotatedPos, 1.0);
            out.worldPosition = worldPos.xyz;

            float3 localNormal = normals[vertexID];
            float3 rotatedNormal;
            rotatedNormal.x = localNormal.x * cosA - localNormal.z * sinA;
            rotatedNormal.y = localNormal.y;
            rotatedNormal.z = localNormal.x * sinA + localNormal.z * cosA;
            out.normal = normalize((uniforms.modelMatrix * float4(rotatedNormal, 0.0)).xyz);

            out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;

            // Color based on frequency position with smooth wrap
            float t = float(instanceID) / float(numBars);
            float3 baseColor = spectrumColor(t);
            float intensity = 0.4 + audioValue * 0.6;
            out.color = float4(baseColor * intensity, 1.0);

            // Glow effect for loud bars
            if (audioValue > 0.5) {
                out.color.rgb += float3(1.0, 1.0, 1.0) * (audioValue - 0.5) * 0.4;
            }

            out.audioValue = audioValue;
            out.texcoord = float2(t, audioValue);

            return out;
        }

        // MARK: - Cylindrical Bars Fragment Shader

        fragment float4 cylindricalBars_fragment(VertexOut in [[stage_in]]) {
            float3 lightDir = normalize(float3(0.5, 1.0, 0.3));
            float diffuse = max(dot(in.normal, lightDir), 0.0) * 0.5 + 0.5;

            float3 finalColor = in.color.rgb * diffuse;
            finalColor += in.color.rgb * 0.1;

            if (in.audioValue > 0.7 && in.texcoord.y > 0.8) {
                finalColor += float3(1.0, 1.0, 1.0) * 0.2;
            }

            return float4(finalColor, 1.0);
        }
        """

        return combinedSource
    }

    // MARK: - Visualization Setup

    private func setupCylindricalBars() {
        guard let library = self.library else {
            print("No shader library available")
            return
        }

        let cylindricalBars = CylindricalBarsRenderer()
        do {
            try cylindricalBars.setup(device: device, library: library)
            currentVisualization = cylindricalBars
            visualizationName = cylindricalBars.name
            print("Set up visualization: \(cylindricalBars.name)")
        } catch {
            print("Failed to set up CylindricalBars: \(error)")
        }
    }

    func setVisualization(_ index: Int) {
        // For now, we only have cylindrical bars
        // This will be expanded as we add more visualizations
        switch index {
        case 0:
            setupCylindricalBars()
        default:
            setupCylindricalBars()
        }
    }

    func setBarCount(_ count: Int) {
        currentVisualization?.barCount = count
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        camera.updateProjection(aspectRatio: Float(size.width / size.height))
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        // Get audio data from view model
        let spectrum = audioViewModel?.spectrumData ?? Array(repeating: 0, count: 512)
        let waveformL = audioViewModel?.waveformLeft ?? Array(repeating: 0, count: 1024)
        let waveformR = audioViewModel?.waveformRight ?? Array(repeating: 0, count: 1024)
        let beatPhase = audioViewModel?.beatPhase ?? 0
        let beatStrength = audioViewModel?.beatStrength ?? 0
        let beatDetected = audioViewModel?.beatDetected ?? false
        let bpm = audioViewModel?.currentBPM ?? 120

        // Update visualization audio data
        currentVisualization?.updateAudioData(spectrum: spectrum, waveformL: waveformL, waveformR: waveformR)

        // Set up render state
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setCullMode(.back)

        // Update camera (auto-rotate if enabled)
        camera.update()

        // Create uniforms
        var uniforms = Uniforms(
            projectionMatrix: camera.projectionMatrix,
            viewMatrix: camera.viewMatrix,
            modelMatrix: matrix_identity_float4x4,
            time: Float(CFAbsoluteTimeGetCurrent() - startTime),
            beatPhase: beatPhase,
            beatStrength: beatStrength,
            beatDetected: beatDetected ? 1 : 0,
            bpm: bpm,
            resolution: simd_float2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            barCount: Int32(currentVisualization?.barCount ?? 128)
        )

        // Draw current visualization
        currentVisualization?.draw(encoder: renderEncoder, uniforms: &uniforms)

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Mouse/Trackpad Input

    func handleMouseDragged(deltaX: CGFloat, deltaY: CGFloat) {
        camera.handleMouseDragged(deltaX: deltaX, deltaY: deltaY)
    }

    func handleScrollWheel(deltaY: CGFloat) {
        camera.handleScrollWheel(deltaY: deltaY)
    }

    func handleMagnify(magnification: CGFloat) {
        camera.handleMagnify(magnification: magnification)
    }
}
