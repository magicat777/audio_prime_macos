//
//  PanelHeader.swift
//  AudioPrime
//
//  Reusable panel header component
//

import SwiftUI

struct PanelHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundColor(.accentColor)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

#Preview {
    VStack(spacing: 0) {
        PanelHeader(title: "Spectrum Analyzer", icon: "waveform")
        Spacer()
    }
    .frame(width: 300, height: 100)
}
