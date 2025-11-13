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
            
            if let image = image {
                GeometryReader { geometry in
                    let previewSize = calculatePreviewSize(in: geometry.size)
                    let currentRatio = cropBox.width / cropBox.height
                    let targetRatioValue = targetRatio.value
                    let deviation = abs(currentRatio - targetRatioValue)
                    
                    ZStack {
                        // Bild-Preview
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: previewSize.width, height: previewSize.height)
                            .clipped()
                        
                        // Zielformat-Overlay (gestrichelt)
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                            .foregroundColor(Color.green.opacity(0.8))
                            .frame(width: previewSize.width, height: previewSize.height)
                        
                        // Aktuelles Format (rot, durchgezogen)
                        Rectangle()
                            .stroke(Color.red, lineWidth: 2)
                            .frame(
                                width: previewSize.width,
                                height: previewSize.width / CGFloat(currentRatio)
                            )
                        
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
        let targetAspect = targetRatio.value
        let availableAspect = availableSize.width / availableSize.height
        
        if targetAspect > availableAspect {
            // Ziel ist breiter → Breite bestimmt Größe
            let width = availableSize.width
            let height = width / CGFloat(targetAspect)
            return CGSize(width: width, height: height)
        } else {
            // Ziel ist höher → Höhe bestimmt Größe
            let height = availableSize.height
            let width = height * CGFloat(targetAspect)
            return CGSize(width: width, height: height)
        }
    }
}

