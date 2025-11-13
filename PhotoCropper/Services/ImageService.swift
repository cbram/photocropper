//
//  ImageService.swift
//  PhotoCropper
//
//  Service für Bild-Laden, Orientierung, Format-Erkennung
//

import Foundation
import AppKit
import CoreGraphics
import ImageIO

/// Service für Bild-Operationen
class ImageService {
    
    /// Lädt ein Bild und erstellt ImageData-Objekt
    static func loadImage(from url: URL) -> ImageData? {
        return ImageData(url: url)
    }
    
    /// Lädt mehrere Bilder (für Batch-Processing)
    static func loadImages(from urls: [URL]) -> [ImageData] {
        return urls.compactMap { ImageData(url: $0) }
    }
    
    /// Konvertiert HEIC zu JPEG (optional, für MCU-Cropping)
    static func convertHEICToJPEG(heicURL: URL, outputURL: URL) -> Result<Void, Error> {
        guard let imageSource = CGImageSourceCreateWithURL(heicURL as CFURL, nil),
              let imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return .failure(ImageServiceError.cannotReadImage)
        }
        
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            return .failure(ImageServiceError.cannotCreateDestination)
        }
        
        // Metadaten übernehmen
        let metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
        
        CGImageDestinationAddImage(destination, imageRef, metadata)
        
        guard CGImageDestinationFinalize(destination) else {
            return .failure(ImageServiceError.cannotFinalize)
        }
        
        return .success(())
    }
    
    /// Prüft ob ein Bild hochkant (Portrait) ist
    static func isPortrait(imageSize: CGSize, orientation: Int) -> Bool {
        let displaySize = calculateDisplaySize(from: imageSize, orientation: orientation)
        return displaySize.height > displaySize.width
    }
    
    /// Berechnet Display-Größe basierend auf Orientierung
    private static func calculateDisplaySize(from size: CGSize, orientation: Int) -> CGSize {
        switch orientation {
        case 5, 6, 7, 8:
            return CGSize(width: size.height, height: size.width)
        default:
            return size
        }
    }
    
    /// Erstellt NSImage mit korrekter Orientierung für Display
    static func createDisplayImage(from imageData: ImageData) -> NSImage? {
        guard let imageSource = CGImageSourceCreateWithURL(imageData.url as CFURL, nil),
              let imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        
        // Für Display: Bild mit korrigierter Orientierung erstellen
        // In einer vollständigen Implementierung würde man hier die Transformation anwenden
        return NSImage(cgImage: imageRef, size: imageData.displaySize)
    }
}

/// Image-Service-Fehler
enum ImageServiceError: LocalizedError {
    case cannotReadImage
    case cannotCreateDestination
    case cannotFinalize
    case unsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .cannotReadImage:
            return "Bild konnte nicht gelesen werden"
        case .cannotCreateDestination:
            return "Ziel-Datei konnte nicht erstellt werden"
        case .cannotFinalize:
            return "Bild konnte nicht finalisiert werden"
        case .unsupportedFormat:
            return "Nicht unterstütztes Bildformat"
        }
    }
}

