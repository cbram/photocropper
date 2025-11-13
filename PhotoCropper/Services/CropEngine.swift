//
//  CropEngine.swift
//  PhotoCropper
//
//  Kern-Logik für Crop-Berechnungen: Ratio, Snapping, Positionierung
//

import Foundation
import CoreGraphics

/// Engine für Crop-Berechnungen
class CropEngine {
    
    /// Berechnet die Crop-Box basierend auf Input- und Ziel-Ratio
    static func calculateCropBox(
        inputDimensions: CGSize,
        inputRatio: String,
        targetRatio: AspectRatio,
        userPosition: CGPoint? = nil
    ) -> CGRect {
        
        // Crop-Größe basierend auf Ziel-Ratio berechnen
        let cropSize = targetRatio.calculateCropSize(for: inputDimensions)
        
        // Position bestimmen (benutzerdefiniert oder zentriert)
        let position: CGPoint
        if let userPos = userPosition {
            position = userPos
        } else {
            position = targetRatio.calculateDefaultPosition(for: inputDimensions, cropSize: cropSize)
        }
        
        // Sicherstellen, dass Crop-Box innerhalb Bildgrenzen liegt
        let clampedX = max(0, min(position.x, inputDimensions.width - cropSize.width))
        let clampedY = max(0, min(position.y, inputDimensions.height - cropSize.height))
        
        // Crop-Größe anpassen falls nötig
        let finalWidth = min(cropSize.width, inputDimensions.width - clampedX)
        let finalHeight = min(cropSize.height, inputDimensions.height - clampedY)
        
        return CGRect(
            x: clampedX,
            y: clampedY,
            width: finalWidth,
            height: finalHeight
        )
    }
    
    /// Snappt Koordinaten auf MCU-Grid (falls MCU-Modus aktiv)
    static func snapToMCUGrid(
        coordinates: CGRect,
        mcuSize: CGSize,
        enabled: Bool
    ) -> CGRect {
        guard enabled else {
            return coordinates
        }
        
        return JPEGService.snapToMCUGrid(coordinates: coordinates, mcuSize: mcuSize)
    }
    
    /// Konvertiert Pixel-Koordinaten zu normalisierten Werten (0.0-1.0)
    static func normalizeCoordinates(
        pixelCoords: CGRect,
        imageSize: CGSize
    ) -> CGRect {
        return CGRect(
            x: pixelCoords.origin.x / imageSize.width,
            y: pixelCoords.origin.y / imageSize.height,
            width: pixelCoords.width / imageSize.width,
            height: pixelCoords.height / imageSize.height
        )
    }
    
    /// Konvertiert normalisierte Koordinaten zurück zu Pixel-Koordinaten
    static func denormalizeCoordinates(
        normalizedCoords: CGRect,
        imageSize: CGSize
    ) -> CGRect {
        return CGRect(
            x: normalizedCoords.origin.x * imageSize.width,
            y: normalizedCoords.origin.y * imageSize.height,
            width: normalizedCoords.width * imageSize.width,
            height: normalizedCoords.height * imageSize.height
        )
    }
    
    /// Validiert ob Crop-Box innerhalb Bildgrenzen liegt
    static func validateCropBox(_ cropBox: CGRect, imageSize: CGSize) -> CGRect {
        var validated = cropBox
        
        // X-Position begrenzen
        validated.origin.x = max(0, min(validated.origin.x, imageSize.width - validated.width))
        
        // Y-Position begrenzen
        validated.origin.y = max(0, min(validated.origin.y, imageSize.height - validated.height))
        
        // Breite begrenzen
        validated.size.width = min(validated.size.width, imageSize.width - validated.origin.x)
        
        // Höhe begrenzen
        validated.size.height = min(validated.size.height, imageSize.height - validated.origin.y)
        
        return validated
    }
    
    /// Berechnet die maximale Crop-Box für ein gegebenes Ratio
    static func maximizeCropBox(
        imageSize: CGSize,
        targetRatio: AspectRatio
    ) -> CGRect {
        let cropSize = targetRatio.calculateCropSize(for: imageSize)
        let position = targetRatio.calculateDefaultPosition(for: imageSize, cropSize: cropSize)
        return CGRect(origin: position, size: cropSize)
    }
    
    /// Zentriert die Crop-Box
    static func centerCropBox(
        cropBox: CGRect,
        imageSize: CGSize
    ) -> CGRect {
        let centerX = (imageSize.width - cropBox.width) / 2.0
        let centerY = (imageSize.height - cropBox.height) / 2.0
        return CGRect(
            x: centerX,
            y: centerY,
            width: cropBox.width,
            height: cropBox.height
        )
    }
}

