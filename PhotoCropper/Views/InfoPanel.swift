//
//  InfoPanel.swift
//  PhotoCropper
//
//  Zeigt Metadaten-Informationen an
//

import SwiftUI

struct InfoPanel: View {
    var imageData: ImageData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BILD-INFORMATIONEN")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if let imageData = imageData {
                VStack(alignment: .leading, spacing: 6) {
                    InfoRow(label: "Dimensionen:", value: "\(Int(imageData.pixelSize.width))x\(Int(imageData.pixelSize.height))")
                    InfoRow(label: "Ratio:", value: imageData.aspectRatioString)
                    InfoRow(label: "Format:", value: formatString(imageData.format))
                    
                    if let creationDate = imageData.creationDate {
                        InfoRow(label: "Erstellt:", value: formatDate(creationDate))
                    }
                    
                    if let mcuSize = imageData.mcuSize {
                        InfoRow(label: "MCU-Größe:", value: "\(Int(mcuSize.width))x\(Int(mcuSize.height))")
                    }
                }
            } else {
                Text("Kein Bild geladen")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private func formatString(_ format: ImageFormat) -> String {
        switch format {
        case .jpeg:
            return "JPEG"
        case .heic:
            return "HEIC"
        case .png:
            return "PNG"
        case .tiff:
            return "TIFF"
        case .unknown:
            return "Unbekannt"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

