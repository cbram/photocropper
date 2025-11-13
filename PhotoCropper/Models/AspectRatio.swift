//
//  AspectRatio.swift
//  PhotoCropper
//
//  Repräsentiert verschiedene Seitenverhältnisse und deren Berechnung
//

import Foundation
import CoreGraphics

/// Repräsentiert ein Seitenverhältnis (z.B. 16:9, 1:1, 3:2)
enum AspectRatio: Identifiable, Hashable {
    case ratio16_9
    case ratio1_1
    case custom(width: Int, height: Int)
    
    static var allCases: [AspectRatio] {
        return [.ratio16_9, .ratio1_1, .custom(width: 16, height: 9)]
    }
    
    var id: String {
        switch self {
        case .ratio16_9:
            return "16:9"
        case .ratio1_1:
            return "1:1"
        case .custom(let w, let h):
            return "\(w):\(h)"
        }
    }
    
    /// Berechnet das Seitenverhältnis als Double (Breite/Höhe)
    var value: Double {
        switch self {
        case .ratio16_9:
            return 16.0 / 9.0
        case .ratio1_1:
            return 1.0
        case .custom(let w, let h):
            return Double(w) / Double(h)
        }
    }
    
    /// Display-Name für UI
    var displayName: String {
        switch self {
        case .ratio16_9:
            return "16:9 (Landscape)"
        case .ratio1_1:
            return "1:1 (Quadrat)"
        case .custom(let w, let h):
            return "\(w):\(h) (Benutzerdefiniert)"
        }
    }
    
    /// Berechnet die Crop-Box-Größe für ein gegebenes Bild
    func calculateCropSize(for imageSize: CGSize) -> CGSize {
        let imageRatio = imageSize.width / imageSize.height
        let targetRatio = self.value
        
        if imageRatio > targetRatio {
            // Bild ist breiter → Crop oben/unten
            let cropHeight = imageSize.height
            let cropWidth = cropHeight * CGFloat(targetRatio)
            return CGSize(width: cropWidth, height: cropHeight)
        } else if imageRatio < targetRatio {
            // Bild ist höher → Crop links/rechts
            let cropWidth = imageSize.width
            let cropHeight = cropWidth / CGFloat(targetRatio)
            return CGSize(width: cropWidth, height: cropHeight)
        } else {
            // Gleiches Verhältnis → Keine Crops nötig
            return imageSize
        }
    }
    
    /// Berechnet die Standard-Position für die Crop-Box (zentriert)
    func calculateDefaultPosition(for imageSize: CGSize, cropSize: CGSize) -> CGPoint {
        let x = (imageSize.width - cropSize.width) / 2.0
        let y = (imageSize.height - cropSize.height) / 2.0
        return CGPoint(x: x, y: y)
    }
}

/// Hilfsfunktion: Berechnet das Seitenverhältnis eines Bildes
func calculateImageAspectRatio(size: CGSize) -> (width: Int, height: Int) {
    let gcd = greatestCommonDivisor(Int(size.width), Int(size.height))
    return (Int(size.width) / gcd, Int(size.height) / gcd)
}

/// Größter gemeinsamer Teiler (Euklidischer Algorithmus)
private func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
    let absA = abs(a)
    let absB = abs(b)
    if absB == 0 {
        return absA
    }
    return greatestCommonDivisor(absB, absA % absB)
}

