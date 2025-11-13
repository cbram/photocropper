//
//  CropSettings.swift
//  PhotoCropper
//
//  Speichert alle Crop-Einstellungen und Koordinaten
//

import Foundation
import CoreGraphics

/// Cropping-Modus
enum CropMode: String, Codable {
    case mcuSensitive = "MCU-Sensitive"
    case standard = "Standard"
}

/// Speichert alle Crop-Einstellungen
struct CropSettings {
    /// Crop-Box in Pixel-Koordinaten
    var cropBox: CGRect
    
    /// Ziel-Seitenverhältnis
    var targetRatio: AspectRatio
    
    /// Cropping-Modus
    var mode: CropMode
    
    /// Original-Seitenverhältnis des Bildes
    var originalRatio: String
    
    /// Zeitstempel wann gecroppt wurde
    var cropDateTime: Date
    
    /// MCU-Größe (falls MCU-Modus)
    var mcuSize: CGSize?
    
    init(cropBox: CGRect, targetRatio: AspectRatio, mode: CropMode, originalRatio: String, mcuSize: CGSize? = nil) {
        self.cropBox = cropBox
        self.targetRatio = targetRatio
        self.mode = mode
        self.originalRatio = originalRatio
        self.cropDateTime = Date()
        self.mcuSize = mcuSize
    }
    
    /// Konvertiert Pixel-Koordinaten zu normalisierten Werten (0.0 - 1.0)
    func normalizedCoordinates(for imageSize: CGSize) -> (origin: CGPoint, size: CGSize) {
        let normalizedOrigin = CGPoint(
            x: cropBox.origin.x / imageSize.width,
            y: cropBox.origin.y / imageSize.height
        )
        let normalizedSize = CGSize(
            width: cropBox.width / imageSize.width,
            height: cropBox.height / imageSize.height
        )
        return (normalizedOrigin, normalizedSize)
    }
}

