//
//  MetalView.swift
//  AudioPrime
//
//  SwiftUI wrapper for MTKView with Metal rendering
//  Handles mouse/trackpad input for camera control
//

import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    @ObservedObject var viewModel: AudioViewModel
    @Binding var selectedVisualization: Int
    @Binding var barCount: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, barCount: barCount)
    }

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MetalMTKView()
        mtkView.coordinator = context.coordinator

        // Initialize renderer with viewModel for audio data access
        if let renderer = MetalRenderer(mtkView: mtkView, viewModel: viewModel) {
            context.coordinator.renderer = renderer
        }

        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        // Update bar count if changed
        if context.coordinator.currentBarCount != barCount {
            context.coordinator.currentBarCount = barCount
            context.coordinator.renderer?.setBarCount(barCount)
        }
    }

    static func dismantleNSView(_ nsView: MTKView, coordinator: Coordinator) {
        // Cleanup if needed
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject {
        var renderer: MetalRenderer?
        let viewModel: AudioViewModel
        var currentBarCount: Int

        init(viewModel: AudioViewModel, barCount: Int) {
            self.viewModel = viewModel
            self.currentBarCount = barCount
            super.init()
        }

        // Mouse/trackpad event forwarding
        func handleMouseDragged(deltaX: CGFloat, deltaY: CGFloat) {
            renderer?.handleMouseDragged(deltaX: deltaX, deltaY: deltaY)
        }

        func handleScrollWheel(deltaY: CGFloat) {
            renderer?.handleScrollWheel(deltaY: deltaY)
        }

        func handleMagnify(magnification: CGFloat) {
            renderer?.handleMagnify(magnification: magnification)
        }
    }
}

// MARK: - Custom MTKView Subclass for Mouse Events

class MetalMTKView: MTKView {
    weak var coordinator: MetalView.Coordinator?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDragged(with event: NSEvent) {
        coordinator?.handleMouseDragged(deltaX: event.deltaX, deltaY: event.deltaY)
    }

    override func scrollWheel(with event: NSEvent) {
        // Use scrollingDeltaY for trackpad, deltaY for mouse wheel
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY * 0.01 : event.deltaY
        coordinator?.handleScrollWheel(deltaY: delta)
    }

    override func magnify(with event: NSEvent) {
        coordinator?.handleMagnify(magnification: event.magnification)
    }

    override func mouseDown(with event: NSEvent) {
        // Accept first responder to receive mouse events
        window?.makeFirstResponder(self)
    }

    override func rightMouseDragged(with event: NSEvent) {
        // Right drag also controls camera
        coordinator?.handleMouseDragged(deltaX: event.deltaX, deltaY: event.deltaY)
    }
}
