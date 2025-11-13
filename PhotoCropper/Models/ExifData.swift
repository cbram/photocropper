//
//  ExifData.swift
//  PhotoCropper
//
//  Struktur für EXIF/XMP-Metadaten-Manipulation
//

import Foundation
import CoreGraphics

/// Struktur für Crop-Metadaten in EXIF/XMP
struct CropMetadata {
    /// DefaultCropOrigin (normalisiert 0.0-1.0)
    var originX: Double
    var originY: Double
    
    /// DefaultCropSize (normalisiert 0.0-1.0)
    var width: Double
    var height: Double
    
    /// Custom Tags
    var cropMode: String
    var originalRatio: String
    var targetRatio: String
    var cropDateTime: Date
    
    init(origin: CGPoint, size: CGSize, mode: CropMode, originalRatio: String, targetRatio: String) {
        self.originX = Double(origin.x)
        self.originY = Double(origin.y)
        self.width = Double(size.width)
        self.height = Double(size.height)
        self.cropMode = mode.rawValue
        self.originalRatio = originalRatio
        self.targetRatio = targetRatio
        self.cropDateTime = Date()
    }
}

/// EXIF-Tag-Konstanten
struct EXIFTags {
    // Standard EXIF Tags
    static let defaultCropOrigin = "DefaultCropOrigin"
    static let defaultCropSize = "DefaultCropSize"
    
    // Custom Tags (werden in XMP gespeichert)
    static let cropMode = "CropMode"
    static let originalRatio = "OriginalRatio"
    static let targetRatio = "TargetRatio"
    static let cropDateTime = "CropDateTime"
    
    // XMP Namespace
    static let xmpNamespace = "http://ns.adobe.com/xap/1.0/"
    static let customNamespace = "http://photocropper.app/1.0/"
}

