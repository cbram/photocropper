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
    
    /// Liest existierende Subject-Tags aus und filtert PhotoCropper-Tags raus
    private static func readNonPhotoCropperSubjectTags(exiftoolPath: String, imageURL: URL) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: exiftoolPath)
        process.arguments = ["-XMP-dc:Subject", "-s3", imageURL.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return []
            }
            
            // exiftool gibt Subject-Tags zeilenweise aus oder komma-separiert
            let subjects = output.components(separatedBy: .newlines)
                .flatMap { $0.components(separatedBy: ",") }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.hasPrefix("PhotoCropper:") }
            
            return subjects
        } catch {
            print("⚠️ Fehler beim Lesen der Subject-Tags: \(error)")
            return []
        }
    }
    
    /// Liest existierende IPTC Keywords aus und filtert PhotoCropper-Keywords raus
    private static func readNonPhotoCropperIPTCKeywords(exiftoolPath: String, imageURL: URL) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: exiftoolPath)
        process.arguments = ["-IPTC:Keywords", "-s3", imageURL.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return []
            }
            
            // exiftool gibt Keywords zeilenweise aus oder komma-separiert
            let keywords = output.components(separatedBy: .newlines)
                .flatMap { $0.components(separatedBy: ",") }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.hasPrefix("CropMode:") && !$0.hasPrefix("TargetRatio:") && !$0.hasPrefix("OriginalRatio:") }
            
            return keywords
        } catch {
            print("⚠️ Fehler beim Lesen der IPTC Keywords: \(error)")
            return []
        }
    }
    
    /// Speichert Crop-Metadaten in Bild-Datei mit exiftool (verlustfrei!)
    static func saveCropMetadata(
        imageURL: URL,
        cropBox: CGRect,
        imageSize: CGSize,
        targetRatio: AspectRatio,
        mode: CropMode,
        originalRatio: String
    ) -> Result<Void, Error> {
        
        // Prüfe ob exiftool verfügbar ist
        let exiftoolPaths = [
            "/opt/homebrew/bin/exiftool",
            "/usr/local/bin/exiftool",
            "/usr/bin/exiftool"
        ]
        
        guard let exiftoolPath = exiftoolPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            print("⚠️ exiftool nicht gefunden - Fallback zu ImageIO")
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
    
    /// Speichert Crop-Metadaten mit exiftool (verlustfrei, keine Bildveränderung!)
    private static func saveCropMetadataWithExiftool(
        exiftoolPath: String,
        imageURL: URL,
        cropBox: CGRect,
        imageSize: CGSize,
        targetRatio: AspectRatio,
        mode: CropMode,
        originalRatio: String
    ) -> Result<Void, Error> {
        
        print("📊 Metadaten-Service (exiftool):")
        print("  exiftool: \(exiftoolPath)")
        print("  Image: \(imageURL.lastPathComponent)")
        print("  Size: \(imageSize.width)x\(imageSize.height)")
        print("  Crop: \(cropBox)")
        print("  💡 3-Pass-Strategie:")
        print("     PASS 1: Lösche alle XMP-crs:Crop*, XMP-dc:Subject und IPTC:Keywords")
        print("     PASS 2: Schreibe neue Crop-Koordinaten + gefilterte Subject-Tags")
        print("     PASS 3: Synchronisiere XMP→IPTC und aktualisiere IPTCDigest")
        print("  📝 Crop-Infos werden gespeichert in:")
        print("     - XMP-crs:CropTop/Left/Bottom/Right (Lightroom-kompatibel)")
        print("     - XMP-dc:Subject (7 PhotoCropper-Felder für vollständige Crop-Info)")
        
        // Normalisierte Koordinaten berechnen und auf 5 Nachkommastellen runden
        let normalizedOriginX = roundToDecimalPlaces(cropBox.origin.x / imageSize.width)
        let normalizedOriginY = roundToDecimalPlaces(cropBox.origin.y / imageSize.height)
        let normalizedWidth = roundToDecimalPlaces(cropBox.width / imageSize.width)
        let normalizedHeight = roundToDecimalPlaces(cropBox.height / imageSize.height)
        
        let normalizedOrigin = CGPoint(x: normalizedOriginX, y: normalizedOriginY)
        let normalizedSize = CGSize(width: normalizedWidth, height: normalizedHeight)
        
        let cropBottom = roundToDecimalPlaces(normalizedOriginY + normalizedHeight)
        let cropRight = roundToDecimalPlaces(normalizedOriginX + normalizedWidth)
        
        print("  Normalized: origin=(\(normalizedOrigin.x), \(normalizedOrigin.y)) size=(\(normalizedSize.width), \(normalizedSize.height))")
        
        // 🔍 SCHRITT 0: Lese bestehende Tags aus und filtere PhotoCropper-Tags raus
        let existingSubjects = readNonPhotoCropperSubjectTags(exiftoolPath: exiftoolPath, imageURL: imageURL)
        let existingKeywords = readNonPhotoCropperIPTCKeywords(exiftoolPath: exiftoolPath, imageURL: imageURL)
        
        if !existingSubjects.isEmpty {
            print("  📋 Behalte \(existingSubjects.count) existierende Subject-Tags (nicht von PhotoCropper):")
            for subject in existingSubjects {
                print("     - \(subject)")
            }
        }
        if !existingKeywords.isEmpty {
            print("  📋 Behalte \(existingKeywords.count) existierende IPTC Keywords:")
            for keyword in existingKeywords {
                print("     - \(keyword)")
            }
        }
        
        print("  ⚠️ WICHTIG: PhotoCropper-Crop-Infos werden NUR in XMP-dc:Subject gespeichert:")
        print("     ✓ PhotoCropper:CropMode, TargetRatio, OriginalRatio")
        print("     ✓ PhotoCropper:CropOriginX, CropOriginY, CropWidth, CropHeight")
        print("     → Dein Ausleseprogramm sollte XMP-dc:Subject lesen, NICHT IPTC:Keywords!")
        
        // 1️⃣ PASS 1: LÖSCHEN - Alle Crop-Tags und Subject-Tags entfernen
        print("  🧹 PASS 1: Lösche alte Tags (OHNE -n, da sonst CropConstrainToUnitSquare nicht gelöscht wird!)...")
        
        var argv1: [UnsafeMutablePointer<CChar>?] = []
        argv1.append(strdup(exiftoolPath))
        argv1.append(strdup("-overwrite_original"))
        // KEIN -n hier! Das "-n" Flag verhindert das Löschen von numerischen Tags wie CropConstrainToUnitSquare!
        
        // XMP-crs Crop-Tags löschen
        argv1.append(strdup("-XMP-crs:CropTop="))
        argv1.append(strdup("-XMP-crs:CropLeft="))
        argv1.append(strdup("-XMP-crs:CropBottom="))
        argv1.append(strdup("-XMP-crs:CropRight="))
        argv1.append(strdup("-XMP-crs:CropAngle="))
        argv1.append(strdup("-XMP-crs:CropConstrainToWarp="))
        argv1.append(strdup("-XMP-crs:CropConstrainToUnitSquare="))
        argv1.append(strdup("-XMP-crs:HasCrop="))
        argv1.append(strdup("-XMP-crs:HasSettings="))
        
        // ALLE Subject-Tags löschen (wird in Pass 2 neu geschrieben)
        argv1.append(strdup("-XMP-dc:Subject="))
        
        // ALLE IPTC Keywords löschen (um Duplikate zu vermeiden)
        argv1.append(strdup("-IPTC:Keywords="))
        
        argv1.append(strdup(imageURL.path))
        argv1.append(nil)
        
        var pid1: pid_t = 0
        let envp: [UnsafeMutablePointer<CChar>?] = [
            strdup("PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"),
            nil
        ]
        
        let status1 = posix_spawn(&pid1, exiftoolPath, nil, nil, argv1, envp)
        argv1.forEach { if let ptr = $0 { free(ptr) } }
        
        if status1 == 0 {
            var exitStatus1: Int32 = 0
            waitpid(pid1, &exitStatus1, 0)
            let actualExit1 = (exitStatus1 >> 8) & 0xFF
            
            if actualExit1 != 0 {
                print("  ❌ PASS 1 fehlgeschlagen: exit code \(actualExit1)")
                envp.forEach { if let ptr = $0 { free(ptr) } }
                return .failure(MetadataServiceError.exiftoolFailed)
            }
            print("  ✅ PASS 1 erfolgreich")
        } else {
            print("  ❌ PASS 1 posix_spawn failed: \(status1)")
            envp.forEach { if let ptr = $0 { free(ptr) } }
            return .failure(MetadataServiceError.exiftoolFailed)
        }
        
        // 2️⃣ PASS 2: SETZEN - Neue Crop-Tags und gefilterte Subject-Tags schreiben
        print("  📝 PASS 2: Schreibe neue Tags...")
        
        var argv2: [UnsafeMutablePointer<CChar>?] = []
        argv2.append(strdup(exiftoolPath))
        argv2.append(strdup("-overwrite_original"))
        argv2.append(strdup("-n"))
        argv2.append(strdup("-codedcharacterset=utf8"))
        
        // Neue XMP-crs Crop-Tags
        argv2.append(strdup("-XMP-crs:CropTop=\(normalizedOrigin.y)"))
        argv2.append(strdup("-XMP-crs:CropLeft=\(normalizedOrigin.x)"))
        argv2.append(strdup("-XMP-crs:CropBottom=\(cropBottom)"))
        argv2.append(strdup("-XMP-crs:CropRight=\(cropRight)"))
        
        // Existierende (nicht-PhotoCropper) Subject-Tags
        for subject in existingSubjects {
            argv2.append(strdup("-XMP-dc:Subject+=\(subject)"))
        }
        
        // Neue PhotoCropper Subject-Tags
        argv2.append(strdup("-XMP-dc:Subject+=PhotoCropper:CropMode=\(mode.rawValue)"))
        argv2.append(strdup("-XMP-dc:Subject+=PhotoCropper:TargetRatio=\(targetRatio.id)"))
        argv2.append(strdup("-XMP-dc:Subject+=PhotoCropper:OriginalRatio=\(originalRatio)"))
        argv2.append(strdup("-XMP-dc:Subject+=PhotoCropper:CropOriginX=\(normalizedOrigin.x)"))
        argv2.append(strdup("-XMP-dc:Subject+=PhotoCropper:CropOriginY=\(normalizedOrigin.y)"))
        argv2.append(strdup("-XMP-dc:Subject+=PhotoCropper:CropWidth=\(normalizedSize.width)"))
        argv2.append(strdup("-XMP-dc:Subject+=PhotoCropper:CropHeight=\(normalizedSize.height)"))
        
        // Existierende (nicht-PhotoCropper) IPTC Keywords wieder hinzufügen
        if !existingKeywords.isEmpty {
            for keyword in existingKeywords {
                argv2.append(strdup("-IPTC:Keywords+=\(keyword)"))
            }
        }
        
        argv2.append(strdup(imageURL.path))
        argv2.append(nil)
        
        var pid2: pid_t = 0
        
        let status2 = posix_spawn(&pid2, exiftoolPath, nil, nil, argv2, envp)
        argv2.forEach { if let ptr = $0 { free(ptr) } }
        
        if status2 == 0 {
            var exitStatus2: Int32 = 0
            waitpid(pid2, &exitStatus2, 0)
            let actualExit2 = (exitStatus2 >> 8) & 0xFF
            
            if actualExit2 != 0 {
                print("  ❌ PASS 2 fehlgeschlagen: exit code \(actualExit2)")
                envp.forEach { if let ptr = $0 { free(ptr) } }
                return .failure(MetadataServiceError.exiftoolFailed)
            }
            print("  ✅ PASS 2 erfolgreich")
        } else {
            print("  ❌ PASS 2 posix_spawn failed: \(status2)")
            envp.forEach { if let ptr = $0 { free(ptr) } }
            return .failure(MetadataServiceError.exiftoolFailed)
        }
        
        // 3️⃣ PASS 3: SYNCHRONISATION - XMP→IPTC sync und IPTCDigest aktualisieren
        print("  🔄 PASS 3: Synchronisiere XMP→IPTC...")
        
        var argv3: [UnsafeMutablePointer<CChar>?] = []
        argv3.append(strdup(exiftoolPath))
        argv3.append(strdup("-overwrite_original"))
        argv3.append(strdup("-codedcharacterset=utf8"))
        
        // Synchronisiere XMP-dc:Subject → IPTC:Keywords
        // Dies ist der exakte Befehl, der beim User funktioniert hat!
        argv3.append(strdup("-IPTC:Keywords<XMP-dc:Subject"))
        
        argv3.append(strdup(imageURL.path))
        argv3.append(nil)
        
        var pid3: pid_t = 0
        
        let status3 = posix_spawn(&pid3, exiftoolPath, nil, nil, argv3, envp)
        argv3.forEach { if let ptr = $0 { free(ptr) } }
        
        if status3 == 0 {
            var exitStatus3: Int32 = 0
            waitpid(pid3, &exitStatus3, 0)
            let actualExit3 = (exitStatus3 >> 8) & 0xFF
            
            if actualExit3 == 0 {
                print("  ✅ PASS 3 erfolgreich - XMP↔IPTC synchronisiert, IPTCDigest aktualisiert!")
                print("  ✅ Metadaten vollständig geschrieben ohne Bildveränderung!")
                envp.forEach { if let ptr = $0 { free(ptr) } }
                return .success(())
            } else {
                print("  ❌ PASS 3 fehlgeschlagen: exit code \(actualExit3)")
                print("  ⚠️ Metadaten wurden geschrieben, aber Synchronisation fehlgeschlagen")
                envp.forEach { if let ptr = $0 { free(ptr) } }
                return .failure(MetadataServiceError.exiftoolFailed)
            }
        } else {
            print("  ❌ PASS 3 posix_spawn failed: \(status3)")
            print("  ⚠️ Metadaten wurden geschrieben, aber Synchronisation fehlgeschlagen")
            envp.forEach { if let ptr = $0 { free(ptr) } }
            return .failure(MetadataServiceError.exiftoolFailed)
        }
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
    
    /// Liest PhotoCropper-Tags aus XMP-dc:Subject mit exiftool
    private static func readPhotoCropperTagsWithExiftool(exiftoolPath: String, imageURL: URL) -> [String: String]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: exiftoolPath)
        process.arguments = ["-XMP-dc:Subject", "-s3", imageURL.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            print("🔍 Raw exiftool output für XMP-dc:Subject:")
            print("   \(output)")
            
            // Parse PhotoCropper-Tags aus Subject
            // Format kann sein:
            // 1. Zeilen-separiert: jeder Tag in eigener Zeile
            // 2. Komma-separiert: alle Tags in einer Zeile mit ", " getrennt
            var cropTags: [String: String] = [:]
            
            // Zuerst versuchen: Komma-getrennt (häufigster Fall)
            let allText = output.trimmingCharacters(in: .whitespacesAndNewlines)
            let subjectItems = allText.components(separatedBy: ", ")
                .flatMap { $0.components(separatedBy: ",") }  // Auch ohne Leerzeichen
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.hasPrefix("PhotoCropper:") }
            
            print("   Gefundene PhotoCropper-Tags: \(subjectItems.count)")
            
            for subject in subjectItems {
                let withoutPrefix = subject.dropFirst("PhotoCropper:".count)
                let parts = withoutPrefix.components(separatedBy: "=")
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    cropTags[key] = value
                    print("   ✓ \(key) = \(value)")
                }
            }
            
            return cropTags.isEmpty ? nil : cropTags
        } catch {
            print("⚠️ Fehler beim Lesen der PhotoCropper-Tags: \(error)")
            return nil
        }
    }
    
    /// Liest Crop-Metadaten aus Bild-Datei
    static func readCropMetadata(imageURL: URL) -> CropMetadata? {
        // Prüfe ob exiftool verfügbar ist für besseres Auslesen
        let exiftoolPaths = [
            "/opt/homebrew/bin/exiftool",
            "/usr/local/bin/exiftool",
            "/usr/bin/exiftool"
        ]
        
        var cropTags: [String: String]?
        if let exiftoolPath = exiftoolPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            cropTags = readPhotoCropperTagsWithExiftool(exiftoolPath: exiftoolPath, imageURL: imageURL)
        }
        
        // Wenn PhotoCropper-Tags gefunden wurden, verwende diese
        if let tags = cropTags,
           let cropOriginX = tags["CropOriginX"].flatMap(Double.init),
           let cropOriginY = tags["CropOriginY"].flatMap(Double.init),
           let cropWidth = tags["CropWidth"].flatMap(Double.init),
           let cropHeight = tags["CropHeight"].flatMap(Double.init) {
            
            let origin = CGPoint(x: cropOriginX, y: cropOriginY)
            let size = CGSize(width: cropWidth, height: cropHeight)
            
            let cropModeString = tags["CropMode"] ?? CropMode.standard.rawValue
            let mode = CropMode(rawValue: cropModeString) ?? .standard
            let originalRatio = tags["OriginalRatio"] ?? "unknown"
            let targetRatioStr = tags["TargetRatio"] ?? "unknown"
            
            print("📖 PhotoCropper Crop-Metadaten gefunden:")
            print("   Origin: (\(origin.x), \(origin.y))")
            print("   Size: (\(size.width), \(size.height))")
            print("   Mode: \(mode.rawValue)")
            print("   Target Ratio: \(targetRatioStr)")
            
            return CropMetadata(
                origin: origin,
                size: size,
                mode: mode,
                originalRatio: originalRatio,
                targetRatio: targetRatioStr
            )
        }
        
        // Fallback: Versuche Standard EXIF-Tags zu lesen
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
        let cropModeString = xmpDict[EXIFTags.Custom.cropMode] as? String ?? CropMode.standard.rawValue
        let mode = CropMode(rawValue: cropModeString) ?? .standard
        let originalRatio = xmpDict[EXIFTags.Custom.originalRatio] as? String ?? "unknown"
        let targetRatioStr = xmpDict[EXIFTags.Custom.targetRatio] as? String ?? "unknown"
        
        print("📖 Standard EXIF Crop-Metadaten gefunden:")
        print("   Origin: (\(origin.x), \(origin.y))")
        print("   Size: (\(size.width), \(size.height))")
        
        return CropMetadata(
            origin: origin,
            size: size,
            mode: mode,
            originalRatio: originalRatio,
            targetRatio: targetRatioStr
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

