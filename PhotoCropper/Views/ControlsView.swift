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
    @Binding var autoFallback: Bool
    @Binding var showMCUGrid: Bool
    @Binding var cropBox: CGRect
    @Binding var customWidth: String
    @Binding var customHeight: String
    
    var imageSize: CGSize
    var onCenter: () -> Void
    var onReset: () -> Void
    var onMaximize: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Zielformat-Auswahl
            VStack(alignment: .leading, spacing: 10) {
                Text("ZIELFORMAT WÄHLEN")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Picker("Format", selection: $targetRatio) {
                    Text("16:9 (Landscape)").tag(AspectRatio.ratio16_9)
                    Text("1:1 (Quadrat)").tag(AspectRatio.ratio1_1)
                    Text("Benutzerdefiniert").tag(AspectRatio.custom(width: 16, height: 9) as AspectRatio)
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
            VStack(alignment: .leading, spacing: 10) {
                Text("CROPPING-MODUS")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Picker("Modus", selection: $cropMode) {
                    Text("MCU-sensitiv (Lossless)").tag(CropMode.mcuSensitive)
                    Text("Standard (Fallback)").tag(CropMode.standard)
                }
                .pickerStyle(.radioGroup)
                
                Toggle("Auto-Fallback aktivieren", isOn: $autoFallback)
                    .padding(.leading, 20)
            }
            
            Divider()
            
            // Position & Feintuning
            VStack(alignment: .leading, spacing: 10) {
                Text("POSITION & FEINTUNING")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Position X:")
                        Slider(value: Binding(
                            get: { cropBox.origin.x },
                            set: { newValue in
                                cropBox.origin.x = max(0, min(newValue, imageSize.width - cropBox.width))
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
                                cropBox.origin.y = max(0, min(newValue, imageSize.height - cropBox.height))
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
                                cropBox.size.width = max(1, min(newValue, imageSize.width))
                                // Wenn Aspect Ratio gesperrt, Höhe anpassen
                                if case .custom = targetRatio {
                                    // Bei custom: Nichts tun
                                } else {
                                    let ratio = targetRatio == .ratio16_9 ? 16.0/9.0 : 1.0
                                    cropBox.size.height = cropBox.size.width / ratio
                                    // Sicherstellen dass Höhe nicht zu groß wird
                                    if cropBox.size.height > imageSize.height {
                                        cropBox.size.height = imageSize.height
                                        cropBox.size.width = cropBox.size.height * ratio
                                    }
                                }
                            }
                        ), in: {
                            // Bei Aspect Ratio Lock: Max. Breite begrenzen durch max. Höhe
                            if case .custom = targetRatio {
                                return 1...max(1, imageSize.width)
                            } else {
                                let ratio = targetRatio == .ratio16_9 ? 16.0/9.0 : 1.0
                                let maxWidthForHeight = imageSize.height * ratio
                                let maxWidth = min(imageSize.width, maxWidthForHeight)
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
                                cropBox.size.height = max(1, min(newValue, imageSize.height))
                                // Wenn Aspect Ratio gesperrt, Breite anpassen
                                if case .custom = targetRatio {
                                    // Bei custom: Nichts tun
                                } else {
                                    let ratio = targetRatio == .ratio16_9 ? 16.0/9.0 : 1.0
                                    cropBox.size.width = cropBox.size.height * ratio
                                    // Sicherstellen dass Breite nicht zu groß wird
                                    if cropBox.size.width > imageSize.width {
                                        cropBox.size.width = imageSize.width
                                        cropBox.size.height = cropBox.size.width / ratio
                                    }
                                }
                            }
                        ), in: {
                            // Bei Aspect Ratio Lock: Max. Höhe begrenzen durch max. Breite
                            if case .custom = targetRatio {
                                return 1...max(1, imageSize.height)
                            } else {
                                let ratio = targetRatio == .ratio16_9 ? 16.0/9.0 : 1.0
                                let maxHeightForWidth = imageSize.width / ratio
                                let maxHeight = min(imageSize.height, maxHeightForWidth)
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
            VStack(alignment: .leading, spacing: 10) {
                Text("SCHNELLZUGRIFFE")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Button("Zentriert", action: onCenter)
                    Button("Reset", action: onReset)
                    Button("Maximize", action: onMaximize)
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
            
            Spacer()
        }
        .padding()
        .frame(width: 300)
    }
}

