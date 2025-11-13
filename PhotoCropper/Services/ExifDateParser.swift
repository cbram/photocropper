//
//  ExifDateParser.swift
//  PhotoCropper
//
//  Extrahiert Erstellungsdatum aus EXIF für Dateinamen-Generierung
//

import Foundation

/// Service für EXIF-Datum-Parsing
class ExifDateParser {
    
    /// Generiert Dateinamen aus EXIF-Erstellungsdatum
    static func generateFilename(
        from imageData: ImageData,
        suffix: String = ""
    ) -> String {
        let date: Date
        
        if let creationDate = imageData.creationDate {
            date = creationDate
        } else {
            // Fallback: Modifikationsdatum der Datei
            if let attributes = try? FileManager.default.attributesOfItem(atPath: imageData.url.path),
               let modificationDate = attributes[.modificationDate] as? Date {
                date = modificationDate
            } else {
                // Fallback: Aktuelle Zeit
                date = Date()
            }
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = formatter.string(from: date)
        
        let extensionString = imageData.url.pathExtension.lowercased()
        
        if suffix.isEmpty {
            return "\(dateString).\(extensionString)"
        } else {
            return "\(dateString)_\(suffix).\(extensionString)"
        }
    }
    
    /// Generiert Suffix basierend auf Ziel-Ratio
    static func suffixForRatio(_ ratio: AspectRatio) -> String {
        switch ratio {
        case .ratio16_9:
            return "16-9"
        case .ratio1_1:
            return "1-1"
        case .custom(let w, let h):
            return "\(w)-\(h)"
        }
    }
}

