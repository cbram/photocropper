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
                    
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: previewSize.width, height: previewSize.height)
                        .clipped()
                        .overlay(
                            Rectangle()
                                .stroke(Color.red, lineWidth: 2)
                                .frame(width: previewSize.width, height: previewSize.height)
                        )
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
            
            Text("Final: \(Int(cropBox.width))x\(Int(cropBox.height))")
                .font(.caption)
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

