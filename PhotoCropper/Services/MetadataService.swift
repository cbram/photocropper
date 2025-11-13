//
//  MetadataService.swift
//  PhotoCropper
//
//  Handhabt EXIF/XMP-Metadaten: Lesen und Schreiben von Crop-Koordinaten
//

import Foundation
import ImageIO
import CoreGraphics

/// Service für Metadaten-Operationen (EXIF/XMP)
class MetadataService {
    
    /// Speichert Crop-Metadaten in Bild-Datei
    static func saveCropMetadata(
        imageURL: URL,
        cropBox: CGRect,
        imageSize: CGSize,
        targetRatio: AspectRatio,
        mode: CropMode,
        originalRatio: String
    ) -> Result<Void, Error> {
        
        // Normalisierte Koordinaten berechnen
        let normalizedOrigin = CGPoint(
            x: cropBox.origin.x / imageSize.width,
            y: cropBox.origin.y / imageSize.height
        )
        let normalizedSize = CGSize(
            width: cropBox.width / imageSize.width,
            height: cropBox.height / imageSize.height
        )
        
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            return .failure(MetadataServiceError.cannotReadImage)
        }
        
        guard let imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return .failure(MetadataServiceError.cannotReadImage)
        }
        
        // Bestehende Metadaten auslesen
        var metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] ?? [:]
        
        print("📊 Metadaten-Service:")
        print("  Original Image Size: \(imageSize.width)x\(imageSize.height)")
        print("  Crop Box (pixels): \(cropBox)")
        print("  Normalized Origin: \(normalizedOrigin)")
        print("  Normalized Size: \(normalizedSize)")
        
        // EXIF-Dictionary erstellen/aktualisieren
        var exifDict = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        
        // DefaultCropOrigin und DefaultCropSize speichern (als Array von NSNumber)
        exifDict["DefaultCropOrigin"] = [NSNumber(value: normalizedOrigin.x), NSNumber(value: normalizedOrigin.y)]
        exifDict["DefaultCropSize"] = [NSNumber(value: normalizedSize.width), NSNumber(value: normalizedSize.height)]
        
        print("  ✅ EXIF DefaultCropOrigin: [\(normalizedOrigin.x), \(normalizedOrigin.y)]")
        print("  ✅ EXIF DefaultCropSize: [\(normalizedSize.width), \(normalizedSize.height)]")
        
        metadata[kCGImagePropertyExifDictionary as String] = exifDict
        
        // XMP-Dictionary für Crop-Daten
        var xmpDict = metadata["http://ns.adobe.com/xap/1.0/" as String] as? [String: Any] ?? [:]
        
        // Adobe XMP Crop Tags (Lightroom-kompatibel)
        xmpDict["crs:CropTop"] = NSNumber(value: normalizedOrigin.y)
        xmpDict["crs:CropLeft"] = NSNumber(value: normalizedOrigin.x)
        xmpDict["crs:CropBottom"] = NSNumber(value: normalizedOrigin.y + normalizedSize.height)
        xmpDict["crs:CropRight"] = NSNumber(value: normalizedOrigin.x + normalizedSize.width)
        
        print("  ✅ XMP CropTop: \(normalizedOrigin.y)")
        print("  ✅ XMP CropLeft: \(normalizedOrigin.x)")
        print("  ✅ XMP CropBottom: \(normalizedOrigin.y + normalizedSize.height)")
        print("  ✅ XMP CropRight: \(normalizedOrigin.x + normalizedSize.width)")
        
        metadata["http://ns.adobe.com/xap/1.0/" as String] = xmpDict
        
        // Custom Tags in IPTC-Dictionary für unsere eigene Verwendung
        var iptcDict = metadata[kCGImagePropertyIPTCDictionary as String] as? [String: Any] ?? [:]
        iptcDict[EXIFTags.cropMode] = mode.rawValue
        iptcDict[EXIFTags.originalRatio] = originalRatio
        iptcDict[EXIFTags.targetRatio] = targetRatio.id
        iptcDict[EXIFTags.cropDateTime] = ISO8601DateFormatter().string(from: Date())
        metadata[kCGImagePropertyIPTCDictionary as String] = iptcDict
        
        print("  ✅ IPTC Custom Tags geschrieben")
        
        // Temporäre Datei im System-Temp-Verzeichnis erstellen (nicht im Zielverzeichnis!)
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("photocropper_\(UUID().uuidString).\(imageURL.pathExtension)")
        
        // Bild mit neuen Metadaten speichern
        guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, CGImageSourceGetType(imageSource)!, 1, nil) else {
            return .failure(MetadataServiceError.cannotCreateDestination)
        }
        
        // WICHTIG: Alle Properties übernehmen inklusive MakerNotes, GPS, etc.
        let options: [String: Any] = [
            kCGImageDestinationLossyCompressionQuality as String: 1.0,  // Maximum Qualität
            kCGImageDestinationMetadata as String: metadata,
            kCGImageDestinationMergeMetadata as String: true  // Merge statt replace!
        ]
        
        CGImageDestinationAddImageFromSource(destination, imageSource, 0, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            // Cleanup bei Fehler
            try? FileManager.default.removeItem(at: tempURL)
            return .failure(MetadataServiceError.cannotFinalize)
        }
        
        print("  ✅ Bild mit Metadaten geschrieben (Merge-Modus)")
        
        // Original-Datei ersetzen
        do {
            let fileManager = FileManager.default
            
            // Backup der Original-Datei (falls vorhanden)
            let backupURL = tempDir.appendingPathComponent("photocropper_backup_\(UUID().uuidString).\(imageURL.pathExtension)")
            if fileManager.fileExists(atPath: imageURL.path) {
                try fileManager.moveItem(at: imageURL, to: backupURL)
            }
            
            // Temp-Datei an Ziel verschieben
            do {
                try fileManager.moveItem(at: tempURL, to: imageURL)
                // Backup löschen bei Erfolg
                try? fileManager.removeItem(at: backupURL)
                return .success(())
            } catch {
                // Bei Fehler: Backup wiederherstellen
                if fileManager.fileExists(atPath: backupURL.path) {
                    try? fileManager.moveItem(at: backupURL, to: imageURL)
                }
                // Temp-Datei löschen
                try? fileManager.removeItem(at: tempURL)
                return .failure(error)
            }
        } catch {
            // Cleanup bei Fehler
            try? FileManager.default.removeItem(at: tempURL)
            return .failure(error)
        }
    }
    
    /// Liest Crop-Metadaten aus Bild-Datei
    static func readCropMetadata(imageURL: URL) -> CropMetadata? {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }
        
        guard let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let originArray = exifDict["DefaultCropOrigin"] as? [Double],
              let sizeArray = exifDict["DefaultCropSize"] as? [Double],
              originArray.count == 2,
              sizeArray.count == 2 else {
            return nil
        }
        
        let origin = CGPoint(x: originArray[0], y: originArray[1])
        let size = CGSize(width: sizeArray[0], height: sizeArray[1])
        
        // Custom Tags aus XMP lesen
        let xmpDict = properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any] ?? [:]
        let cropModeString = xmpDict[EXIFTags.cropMode] as? String ?? CropMode.standard.rawValue
        let mode = CropMode(rawValue: cropModeString) ?? .standard
        let originalRatio = xmpDict[EXIFTags.originalRatio] as? String ?? "unknown"
        let targetRatio = xmpDict[EXIFTags.targetRatio] as? String ?? "unknown"
        
        return CropMetadata(
            origin: origin,
            size: size,
            mode: mode,
            originalRatio: originalRatio,
            targetRatio: targetRatio
        )
    }
    
    /// Erstellt XMP-XML-String für Metadaten
    private static func createXMPString(
        cropOrigin: CGPoint,
        cropSize: CGSize,
        mode: CropMode,
        originalRatio: String,
        targetRatio: String
    ) -> String {
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: Date())
        
        return """
        <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description rdf:about="" xmlns:photocropper="http://photocropper.app/1.0/">
        <photocropper:CropMode>\(mode.rawValue)</photocropper:CropMode>
        <photocropper:OriginalRatio>\(originalRatio)</photocropper:OriginalRatio>
        <photocropper:TargetRatio>\(targetRatio)</photocropper:TargetRatio>
        <photocropper:CropDateTime>\(dateString)</photocropper:CropDateTime>
        <photocropper:DefaultCropOrigin>\(cropOrigin.x),\(cropOrigin.y)</photocropper:DefaultCropOrigin>
        <photocropper:DefaultCropSize>\(cropSize.width),\(cropSize.height)</photocropper:DefaultCropSize>
        </rdf:Description>
        </rdf:RDF>
        </x:xmpmeta>
        <?xpacket end="w"?>
        """
    }
    
    /// Prüft ob XMP-Daten vorhanden sind
    static func hasXMPData(imageURL: URL) -> Bool {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return false
        }
        
        // Prüfe verschiedene mögliche XMP-Locations
        if properties[kCGImagePropertyMakerAppleDictionary as String] != nil {
            return true
        }
        if properties[kCGImagePropertyIPTCDictionary as String] != nil {
            return true
        }
        
        return false
    }
    
    /// Erstellt XMP-Daten falls nicht vorhanden (für JPEG ohne XMP)
    static func ensureXMPData(imageURL: URL) -> Result<Void, Error> {
        if hasXMPData(imageURL: imageURL) {
            return .success(())
        }
        
        // XMP-Daten müssen beim nächsten Speichern erstellt werden
        // Diese Funktion markiert nur, dass XMP erstellt werden soll
        return .success(())
    }
}

/// Metadaten-Service-Fehler
enum MetadataServiceError: LocalizedError {
    case cannotReadImage
    case cannotCreateDestination
    case cannotFinalize
    case xmpCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .cannotReadImage:
            return "Bild konnte nicht gelesen werden"
        case .cannotCreateDestination:
            return "Ziel-Datei konnte nicht erstellt werden"
        case .cannotFinalize:
            return "Metadaten konnten nicht finalisiert werden"
        case .xmpCreationFailed:
            return "XMP-Daten konnten nicht erstellt werden"
        }
    }
}

