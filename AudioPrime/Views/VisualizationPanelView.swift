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
    @State private var barCount = 128

    let barCountOptions = [128, 256, 512]
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

                // Visualization picker (fixed width to prevent resizing)
                Picker("", selection: $selectedVisualization) {
                    ForEach(0..<visualizations.count, id: \.self) { index in
                        Text(visualizations[index]).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180, alignment: .trailing)
                .fixedSize()

                // Bar count button
                Button(action: {
                    if let currentIndex = barCountOptions.firstIndex(of: barCount) {
                        let nextIndex = (currentIndex + 1) % barCountOptions.count
                        barCount = barCountOptions[nextIndex]
                    }
                }) {
                    Text("\(barCount) bars")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .frame(width: 70)

                // Beat indicator (always present, opacity changes)
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .opacity(viewModel.beatDetected ? 0.9 : 0.15)
                    .padding(.horizontal, 8)
            }
            .padding(.trailing, 8)

            // Metal 3D view
            MetalView(viewModel: viewModel, selectedVisualization: $selectedVisualization, barCount: $barCount)
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
