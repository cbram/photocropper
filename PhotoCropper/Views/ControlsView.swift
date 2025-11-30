//
//  ControlsView.swift
//  PhotoCropper
//
//  Control-Panel mit Format-Auswahl, Modus-Toggle, Slider, Buttons
//

import SwiftUI

struct ControlsView: View {
    @Binding var targetRatio: AspectRatio
    @Binding var cropMode: CropMode
    @Binding var showMCUGrid: Bool
    @Binding var compositionOverlay: CompositionOverlay
    @Binding var cropBox: CGRect
    @Binding var customWidth: String
    @Binding var customHeight: String
    
    var imageSize: CGSize
    var onCenter: () -> Void
    var onReset: () -> Void
    var onMaximize: () -> Void
    var onCropBoxChanged: (CGRect) -> Void
    
    // Helper für Picker: Vereinfachtes Enum ohne associated values
    private enum RatioSelection: String, CaseIterable, Identifiable {
        case ratio16_9 = "16:9"
        case ratio1_1 = "1:1"
        case custom = "custom"
        
        var id: String { rawValue }
    }
    
    // Computed property für Picker-Selection
    private var ratioSelection: RatioSelection {
        let selection: RatioSelection
        switch targetRatio {
        case .ratio16_9:
            selection = .ratio16_9
        case .ratio1_1:
            selection = .ratio1_1
        case .custom(let w, let h):
            selection = .custom
            print("🎯 ControlsView: ratioSelection computed -> custom (\(w):\(h))")
        }
        return selection
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Zielformat-Auswahl
            VStack(alignment: .leading, spacing: 8) {
                Text("ZIELFORMAT WÄHLEN")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Picker("Format", selection: Binding(
                    get: { ratioSelection },
                    set: { newValue in
                        switch newValue {
                        case .ratio16_9:
                            targetRatio = .ratio16_9
                        case .ratio1_1:
                            targetRatio = .ratio1_1
                        case .custom:
                            // Parse custom values from text fields
                            if let w = Int(customWidth), let h = Int(customHeight), w > 0, h > 0 {
                                targetRatio = .custom(width: w, height: h)
                            } else {
                                targetRatio = .custom(width: 16, height: 9)
                            }
                        }
                    }
                )) {
                    Text("16:9 (Landscape)").tag(RatioSelection.ratio16_9)
                    Text("1:1 (Quadrat)").tag(RatioSelection.ratio1_1)
                    Text("Benutzerdefiniert").tag(RatioSelection.custom)
                }
                .pickerStyle(.radioGroup)
                
                if case .custom = targetRatio {
                    HStack {
                        Text("Breite:")
                        TextField("16", text: $customWidth)
                            .frame(width: 60)
                        Text("Höhe:")
                        TextField("9", text: $customHeight)
                            .frame(width: 60)
                    }
                    .padding(.leading, 20)
                }
            }
            
            Divider()
            
            // Cropping-Modus
            VStack(alignment: .leading, spacing: 8) {
                Text("CROPPING-MODUS")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Picker("Modus", selection: $cropMode) {
                    Text("MCU-sensitiv (Lossless)").tag(CropMode.mcuSensitive)
                    Text("Standard (Fallback)").tag(CropMode.standard)
                }
                .pickerStyle(.radioGroup)
            }
            
            Divider()
            
            // Kompositions-Overlay
            VStack(alignment: .leading, spacing: 8) {
                Text("KOMPOSITIONS-OVERLAY")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Picker("Overlay", selection: $compositionOverlay) {
                    ForEach(CompositionOverlay.allCases, id: \.self) { overlay in
                        Text(overlay.displayName).tag(overlay)
                    }
                }
                .pickerStyle(.radioGroup)
                
                HStack(spacing: 4) {
                    Image(systemName: "keyboard")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Leertaste: Overlay ein/ausblenden")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 20)
            }
            
            Divider()
            
            // Position & Feintuning
            VStack(alignment: .leading, spacing: 8) {
                Text("POSITION & FEINTUNING")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Position X:")
                        Slider(value: Binding(
                            get: { cropBox.origin.x },
                            set: { newValue in
                                var newBox = cropBox
                                newBox.origin.x = max(0, min(newValue, imageSize.width - cropBox.width))
                                onCropBoxChanged(newBox)
                            }
                        ), in: 0...max(0, imageSize.width - cropBox.width))
                        Text("\(Int(cropBox.origin.x))")
                            .frame(width: 60)
                    }
                    .disabled(imageSize.width <= cropBox.width)
                    
                    HStack {
                        Text("Position Y:")
                        Slider(value: Binding(
                            get: { cropBox.origin.y },
                            set: { newValue in
                                var newBox = cropBox
                                newBox.origin.y = max(0, min(newValue, imageSize.height - cropBox.height))
                                onCropBoxChanged(newBox)
                            }
                        ), in: 0...max(0, imageSize.height - cropBox.height))
                        Text("\(Int(cropBox.origin.y))")
                            .frame(width: 60)
                    }
                    .disabled(imageSize.height <= cropBox.height)
                    
                    HStack {
                        Text("Breite:")
                        Slider(value: Binding(
                            get: { cropBox.width },
                            set: { newValue in
                                var newBox = cropBox
                                // WICHTIG: Max. Breite basierend auf aktueller X-Position!
                                let maxWidth = imageSize.width - newBox.origin.x
                                newBox.size.width = max(1, min(newValue, maxWidth))
                                // Wenn Aspect Ratio gesperrt, Höhe anpassen
                                if case .custom = targetRatio {
                                    // Bei custom: Nichts tun
                                } else {
                                    let ratio = targetRatio == .ratio16_9 ? 16.0/9.0 : 1.0
                                    newBox.size.height = newBox.size.width / ratio
                                    // Sicherstellen dass Höhe nicht über Bildrand hinausgeht
                                    let maxHeight = imageSize.height - newBox.origin.y
                                    if newBox.size.height > maxHeight {
                                        newBox.size.height = maxHeight
                                        newBox.size.width = newBox.size.height * ratio
                                    }
                                }
                                onCropBoxChanged(newBox)
                            }
                        ), in: {
                            // Bei Aspect Ratio Lock: Max. Breite begrenzen durch max. Höhe UND Position
                            let maxWidthForPosition = imageSize.width - cropBox.origin.x
                            if case .custom = targetRatio {
                                return 1...max(1, maxWidthForPosition)
                            } else {
                                let ratio = targetRatio == .ratio16_9 ? 16.0/9.0 : 1.0
                                let maxHeightForPosition = imageSize.height - cropBox.origin.y
                                let maxWidthForHeight = maxHeightForPosition * ratio
                                let maxWidth = min(maxWidthForPosition, maxWidthForHeight)
                                return 1...max(1, maxWidth)
                            }
                        }())
                        Text("\(Int(cropBox.width))")
                            .frame(width: 60)
                    }
                    .disabled(imageSize.width <= 0)
                    
                    HStack {
                        Text("Höhe:")
                        Slider(value: Binding(
                            get: { cropBox.height },
                            set: { newValue in
                                var newBox = cropBox
                                // WICHTIG: Max. Höhe basierend auf aktueller Y-Position!
                                let maxHeight = imageSize.height - newBox.origin.y
                                newBox.size.height = max(1, min(newValue, maxHeight))
                                // Wenn Aspect Ratio gesperrt, Breite anpassen
                                if case .custom = targetRatio {
                                    // Bei custom: Nichts tun
                                } else {
                                    let ratio = targetRatio == .ratio16_9 ? 16.0/9.0 : 1.0
                                    newBox.size.width = newBox.size.height * ratio
                                    // Sicherstellen dass Breite nicht über Bildrand hinausgeht
                                    let maxWidth = imageSize.width - newBox.origin.x
                                    if newBox.size.width > maxWidth {
                                        newBox.size.width = maxWidth
                                        newBox.size.height = newBox.size.width / ratio
                                    }
                                }
                                onCropBoxChanged(newBox)
                            }
                        ), in: {
                            // Bei Aspect Ratio Lock: Max. Höhe begrenzen durch max. Breite UND Position
                            let maxHeightForPosition = imageSize.height - cropBox.origin.y
                            if case .custom = targetRatio {
                                return 1...max(1, maxHeightForPosition)
                            } else {
                                let ratio = targetRatio == .ratio16_9 ? 16.0/9.0 : 1.0
                                let maxWidthForPosition = imageSize.width - cropBox.origin.x
                                let maxHeightForWidth = maxWidthForPosition / ratio
                                let maxHeight = min(maxHeightForPosition, maxHeightForWidth)
                                return 1...max(1, maxHeight)
                            }
                        }())
                        Text("\(Int(cropBox.height))")
                            .frame(width: 60)
                    }
                    .disabled(imageSize.height <= 0)
                }
                
                Toggle("MCU-Grid anzeigen", isOn: $showMCUGrid)
            }
            
            Divider()
            
            // Schnellzugriffe
            VStack(alignment: .leading, spacing: 8) {
                Text("SCHNELLZUGRIFFE")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Button("Zentriert", action: onCenter)
                        .buttonStyle(.bordered)
                    Button("Reset", action: onReset)
                        .buttonStyle(.bordered)
                    Button("Maximize", action: onMaximize)
                        .buttonStyle(.bordered)
                }
                
                // Eckpunkt-Koordinaten
                Divider()
                    .padding(.vertical, 8)
                
                Text("ECKPUNKT-KOORDINATEN")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                let x1 = Int(cropBox.origin.x)
                let y1 = Int(cropBox.origin.y)
                let x2 = Int(cropBox.origin.x + cropBox.width)
                let y2 = Int(cropBox.origin.y + cropBox.height)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Oben Links:     (\(x1), \(y2))")
                        .font(.system(.caption, design: .monospaced))
                    Text("Oben Rechts:    (\(x2), \(y2))")
                        .font(.system(.caption, design: .monospaced))
                    Text("Unten Links:    (\(x1), \(y1))")
                        .font(.system(.caption, design: .monospaced))
                    Text("Unten Rechts:   (\(x2), \(y1))")
                        .font(.system(.caption, design: .monospaced))
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

