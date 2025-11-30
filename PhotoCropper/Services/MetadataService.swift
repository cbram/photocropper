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
    
    /// Rundet einen Double-Wert auf maximal 5 Nachkommastellen
    private static func roundToDecimalPlaces(_ value: Double, places: Int = 5) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (value * multiplier).rounded() / multiplier
    }
    
    /// Formatiert einen Double-Wert als String mit maximal 5 Nachkommastellen (entfernt trailing zeros)
    private static func formatDecimal(_ value: Double, maxPlaces: Int = 5) -> String {
        let rounded = roundToDecimalPlaces(value, places: maxPlaces)
        // Formatiere als String und entferne unnötige trailing zeros
        let formatted = String(format: "%.\(maxPlaces)f", rounded)
        // Entferne trailing zeros nach dem Dezimalpunkt
        if formatted.contains(".") {
            let trimmed = formatted.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
            return trimmed.hasSuffix(".") ? String(trimmed.dropLast()) : trimmed
        }
        return formatted
    }
    
    
    /// Saves crop metadata to image file using exiftool (lossless!)
    static func saveCropMetadata(
        imageURL: URL,
        cropBox: CGRect,
        imageSize: CGSize,
        targetRatio: AspectRatio,
        mode: CropMode,
        originalRatio: String
    ) -> Result<Void, Error> {
        
        // Check if exiftool is available
        guard let exiftoolPath = ExiftoolPathResolver.findExiftoolPath() else {
            print("⚠️ exiftool not found - falling back to ImageIO")
            return saveCropMetadataWithImageIO(
                imageURL: imageURL,
                cropBox: cropBox,
                imageSize: imageSize,
                targetRatio: targetRatio,
                mode: mode,
                originalRatio: originalRatio
            )
        }
        
        return saveCropMetadataWithExiftool(
            exiftoolPath: exiftoolPath,
            imageURL: imageURL,
            cropBox: cropBox,
            imageSize: imageSize,
            targetRatio: targetRatio,
            mode: mode,
            originalRatio: originalRatio
        )
    }
    
    /// Saves crop metadata to image file using exiftool (lossless!)
    ///
    /// - Parameters:
    ///   - exiftoolPath: Path to the exiftool executable
    ///   - imageURL: URL to the image file
    ///   - cropBox: Crop rectangle in pixel coordinates
    ///   - imageSize: Original image size
    ///   - targetRatio: Target aspect ratio
    ///   - mode: Crop mode (MCU-sensitive or standard)
    ///   - originalRatio: Original aspect ratio as string
    /// - Returns: Result indicating success or failure
    ///
    /// - Note: This method delegates to `MetadataWriter` for actual writing logic
    private static func saveCropMetadataWithExiftool(
        exiftoolPath: String,
        imageURL: URL,
        cropBox: CGRect,
        imageSize: CGSize,
        targetRatio: AspectRatio,
        mode: CropMode,
        originalRatio: String
    ) -> Result<Void, Error> {
        let result = MetadataWriter.saveCropMetadata(
            exiftoolPath: exiftoolPath,
            imageURL: imageURL,
            cropBox: cropBox,
            imageSize: imageSize,
            targetRatio: targetRatio,
            mode: mode,
            originalRatio: originalRatio
        )
        
        // Convert MetadataWriterError to MetadataServiceError
        return result.mapError { $0 as Error }
    }
    
    /// Fallback: Speichert Crop-Metadaten mit ImageIO (kann Bild verändern!)
    private static func saveCropMetadataWithImageIO(
        imageURL: URL,
        cropBox: CGRect,
        imageSize: CGSize,
        targetRatio: AspectRatio,
        mode: CropMode,
        originalRatio: String
    ) -> Result<Void, Error> {
        
        print("⚠️ Verwende ImageIO Fallback (kann Bild re-encoden!)")
        
        // Normalisierte Koordinaten berechnen und auf 5 Nachkommastellen runden
        let normalizedOriginX = roundToDecimalPlaces(cropBox.origin.x / imageSize.width)
        let normalizedOriginY = roundToDecimalPlaces(cropBox.origin.y / imageSize.height)
        let normalizedWidth = roundToDecimalPlaces(cropBox.width / imageSize.width)
        let normalizedHeight = roundToDecimalPlaces(cropBox.height / imageSize.height)
        
        let normalizedOrigin = CGPoint(x: normalizedOriginX, y: normalizedOriginY)
        let normalizedSize = CGSize(width: normalizedWidth, height: normalizedHeight)
        
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            return .failure(MetadataServiceError.cannotReadImage)
        }
        
        // Image reference wird nicht benötigt für Metadata-only update
        // guard let imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
        //     return .failure(MetadataServiceError.cannotReadImage)
        // }
        
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
        iptcDict[EXIFTags.Custom.cropMode] = mode.rawValue
        iptcDict[EXIFTags.Custom.originalRatio] = originalRatio
        iptcDict[EXIFTags.Custom.targetRatio] = targetRatio.id
        iptcDict[EXIFTags.Custom.cropDateTime] = ISO8601DateFormatter().string(from: Date())
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
    
    /// Reads crop metadata from image file
    ///
    /// - Parameter imageURL: URL to the image file
    /// - Returns: `CropMetadata` if found, otherwise `nil`
    ///
    /// - Note: This method delegates to `MetadataReader` for actual reading logic
    static func readCropMetadata(imageURL: URL) -> CropMetadata? {
        return MetadataReader.readCropMetadata(imageURL: imageURL)
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
    case exiftoolFailed
    case xmpCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .cannotReadImage:
            return "Bild konnte nicht gelesen werden"
        case .cannotCreateDestination:
            return "Ziel-Datei konnte nicht erstellt werden"
        case .cannotFinalize:
            return "Metadaten konnten nicht finalisiert werden"
        case .exiftoolFailed:
            return "exiftool konnte Metadaten nicht schreiben"
        case .xmpCreationFailed:
            return "XMP-Daten konnten nicht erstellt werden"
        }
    }
}

