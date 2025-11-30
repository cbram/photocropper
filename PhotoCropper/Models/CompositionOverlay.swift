//
//  CompositionOverlay.swift
//  PhotoCropper
//
//  Defines available composition overlays for better image composition
//

import Foundation
import CoreGraphics

/// Composition overlay types for image composition guidance
///
/// Provides visual guides to help with image composition according to
/// established photographic principles like the Rule of Thirds or
/// the Golden Ratio.
///
/// ## Composition Principles
///
/// - **Rule of Thirds**: Divides the image into 9 equal parts using 2 horizontal
///   and 2 vertical lines. Important elements should be placed at the intersections
///   or along the lines.
///
/// - **Golden Ratio**: Uses the ratio 1:1.618 (φ) for harmonious composition.
///   Creates more dynamic and visually pleasing compositions than the Rule of Thirds.
///
/// - **Fibonacci Spiral**: Based on the Fibonacci sequence, creates a spiral that
///   guides the viewer's eye through the composition. Available in 4 orientations.
///
/// ## Usage Example
/// ```swift
/// let overlay: CompositionOverlay = .ruleOfThirds
/// print(overlay.displayName)  // "Rule of Thirds"
/// print(overlay.description)  // "Divides the frame..."
/// ```
///
/// - Note: The overlay is displayed on top of the image and crop box
///         to assist with positioning the subject optimally.
enum CompositionOverlay: Equatable, CaseIterable, Hashable {
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
    
    /// Short description of the composition principle
    var description: String {
        switch self {
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
    
    // MARK: - Mathematical Constants
    
    /// The golden ratio (φ ≈ 1.618033988749895)
    static let phi: CGFloat = 1.618033988749895
    
    /// Inverse of the golden ratio (1/φ ≈ 0.618)
    static let phiInverse: CGFloat = 0.618033988749895
    
    // MARK: - Calculation Methods
    
    /// Calculates the line positions for Rule of Thirds
    ///
    /// - Parameter rect: Rectangle to divide
    /// - Returns: Tuple of (horizontal lines, vertical lines) as normalized positions (0.0-1.0)
    static func ruleOfThirdsLines(in rect: CGRect) -> (horizontal: [CGFloat], vertical: [CGFloat]) {
        return (
            horizontal: [1.0/3.0, 2.0/3.0],
            vertical: [1.0/3.0, 2.0/3.0]
        )
    }
    
    /// Calculates the line positions for Golden Ratio
    ///
    /// - Parameter rect: Rectangle to divide
    /// - Returns: Tuple of (horizontal lines, vertical lines) as normalized positions (0.0-1.0)
    static func goldenRatioLines(in rect: CGRect) -> (horizontal: [CGFloat], vertical: [CGFloat]) {
        return (
            horizontal: [phiInverse, 1.0 - phiInverse],
            vertical: [phiInverse, 1.0 - phiInverse]
        )
    }
    
    /// Calculates intersection points (power points) for the overlay
    ///
    /// - Parameter rect: Rectangle to calculate intersections for
    /// - Returns: Array of intersection points in absolute coordinates
    func intersectionPoints(in rect: CGRect) -> [CGPoint] {
        let lines: (horizontal: [CGFloat], vertical: [CGFloat])
        
        switch self {
        case .ruleOfThirds:
            lines = Self.ruleOfThirdsLines(in: rect)
        case .goldenRatio:
            lines = Self.goldenRatioLines(in: rect)
        case .fibonacciTopLeft, .fibonacciTopRight, .fibonacciBottomLeft, .fibonacciBottomRight:
            // Fibonacci spirals don't have discrete intersection points
            return []
        }
        
        var points: [CGPoint] = []
        for h in lines.horizontal {
            for v in lines.vertical {
                points.append(CGPoint(
                    x: rect.origin.x + rect.width * v,
                    y: rect.origin.y + rect.height * h
                ))
            }
        }
        
        return points
    }
    
    /// Checks if this overlay uses a spiral (Fibonacci)
    var isSpiral: Bool {
        switch self {
        case .fibonacciTopLeft, .fibonacciTopRight, .fibonacciBottomLeft, .fibonacciBottomRight:
            return true
        case .ruleOfThirds, .goldenRatio:
            return false
        }
    }
    
    /// Checks if this overlay uses grid lines
    var isGrid: Bool {
        return !isSpiral
    }
}
