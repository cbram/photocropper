//
//  CompositionOverlay.swift
//  PhotoCropper
//
//  Defines available composition overlays for better image composition
//

import Foundation

/// Composition overlay types for image composition guidance
///
/// Provides visual guides to help with image composition according to
/// established photographic principles like the Rule of Thirds or
/// the Golden Ratio.
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
}
