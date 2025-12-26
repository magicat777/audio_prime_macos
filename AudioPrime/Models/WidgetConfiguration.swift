//
//  WidgetConfiguration.swift
//  AudioPrime
//
//  Modular widget configuration for enabling/disabling panels
//  Allows users to customize layout based on screen space and needs
//

import SwiftUI

/// Configuration for all widget/panel visibility states
struct WidgetConfiguration: Equatable {
    // MARK: - Main Panels

    /// Spectrum analyzer panel (left side)
    var showSpectrum: Bool = true

    /// 3D visualization panel (center)
    var showVisualization: Bool = true

    /// Analysis tools panel (right side)
    var showAnalysis: Bool = true

    // MARK: - Spectrum Sub-Widgets

    /// Bass detail sub-panel (20-200Hz)
    var showBassDetail: Bool = true

    /// Oscilloscope waveform display (time-domain)
    var showOscilloscope: Bool = true

    /// Vertical meters (LUFS, True Peak, VU) next to spectrum
    var showVerticalMeters: Bool = true

    /// Spectrum controls (FFT size, smoothing, etc.)
    var showSpectrumControls: Bool = true

    // MARK: - Metering Widgets

    /// LUFS loudness meters (M, S, I)
    var showLUFSMeters: Bool = true

    /// True Peak meter
    var showTruePeak: Bool = true

    /// VU meters (L/R)
    var showVUMeters: Bool = true

    /// BPM/Tempo display
    var showBPM: Bool = true

    /// Frequency bands analyzer
    var showFrequencyBands: Bool = true

    // MARK: - Stereo Analysis

    /// Goniometer (stereo phase scope)
    var showGoniometer: Bool = true

    /// Stereo correlation meter
    var showCorrelation: Bool = true

    /// M/S (Mid/Side) display
    var showMidSide: Bool = true

    // MARK: - Utility Panels

    /// Debug values panel
    var showDebug: Bool = true

    /// Bottom info bar (BPM, LUFS, status)
    var showBottomBar: Bool = true

    // MARK: - Presets

    /// Full layout - all widgets enabled
    static var full: WidgetConfiguration {
        WidgetConfiguration()
    }

    /// Minimal layout - spectrum and essential meters only
    static var minimal: WidgetConfiguration {
        var config = WidgetConfiguration()
        config.showVisualization = false
        config.showAnalysis = false
        config.showBassDetail = false
        config.showGoniometer = false
        config.showCorrelation = false
        config.showMidSide = false
        config.showDebug = false
        return config
    }

    /// Metering focused - all meters, no visualization
    static var metering: WidgetConfiguration {
        var config = WidgetConfiguration()
        config.showVisualization = false
        config.showBassDetail = true
        config.showGoniometer = true
        config.showDebug = true
        return config
    }

    /// Visualization focused - 3D vis and spectrum only
    static var visualization: WidgetConfiguration {
        var config = WidgetConfiguration()
        config.showAnalysis = false
        config.showVerticalMeters = false
        config.showBassDetail = false
        config.showDebug = false
        return config
    }
}

// MARK: - Widget Preset Enum

enum WidgetPreset: String, CaseIterable, Identifiable {
    case full = "Full"
    case minimal = "Minimal"
    case metering = "Metering"
    case visualization = "Visualization"
    case custom = "Custom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .full: return "square.grid.3x3.fill"
        case .minimal: return "square.fill"
        case .metering: return "chart.bar.fill"
        case .visualization: return "waveform.circle.fill"
        case .custom: return "slider.horizontal.3"
        }
    }

    var configuration: WidgetConfiguration {
        switch self {
        case .full: return .full
        case .minimal: return .minimal
        case .metering: return .metering
        case .visualization: return .visualization
        case .custom: return .full // Custom starts from full
        }
    }
}
