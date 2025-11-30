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
}

