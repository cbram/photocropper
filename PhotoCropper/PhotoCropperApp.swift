//
//  PhotoCropperApp.swift
//  PhotoCropper
//
//  Haupt-App-Entry-Point
//

import SwiftUI

@main
struct PhotoCropperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1200, minHeight: 800)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Bild öffnen...") {
                    // Wird von ContentView gehandhabt
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

