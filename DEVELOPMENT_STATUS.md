# AudioPrime macOS - Development Status

## Project Overview

**AudioPrime macOS** is a native Swift/C++ port of the [Electron-based AUDIO_PRIME](https://github.com/magicat777/AUDIO_PRIME) real-time audio visualizer. This port leverages Apple's native frameworks for optimal performance on macOS.

### Tech Stack

| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI |
| Audio Engine | C++ with vDSP/Accelerate |
| Audio Capture | ScreenCaptureKit |
| Build System | Swift Package Manager |
| Target Platform | macOS 14.0+ |

---

## Implemented Features

### Phase 1: Core Infrastructure
- [x] Swift Package Manager project structure
- [x] C++/Swift bridging via C API
- [x] Basic SwiftUI application shell
- [x] Panel-based UI layout (Spectrum, Meters, Analysis)

### Phase 2: Audio Capture & FFT
- [x] ScreenCaptureKit system audio capture
- [x] Real-time stereo audio processing (48kHz, 32-bit float)
- [x] vDSP-accelerated FFT analysis
- [x] Configurable FFT sizes (512, 1024, 2048, 4096)
- [x] Hann windowing for spectral leakage reduction
- [x] 75% overlap for low latency (~21ms at 4096 FFT)
- [x] Logarithmic frequency scale (20Hz - 20kHz)
- [x] 512-bar spectrum display with color gradient

### Phase 3: Stereo Analysis
- [x] Stereo correlation meter (-1 to +1)
- [x] L/R level metering with RMS calculation
- [x] Mid/Side (M/S) level analysis
- [x] Lissajous goniometer display with auto-scaling
- [x] Real-time goniometer point rendering (512 points)

### Phase 4: Advanced Spectrum Features
- [x] Multi-Resolution FFT mode (frequency-dependent smoothing)
- [x] A-weighting perceptual filter (IEC 61672-1)
- [x] Bass Detail panel (20-200Hz zoomed view)
- [x] Catmull-Rom cubic interpolation for bass detail
- [x] Frequency-dependent noise floor adjustment
- [x] Grid overlay with dB scale (0 to -80dB)
- [x] Frequency labels (20Hz to 20kHz)
- [x] Major/minor grid line styling
- [x] Configurable smoothing control

### UI/UX
- [x] FPS counter (real-time measurement)
- [x] Latency display (hop-size based)
- [x] Start/Stop capture button
- [x] FFT size selector (segmented control)
- [x] Smoothing slider
- [x] Multi-Res FFT toggle
- [x] A-Weighting toggle
- [x] Dark theme interface

---

## Features Not Yet Implemented

### Spectrum Analysis
- [ ] Waterfall spectrogram (60 FPS scrolling history)
- [ ] Six-band frequency analysis display
- [ ] True multi-resolution FFT (separate FFT sizes per band)
- [ ] Extended dynamic range display (-80dB to -10dB option)

### Professional Metering
- [ ] ITU-R BS.1770-4 LUFS measurement
  - [ ] Momentary loudness (400ms window)
  - [ ] Short-term loudness (3s window)
  - [ ] Integrated loudness (program duration)
  - [ ] True peak detection (4x oversampling)
- [ ] VU meters with peak hold
- [ ] BPM detection with beat phase visualization

### Voice Analysis
- [ ] Voice activity detection (VAD)
- [ ] Singing vs. speech classification
- [ ] Formant tracking (F1-F4)
- [ ] Vibrato detection (4.5-8.5 Hz range)
- [ ] Pitch/fundamental frequency estimation

### Stereo Analysis (Enhancements)
- [ ] Oscilloscope waveform view
- [ ] Auto-gain for oscilloscope
- [ ] Phase correlation history

### 3D Visualizations
- [ ] Cylindrical spectrum bars (Metal/SceneKit)
- [ ] 3D waterfall mesh surface
- [ ] Pulsating frequency sphere
- [ ] Point cloud stereo visualization
- [ ] Tunnel effect with concentric rings
- [ ] Terrain landscape visualization

### Spotify Integration
- [ ] OAuth PKCE authentication
- [ ] Now-playing display with album art
- [ ] Playback controls
- [ ] Encrypted token storage

### Additional Features
- [ ] Preset management (save/load configurations)
- [ ] Audio device selection
- [ ] Window resizing with responsive layout
- [ ] Keyboard shortcuts
- [ ] Menu bar integration
- [ ] Export analysis data

---

## Performance Metrics

### Current (macOS Port)
| Metric | Value |
|--------|-------|
| Frame Rate | 60 FPS |
| Latency (512 FFT) | ~2.7ms |
| Latency (4096 FFT) | ~21.3ms |
| Sample Rate | 48kHz |
| Channels | 2 (Stereo) |

### Target (Electron Original)
| Metric | Value |
|--------|-------|
| Frame Rate | 60 FPS |
| End-to-end Latency | ~10ms |
| FFT Processing | ~1.5ms/frame |
| Memory Usage | ~150MB |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      SwiftUI Layer                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Spectrum   │  │   Meters    │  │     Analysis        │  │
│  │  PanelView  │  │  PanelView  │  │     PanelView       │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    AudioViewModel                           │
│              (MainActor, ObservableObject)                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  AudioCaptureService                        │
│                   (ScreenCaptureKit)                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  AudioEngineWrapper                         │
│                    (Swift ↔ C API)                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                 C++ AudioEngine                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  • vDSP FFT Processing                               │  │
│  │  • Spectrum Analysis (512 bars)                      │  │
│  │  • Stereo Correlation                                │  │
│  │  • M/S Level Calculation                             │  │
│  │  • Goniometer Points                                 │  │
│  │  • A-Weighting Filter                                │  │
│  │  • Bass Detail Extraction                            │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## File Structure

```
audio-prime-ios/
├── Package.swift                 # SPM manifest
├── AudioPrime/
│   ├── AudioPrimeApp.swift       # App entry point
│   ├── Services/
│   │   ├── AudioCaptureService.swift
│   │   └── AudioEngineWrapper.swift
│   ├── ViewModels/
│   │   └── AudioViewModel.swift
│   └── Views/
│       ├── MainWindowView.swift
│       ├── SpectrumPanelView.swift
│       ├── MetersPanelView.swift
│       ├── AnalysisPanelView.swift
│       └── PanelHeader.swift
├── AudioPrimeCore/
│   ├── include/
│   │   ├── AudioEngine.h         # C API header
│   │   └── AudioEngine.hpp       # C++ class header
│   └── src/
│       └── AudioEngine.cpp       # C++ implementation
└── Tests/
    └── AudioPrimeTests/
```

---

## Development Priorities

### High Priority
1. **LUFS Metering** - Essential for professional audio work
2. **BPM Detection** - Core feature for music analysis
3. **Waterfall Spectrogram** - Visual history of spectrum

### Medium Priority
4. **Voice Analysis** - Formant tracking, pitch detection
5. **VU Meters** - Traditional metering display
6. **True Multi-Resolution FFT** - Per-band FFT sizes

### Low Priority (Future)
7. **3D Visualizations** - Metal/SceneKit implementation
8. **Spotify Integration** - OAuth flow for macOS
9. **Preset Management** - Save/load configurations

---

## Build & Run

```bash
# Build
swift build

# Run
.build/debug/AudioPrime

# Build for release
swift build -c release
```

**Requirements:**
- macOS 14.0 or later
- Xcode 15.0+ (for Swift 5.9+)
- Screen Recording permission (System Preferences → Privacy & Security)

---

## Commits History

| Commit | Description |
|--------|-------------|
| `966b5e6` | Phase 4: Advanced spectrum features with grid overlay |
| `5667540` | Phase 3: Stereo analysis with correlation, M/S, goniometer |
| `2bff286` | Fix: Dynamic FPS and latency metrics display |
| `a4bf358` | Phase 2: Working spectrum analyzer with FFT controls |
| `1d02c86` | Fix: Swift 6 concurrency errors |
| `56af23d` | Fix: Move tests to proper SPM location |
| `5527d9e` | Phase 2 Complete: Real-Time Stereo Audio Capture |
| `16a9f96` | Initial commit - AudioPrime Phase 1 Complete |

---

## License

This project is a macOS port of AUDIO_PRIME. See the original project for license information.

---

*Last Updated: December 2024*
