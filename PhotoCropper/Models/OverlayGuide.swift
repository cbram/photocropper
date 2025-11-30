//
//  OverlayGuide.swift
//  PhotoCropper
//
//  Defines visual overlay guides for image cropping assistance
//

import Foundation

/// Visual overlay guides for cropping assistance
///
/// Provides various overlay types to help with image composition and technical
/// constraints. Overlays are mutually exclusive - only one can be active at a time.
///
/// - `none`: No overlay guide
/// - `mcuGrid`: Shows MCU (Minimum Coded Unit) grid for lossless JPEG cropping
/// - Composition guides: Rule of Thirds, Golden Ratio, Fibonacci spirals
enum OverlayGuide: Equatable, CaseIterable, Hashable {
    case none
    case mcuGrid
    case ruleOfThirds
    case goldenRatio
    case fibonacciTopLeft
    case fibonacciTopRight
    case fibonacciBottomLeft
    case fibonacciBottomRight
    
    // MARK: - Display Properties
    
    /// Human-readable name for the overlay type
    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .mcuGrid:
            return "MCU Grid"
        case .ruleOfThirds:
            return "Rule of Thirds"
        case .goldenRatio:
            return "Golden Ratio"
        case .fibonacciTopLeft:
            return "Fibonacci (Top-Left)"
        case .fibonacciTopRight:
            return "Fibonacci (Top-Right)"
        case .fibonacciBottomLeft:
            return "Fibonacci (Bottom-Left)"
        case .fibonacciBottomRight:
            return "Fibonacci (Bottom-Right)"
        }
    }
    
    /// Short description of the overlay guide
    var description: String {
        switch self {
        case .none:
            return "No overlay guide"
        case .mcuGrid:
            return "Shows MCU grid for lossless JPEG cropping (8×8 pixel blocks)"
        case .ruleOfThirds:
            return "Divides the frame into thirds horizontally and vertically"
        case .goldenRatio:
            return "Uses the golden ratio (1:1.618) for harmonious composition"
        case .fibonacciTopLeft:
            return "Fibonacci spiral starting from top-left"
        case .fibonacciTopRight:
            return "Fibonacci spiral starting from top-right"
        case .fibonacciBottomLeft:
            return "Fibonacci spiral starting from bottom-left"
        case .fibonacciBottomRight:
            return "Fibonacci spiral starting from bottom-right"
        }
    }
    
    // MARK: - Classification
    
    /// Indicates whether this overlay requires MCU-sensitive cropping mode
    ///
    /// MCU Grid should only be used when cropping mode is set to MCU-sensitive,
    /// as it shows the MCU block boundaries for lossless JPEG cropping.
    var requiresMCUMode: Bool {
        return self == .mcuGrid
    }
    
    /// Indicates whether this is a composition guide (artistic overlay)
    var isCompositionGuide: Bool {
        switch self {
        case .none, .mcuGrid:
            return false
        case .ruleOfThirds, .goldenRatio, 
             .fibonacciTopLeft, .fibonacciTopRight,
             .fibonacciBottomLeft, .fibonacciBottomRight:
            return true
        }
    }
    
    /// Indicates whether this overlay should be shown
    var isVisible: Bool {
        return self != .none
    }
    
    // MARK: - Conversion
    
    /// Converts to CompositionOverlay type for legacy compatibility
    ///
    /// - Returns: The corresponding CompositionOverlay, or nil if this is not a composition guide
    var asCompositionOverlay: CompositionOverlay? {
        switch self {
        case .ruleOfThirds:
            return .ruleOfThirds
        case .goldenRatio:
            return .goldenRatio
        case .fibonacciTopLeft:
            return .fibonacciTopLeft
        case .fibonacciTopRight:
            return .fibonacciTopRight
        case .fibonacciBottomLeft:
            return .fibonacciBottomLeft
        case .fibonacciBottomRight:
            return .fibonacciBottomRight
        case .none, .mcuGrid:
            return nil
        }
    }
    
    /// Creates an OverlayGuide from a CompositionOverlay
    ///
    /// - Parameter overlay: The composition overlay to convert
    /// - Returns: The corresponding OverlayGuide
    static func from(_ overlay: CompositionOverlay) -> OverlayGuide {
        switch overlay {
        case .ruleOfThirds:
            return .ruleOfThirds
        case .goldenRatio:
            return .goldenRatio
        case .fibonacciTopLeft:
            return .fibonacciTopLeft
        case .fibonacciTopRight:
            return .fibonacciTopRight
        case .fibonacciBottomLeft:
            return .fibonacciBottomLeft
        case .fibonacciBottomRight:
            return .fibonacciBottomRight
        }
    }
}

