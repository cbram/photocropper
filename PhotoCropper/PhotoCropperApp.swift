//
//  PhotoCropperApp.swift
//  PhotoCropper
//
//  Main app entry point
//

import SwiftUI

@main
struct PhotoCropperApp: App {
    @StateObject private var batchManager = BatchImageManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView(batchManager: batchManager)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About PhotoCropper") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationVersion: Self.buildDescription
                    ])
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("Bild öffnen...") {
                    // Handled by ContentView
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Divider()
                
                Button("Alle Fotos schließen") {
                    batchManager.clear()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(batchManager.images.isEmpty)
            }
        }
    }

    /// Build part of the About panel version, e.g. "147 · b275e0f".
    /// Both values are stamped into Info.plist by Scripts/stamp-build-version.sh.
    private static var buildDescription: String {
        let info = Bundle.main.infoDictionary
        let buildNumber = info?["CFBundleVersion"] as? String ?? "0"
        let commit = info?["GitCommit"] as? String ?? "unknown"
        return "\(buildNumber) · \(commit)"
    }
}

