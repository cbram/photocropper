//
//  ControlsView.swift
//  PhotoCropper
//
//  Control panel with format selection, mode toggle, sliders, and buttons
//

import SwiftUI

struct ControlsView: View {
    @Binding var targetRatio: AspectRatio
    @Binding var cropMode: CropMode
    @Binding var activeOverlay: OverlayGuide
    @Binding var cropBox: CGRect
    @Binding var customWidth: String
    @Binding var customHeight: String
    
    var imageSize: CGSize
    var onCenter: () -> Void
    var onReset: () -> Void
    var onMaximize: () -> Void
    var onCropBoxChanged: (CGRect) -> Void
    
    // Helper for Picker: Simplified enum without associated values
    private enum RatioSelection: String, CaseIterable, Identifiable {
        case ratio16_9 = "16:9"
        case ratio1_1 = "1:1"
        case custom = "custom"
        
        var id: String { rawValue }
    }
    
    // Computed property for Picker selection
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
            // Target Format Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("TARGET FORMAT")
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
                    Text("1:1 (Square)").tag(RatioSelection.ratio1_1)
                    Text("Custom").tag(RatioSelection.custom)
                }
                .pickerStyle(.radioGroup)
                
                if case .custom = targetRatio {
                    HStack {
                        Text("Width:")
                        TextField("16", text: $customWidth)
                            .frame(width: 60)
                        Text("Height:")
                        TextField("9", text: $customHeight)
                            .frame(width: 60)
                    }
                    .padding(.leading, 20)
                }
            }
            
            Divider()
            
            // Cropping Mode
            VStack(alignment: .leading, spacing: 8) {
                Text("CROPPING MODE")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Picker("Mode", selection: $cropMode) {
                    Text("MCU-Sensitive (Lossless)").tag(CropMode.mcuSensitive)
                    Text("Standard (Fallback)").tag(CropMode.standard)
                }
                .pickerStyle(.radioGroup)
            }
            
            Divider()
            
            // Overlay Guides
            VStack(alignment: .leading, spacing: 8) {
                Text("OVERLAY GUIDES")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Picker("Guide", selection: $activeOverlay) {
                    // None option
                    Text(OverlayGuide.none.displayName)
                        .tag(OverlayGuide.none)
                    
                    // Composition overlays (artistic guides)
                    Text(OverlayGuide.ruleOfThirds.displayName)
                        .tag(OverlayGuide.ruleOfThirds)
                    Text(OverlayGuide.goldenRatio.displayName)
                        .tag(OverlayGuide.goldenRatio)
                    Text(OverlayGuide.fibonacciTopLeft.displayName)
                        .tag(OverlayGuide.fibonacciTopLeft)
                    Text(OverlayGuide.fibonacciTopRight.displayName)
                        .tag(OverlayGuide.fibonacciTopRight)
                    Text(OverlayGuide.fibonacciBottomLeft.displayName)
                        .tag(OverlayGuide.fibonacciBottomLeft)
                    Text(OverlayGuide.fibonacciBottomRight.displayName)
                        .tag(OverlayGuide.fibonacciBottomRight)
                    
                    // MCU Grid (technical overlay) - at the bottom
                    Text(OverlayGuide.mcuGrid.displayName)
                        .tag(OverlayGuide.mcuGrid)
                }
                .pickerStyle(.radioGroup)
                
                // Info text
                if activeOverlay != .none {
                    Text(activeOverlay.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                        .padding(.top, 4)
                }
            }
            
            Divider()
            
            // Position & Fine-Tuning
            VStack(alignment: .leading, spacing: 8) {
                Text("POSITION & FINE-TUNING")
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
                        Text("Width:")
                        Slider(value: Binding(
                            get: { cropBox.width },
                            set: { newValue in
                                var newBox = cropBox
                                // IMPORTANT: Max width based on current X position
                                let maxWidth = imageSize.width - newBox.origin.x
                                newBox.size.width = max(1, min(newValue, maxWidth))
                                // If aspect ratio is locked, adjust height
                                if case .custom = targetRatio {
                                    // Custom: Do nothing
                                } else {
                                    let ratio = targetRatio == .ratio16_9 ? 16.0/9.0 : 1.0
                                    newBox.size.height = newBox.size.width / ratio
                                    // Ensure height doesn't exceed image bounds
                                    let maxHeight = imageSize.height - newBox.origin.y
                                    if newBox.size.height > maxHeight {
                                        newBox.size.height = maxHeight
                                        newBox.size.width = newBox.size.height * ratio
                                    }
                                }
                                onCropBoxChanged(newBox)
                            }
                        ), in: {
                            // With aspect ratio lock: Limit max width by max height AND position
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
                        Text("Height:")
                        Slider(value: Binding(
                            get: { cropBox.height },
                            set: { newValue in
                                var newBox = cropBox
                                // IMPORTANT: Max height based on current Y position
                                let maxHeight = imageSize.height - newBox.origin.y
                                newBox.size.height = max(1, min(newValue, maxHeight))
                                // If aspect ratio is locked, adjust width
                                if case .custom = targetRatio {
                                    // Custom: Do nothing
                                } else {
                                    let ratio = targetRatio == .ratio16_9 ? 16.0/9.0 : 1.0
                                    newBox.size.width = newBox.size.height * ratio
                                    // Ensure width doesn't exceed image bounds
                                    let maxWidth = imageSize.width - newBox.origin.x
                                    if newBox.size.width > maxWidth {
                                        newBox.size.width = maxWidth
                                        newBox.size.height = newBox.size.width / ratio
                                    }
                                }
                                onCropBoxChanged(newBox)
                            }
                        ), in: {
                            // With aspect ratio lock: Limit max height by max width AND position
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
            }
            
            Divider()
            
            // Quick Actions
            VStack(alignment: .leading, spacing: 8) {
                Text("QUICK ACTIONS")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Button("Center", action: onCenter)
                        .buttonStyle(.bordered)
                    Button("Reset", action: onReset)
                        .buttonStyle(.bordered)
                    Button("Maximize", action: onMaximize)
                        .buttonStyle(.bordered)
                }
                
                // Corner Coordinates
                Divider()
                    .padding(.vertical, 8)
                
                Text("CORNER COORDINATES")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                let x1 = Int(cropBox.origin.x)
                let y1 = Int(cropBox.origin.y)
                let x2 = Int(cropBox.origin.x + cropBox.width)
                let y2 = Int(cropBox.origin.y + cropBox.height)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Top Left:       (\(x1), \(y2))")
                        .font(.system(.caption, design: .monospaced))
                    Text("Top Right:      (\(x2), \(y2))")
                        .font(.system(.caption, design: .monospaced))
                    Text("Bottom Left:    (\(x1), \(y1))")
                        .font(.system(.caption, design: .monospaced))
                    Text("Bottom Right:   (\(x2), \(y1))")
                        .font(.system(.caption, design: .monospaced))
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

