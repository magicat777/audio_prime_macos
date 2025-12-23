//
//  AudioPrimeApp.swift
//  AudioPrime
//
//  Professional Audio Spectrum Analyzer for macOS
//  Native Swift/C++ port from Electron
//

import SwiftUI

@main
struct AudioPrimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainWindowView()
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
        }
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
