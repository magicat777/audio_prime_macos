//
//  AudioPrimeApp.swift
//  AudioPrime
//
//  Professional Audio Spectrum Analyzer for macOS
//  Native Swift/C++ port from Electron
//

import SwiftUI

// Shared ViewModel for both windows
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    let audioViewModel = AudioViewModel()
}

@main
struct AudioPrimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // Main visualization window
        WindowGroup {
            MainWindowView(viewModel: appState.audioViewModel)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // Custom menu commands
            CommandGroup(replacing: .appInfo) {
                Button("About AudioPrime") {
                    // TODO: Show about window
                }
            }

            CommandGroup(after: .windowArrangement) {
                Button("Reset Panel Layout") {
                    // TODO: Reset to default panel sizes
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }

            // View menu - Controls window
            CommandGroup(after: .toolbar) {
                Button("Show FFT Controls") {
                    openWindow(id: "controls")
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }

        // Separate controls window (isolated from 60fps updates)
        Window("FFT Controls", id: "controls") {
            ControlsWindowView(viewModel: appState.audioViewModel)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request screen recording permission for ScreenCaptureKit
        print("AudioPrime launched - requesting screen recording permission...")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
