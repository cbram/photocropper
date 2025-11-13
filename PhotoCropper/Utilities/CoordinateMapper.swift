//
//  CoordinateMapper.swift
//  PhotoCropper
//
//  Hilfsfunktionen für Koordinaten-Transformationen
//

import Foundation
import CoreGraphics

/// Mappt Koordinaten zwischen verschiedenen Koordinatensystemen
struct CoordinateMapper {
    /// Konvertiert View-Koordinaten zu Bild-Koordinaten
    static func viewToImage(
        viewPoint: CGPoint,
        viewSize: CGSize,
        imageRect: CGRect,
        imageSize: CGSize
    ) -> CGPoint {
        let scaleX = imageSize.width / imageRect.width
        let scaleY = imageSize.height / imageRect.height
        
        let relativeX = viewPoint.x - imageRect.origin.x
        let relativeY = viewPoint.y - imageRect.origin.y
        
        return CGPoint(
            x: relativeX * scaleX,
            y: relativeY * scaleY
        )
    }
    
    /// Konvertiert Bild-Koordinaten zu View-Koordinaten
    static func imageToView(
        imagePoint: CGPoint,
        imageRect: CGRect,
        imageSize: CGSize
    ) -> CGPoint {
        let scaleX = imageRect.width / imageSize.width
        let scaleY = imageRect.height / imageSize.height
        
        return CGPoint(
            x: imageRect.origin.x + imagePoint.x * scaleX,
            y: imageRect.origin.y + imagePoint.y * scaleY
        )
    }
}

