//
//  PreviewView.swift
//  PhotoCropper
//
//  Kleine Vorschau des finalen Crops
//

import SwiftUI
import AppKit

struct PreviewView: View {
    var image: NSImage?
    var cropBox: CGRect
    var imageSize: CGSize
    var targetRatio: AspectRatio
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PREVIEW \(targetRatio.id.uppercased())")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if let image = image, let croppedImage = cropImage(image, cropBox: cropBox, imageSize: imageSize) {
                GeometryReader { geometry in
                    let previewSize = calculatePreviewSize(in: geometry.size)
                    let currentRatio = cropBox.width / cropBox.height
                    let targetRatioValue = targetRatio.value
                    let deviation = abs(currentRatio - targetRatioValue)
                    
                    ZStack {
                        // Gecropptes Bild-Preview
                        Image(nsImage: croppedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: previewSize.width, height: previewSize.height)
                            .clipped()
                        
                        // Border around the preview
                        Rectangle()
                            .stroke(currentRatio == targetRatioValue ? Color.green : Color.orange, lineWidth: 2)
                            .frame(width: previewSize.width, height: previewSize.height)
                        
                        // Abweichungs-Indikator
                        if deviation > 0.01 {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Text(String(format: "Δ %.2f%%", deviation / targetRatioValue * 100))
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Color.orange.opacity(0.8))
                                        .cornerRadius(4)
                                        .padding(4)
                                }
                            }
                        }
                    }
                }
                .frame(height: 150)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 150)
                    .overlay(
                        Text("Kein Bild geladen")
                            .foregroundColor(.secondary)
                    )
            }
            
            // Ratio-Vergleich
            let currentRatio = cropBox.width / cropBox.height
            let targetRatioValue = targetRatio.value
            HStack {
                Text("Aktuell: \(Int(cropBox.width))×\(Int(cropBox.height))")
                    .font(.caption)
                    .foregroundColor(abs(currentRatio - targetRatioValue) < 0.01 ? .green : .orange)
                Spacer()
                Text(String(format: "%.2f:1", currentRatio))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption2)
                Text("Grün = Zielformat")
                Spacer()
                Image(systemName: "square")
                    .foregroundColor(.red)
                    .font(.caption2)
                Text("Rot = Aktuell")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private func calculatePreviewSize(in availableSize: CGSize) -> CGSize {
        let cropAspect = cropBox.width / cropBox.height
        let availableAspect = availableSize.width / availableSize.height
        
        if cropAspect > availableAspect {
            // Crop is wider → width determines size
            let width = availableSize.width
            let height = width / cropAspect
            return CGSize(width: width, height: height)
        } else {
            // Crop is taller → height determines size
            let height = availableSize.height
            let width = height * cropAspect
            return CGSize(width: width, height: height)
        }
    }
    
    private func cropImage(_ image: NSImage, cropBox: CGRect, imageSize: CGSize) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // Berechne Scale-Faktor (falls Bild skaliert wurde)
        let scaleX = CGFloat(cgImage.width) / imageSize.width
        let scaleY = CGFloat(cgImage.height) / imageSize.height
        
        // Crop-Rect in CGImage-Koordinaten umrechnen
        let scaledCropRect = CGRect(
            x: cropBox.origin.x * scaleX,
            y: cropBox.origin.y * scaleY,
            width: cropBox.width * scaleX,
            height: cropBox.height * scaleY
        )
        
        // Crop durchführen
        guard let croppedCGImage = cgImage.cropping(to: scaledCropRect) else {
            return nil
        }
        
        // Zurück zu NSImage konvertieren
        let croppedImage = NSImage(cgImage: croppedCGImage, size: NSSize(width: cropBox.width, height: cropBox.height))
        return croppedImage
    }
}

