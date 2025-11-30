//
//  ImageData.swift
//  PhotoCropper
//
//  Repräsentiert ein geladenes Bild mit allen Metadaten
//

import Foundation
import AppKit
import CoreGraphics
import ImageIO
import Combine

/// Bildformat-Typen
enum ImageFormat {
    case jpeg
    case heic
    case png
    case tiff
    case unknown
}

/// Repräsentiert ein geladenes Bild mit Metadaten
class ImageData: ObservableObject {
    /// Bild-URL
    let url: URL
    
    /// NSImage für Display
    @Published var image: NSImage?
    
    /// Original-Dimensionen in Pixeln
    @Published var pixelSize: CGSize = .zero
    
    /// EXIF-Orientierung (1-8)
    @Published var exifOrientation: Int = 1
    
    /// Tatsächliche Display-Orientierung (nach EXIF korrigiert)
    @Published var displaySize: CGSize = .zero
    
    /// Bildformat
    @Published var format: ImageFormat = .unknown
    
    /// Seitenverhältnis als String (z.B. "3:2", "16:9")
    @Published var aspectRatioString: String = ""
    
    /// Erstellungsdatum aus EXIF
    @Published var creationDate: Date?
    
    /// MCU-Größe (falls JPEG)
    @Published var mcuSize: CGSize?
    
    /// Gespeicherte Crop-Metadaten (falls vorhanden)
    @Published var cropMetadata: CropMetadata?
    
    /// Flag ob Bild bereits Crop-Metadaten hat
    @Published var hasCropMetadata: Bool = false
    
    /// Metadaten-Dictionary
    var metadata: [String: Any] = [:]
    
    init(url: URL) {
        self.url = url
        loadImage()
    }
    
    /// Lädt das Bild und extrahiert Metadaten
    private func loadImage() {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return
        }
        
        // Bildformat bestimmen
        if let uti = CGImageSourceGetType(imageSource) {
            format = determineFormat(from: uti as String)
        }
        
        // Pixel-Dimensionen
        pixelSize = CGSize(width: imageRef.width, height: imageRef.height)
        
        // EXIF-Orientierung auslesen
        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
           let orientation = properties[kCGImagePropertyOrientation as String] as? Int {
            exifOrientation = orientation
        }
        
        // Display-Größe berechnen (nach Orientierung korrigiert)
        displaySize = calculateDisplaySize(from: pixelSize, orientation: exifOrientation)
        
        // Seitenverhältnis berechnen
        let ratio = calculateImageAspectRatio(size: displaySize)
        aspectRatioString = "\(ratio.width):\(ratio.height)"
        
        // Erstellungsdatum auslesen
        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
           let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateTimeOriginal = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            creationDate = parseEXIFDate(dateTimeOriginal)
        }
        
        // Metadaten speichern
        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
            metadata = properties
        }
        
        // NSImage für Display erstellen
        image = NSImage(cgImage: imageRef, size: displaySize)
        
        // MCU-Größe für JPEG bestimmen (wird später von JPEGService geladen)
        
        // Crop-Metadaten auslesen (falls vorhanden)
        if let cropMeta = MetadataService.readCropMetadata(imageURL: url) {
            cropMetadata = cropMeta
            hasCropMetadata = true
            print("✅ Bild hat bereits Crop-Metadaten: \(url.lastPathComponent)")
        }
    }
    
    /// Bestimmt das Bildformat aus UTI
    private func determineFormat(from uti: String) -> ImageFormat {
        switch uti {
        case "public.jpeg":
            return .jpeg
        case "public.heic", "public.heif":
            return .heic
        case "public.png":
            return .png
        case "public.tiff":
            return .tiff
        default:
            return .unknown
        }
    }
    
    /// Berechnet die Display-Größe basierend auf EXIF-Orientierung
    private func calculateDisplaySize(from size: CGSize, orientation: Int) -> CGSize {
        // Orientierung 1, 2: Normal oder gespiegelt horizontal
        // Orientierung 3, 4: 180° gedreht oder gespiegelt vertikal
        // Orientierung 5-8: 90° oder 270° gedreht → Breite/Höhe tauschen
        switch orientation {
        case 1, 2:
            return size
        case 3, 4:
            return size
        case 5, 6, 7, 8:
            return CGSize(width: size.height, height: size.width)
        default:
            return size
        }
    }
    
    /// Parst EXIF-Datum-String
    private func parseEXIFDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateString)
    }
}

