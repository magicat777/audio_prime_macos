//
//  VisualizationPanelView.swift
//  AudioPrime
//
//  3D visualization panel (Metal rendering)
//  Top center panel in main layout
//

import SwiftUI

struct VisualizationPanelView: View {
    @ObservedObject var viewModel: AudioViewModel
    @State private var selectedVisualization = 0

    let visualizations = [
        "Cylindrical Bars",
        "Frequency Sphere",
        "Point Cloud",
        "Tunnel Effect",
        "Terrain Landscape",
        "Waterfall Mesh"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Panel header with visualization selector
            HStack {
                PanelHeader(title: "3D Visualization", icon: "cube.fill")

                Spacer()

                Picker("", selection: $selectedVisualization) {
                    ForEach(0..<visualizations.count, id: \.self) { index in
                        Text(visualizations[index]).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
                .padding(.trailing, 12)
            }

            // Metal view placeholder
            // TODO: Replace with actual Metal rendering view
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [.black, .blue.opacity(0.3), .purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 20) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.3))

                    Text(visualizations[selectedVisualization])
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.5))

                    Text("Metal 3D rendering")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))

                    if viewModel.beatDetected {
                        Circle()
                            .fill(Color.green.opacity(0.8))
                            .frame(width: 20, height: 20)
                            .overlay(Text("♪").foregroundColor(.white))
                    }
                }
            }
            .cornerRadius(8)
            .padding(12)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    VisualizationPanelView(viewModel: AudioViewModel())
        .frame(width: 600, height: 400)
}
