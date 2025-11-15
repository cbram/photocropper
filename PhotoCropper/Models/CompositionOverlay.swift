//
//  CompositionOverlay.swift
//  PhotoCropper
//
//  Definiert die verfügbaren Kompositions-Overlays
//

import Foundation

/// Kompositions-Overlay-Typen für bessere Bildkomposition
enum CompositionOverlay: Equatable, CaseIterable {
    case none
    case ruleOfThirds
    case goldenRatio
    case fibonacciTopLeft
    case fibonacciTopRight
    case fibonacciBottomLeft
    case fibonacciBottomRight
    
    var displayName: String {
        switch self {
        case .none:
            return "Keine"
        case .ruleOfThirds:
            return "Drittel-Regel"
        case .goldenRatio:
            return "Goldener Schnitt"
        case .fibonacciTopLeft:
            return "Fibonacci (Oben-Links)"
        case .fibonacciTopRight:
            return "Fibonacci (Oben-Rechts)"
        case .fibonacciBottomLeft:
            return "Fibonacci (Unten-Links)"
        case .fibonacciBottomRight:
            return "Fibonacci (Unten-Rechts)"
        }
    }
}

