//
//  PhotoCropperApp.swift
//  PhotoCropper
//
//  Haupt-App-Entry-Point
//

import SwiftUI

@main
struct PhotoCropperApp: App {
    @StateObject private var batchManager = BatchImageManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView(batchManager: batchManager)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Bild öffnen...") {
                    // Wird von ContentView gehandhabt
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

