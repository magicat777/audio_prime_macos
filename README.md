# AudioPrime for macOS

Professional real-time audio spectrum analyzer for macOS - Native Swift/C++ port from Electron.

## Overview

AudioPrime is a professional-grade audio analysis tool featuring:
- **512-bar spectrum analyzer** (20Hz-20kHz, 70dB dynamic range)
- **ITU-R BS.1770-4 loudness metering** (momentary, short-term, integrated)
- **Stereo analysis** (goniometer, correlation meter, M/S metering)
- **Voice analysis** (formant tracking, vibrato detection)
- **6 stunning 3D visualizations** (Metal-powered)
- **Spotify integration** (now playing, playback controls)

## Why Native?

The original Electron-based version faced a critical limitation: **Chromium's getDisplayMedia() API only captures mono audio on macOS**, making professional stereo audio analysis impossible. This native Swift/C++ version leverages Apple's **ScreenCaptureKit** framework to capture full stereo system audio.

## Tech Stack

- **Swift 6** - Modern UI and system integration
- **C++17** - High-performance audio processing
- **SwiftUI** - Declarative, responsive UI
- **Metal** - GPU-accelerated 3D visualizations
- **Accelerate framework** - Optimized FFT (vDSP)
- **ScreenCaptureKit** - Stereo system audio capture

## Requirements

- **macOS 13.0+** (Ventura or later)
- **Xcode 15.0+**
- **Screen Recording permission** (for audio capture)

## Project Structure

```
AudioPrime/
├── AudioPrime/              # Swift application
│   ├── App/                 # App entry point
│   ├── Views/               # SwiftUI views
│   ├── ViewModels/          # MVVM view models
│   ├── Services/            # Business logic
│   └── Metal/               # Metal shaders & rendering
├── AudioPrimeCore/          # C++ audio processing
│   ├── include/             # C++ headers
│   └── src/                 # C++ implementation
└── AudioPrimeTests/         # Unit tests
```

## Building & Running

### Using Swift Package Manager (SPM)

```bash
# Build the project
swift build

# Run the app
swift run AudioPrime
```

### Using Xcode

1. Open the project directory in Xcode
2. Select **Product > Build** (⌘B)
3. Select **Product > Run** (⌘R)

Or generate an Xcode project:

```bash
swift package generate-xcodeproj
open AudioPrime.xcodeproj
```

## Development Status

**Phase 1: Project Setup** ✅ COMPLETE
- [x] Project structure
- [x] Swift/C++ interop
- [x] Resizable panel layout (NSSplitView)
- [x] Placeholder UI for all panels
- [x] Basic FFT engine (C++ with Accelerate)

**Phase 2: Audio Capture & Spectrum** 🚧 IN PROGRESS
- [ ] ScreenCaptureKit audio capture
- [ ] Real-time spectrum analyzer
- [ ] 60 FPS performance optimization

**Phase 3: Professional Metering** 📅 PLANNED
- [ ] LUFS metering (ITU-R BS.1770-4)
- [ ] Beat detection & BPM
- [ ] Voice analysis
- [ ] Stereo analysis

**Phase 4: 3D Visualizations** 📅 PLANNED
- [ ] Metal rendering infrastructure
- [ ] 6 visualization modes

**Phase 5: Spotify Integration** 📅 PLANNED
- [ ] OAuth authentication
- [ ] Now playing display
- [ ] Playback controls

**Phase 6: Polish & Release** 📅 PLANNED
- [ ] Performance optimization
- [ ] Settings persistence
- [ ] DMG packaging

## Architecture

AudioPrime follows the **MVVM (Model-View-ViewModel)** pattern with strict separation of concerns:

### UI Layer (Swift/SwiftUI)
- Resizable panels using `NSSplitView`
- Reactive updates via Combine `@Published` properties
- 60 FPS Canvas/Metal rendering

### Business Logic (Swift)
- `AudioViewModel`: Central state management
- `AudioCaptureService`: ScreenCaptureKit integration
- `SpotifyService`: OAuth & API calls

### Audio Processing (C++)
- `AudioEngine`: Core processing pipeline
- `SpectrumAnalyzer`: FFT and frequency analysis
- All heavy computation in C++ for performance

### Swift/C++ Bridge
- C API layer (`AudioEngine.h`)
- Swift wrapper (`AudioEngineWrapper.swift`)
- Lock-free ring buffers for real-time audio

## Performance Targets

- **Frame Rate:** 60 FPS (no drops)
- **Latency:** <5ms end-to-end
- **CPU Usage:** <10% on Apple Silicon
- **Memory:** <200MB RAM

## License

[TBD - To match original AUDIO_PRIME project]

## Credits

Native macOS port developed with **Claude Code** (Anthropic)
Original Electron version: [AUDIO_PRIME](https://github.com/magicat777/AUDIO_PRIME)

---

**Note:** This is Phase 1 completion. The app builds and displays the UI shell with test data. Audio capture and real processing will be implemented in Phase 2.
