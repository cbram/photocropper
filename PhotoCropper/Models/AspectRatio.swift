//
//  AspectRatio.swift
//  PhotoCropper
//
//  Represents different aspect ratios and their calculations
//

import Foundation
import CoreGraphics

/// Represents an aspect ratio (e.g., 16:9, 1:1, 3:2) used for image cropping
///
/// This enum provides predefined common aspect ratios as well as support for custom ratios.
/// It includes methods for calculating crop box dimensions and positions based on the target ratio.
///
/// - Note: Custom ratios must have positive width and height values
enum AspectRatio: Identifiable, Hashable {
    case ratio16_9
    case ratio1_1
    case custom(width: Int, height: Int)
    
    // MARK: - Constants
    
    /// Tolerance value for comparing aspect ratios (prevents floating-point precision issues)
    private static let comparisonTolerance: Double = 0.001
    
    // MARK: - Static Properties
    
    /// Returns all predefined (non-custom) aspect ratio cases
    ///
    /// - Note: This only includes fixed ratios (16:9, 1:1), not custom ratios
    static var allCases: [AspectRatio] {
        return [.ratio16_9, .ratio1_1]
    }
    
    // MARK: - Computed Properties
    
    /// Unique identifier for the aspect ratio
    ///
    /// Used for SwiftUI Identifiable conformance
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
    
    /// Calculates the aspect ratio as a Double (width/height)
    ///
    /// - Returns: The numeric aspect ratio value
    /// - Note: For custom ratios, ensures positive values are used
    var value: Double {
        switch self {
        case .ratio16_9:
            return 16.0 / 9.0
        case .ratio1_1:
            return 1.0
        case .custom(let w, let h):
            guard w > 0 && h > 0 else {
                assertionFailure("Custom aspect ratio must have positive width and height")
                return 1.0 // Fallback to square ratio
            }
            return Double(w) / Double(h)
        }
    }
    
    /// Display name for UI presentation
    ///
    /// - Returns: A human-readable string describing the aspect ratio
    var displayName: String {
        switch self {
        case .ratio16_9:
            return "16:9 (Landscape)"
        case .ratio1_1:
            return "1:1 (Square)"
        case .custom(let w, let h):
            return "\(w):\(h) (Custom)"
        }
    }
    
    // MARK: - Calculation Methods
    
    /// Calculates the crop box size for a given image
    ///
    /// Determines the maximum crop box size that fits within the image bounds
    /// while maintaining the target aspect ratio. The crop box is maximized to
    /// use either the full width or full height of the image.
    ///
    /// - Parameter imageSize: The size of the image in pixels
    /// - Returns: The calculated crop box size maintaining the target aspect ratio
    ///
    /// - Note: If the image already matches the target ratio (within tolerance),
    ///         the full image size is returned
    func calculateCropSize(for imageSize: CGSize) -> CGSize {
        let imageRatio = imageSize.width / imageSize.height
        let targetRatio = self.value
        
        // If ratios match (within tolerance), use full image size
        if abs(imageRatio - targetRatio) < Self.comparisonTolerance {
            return imageSize
        }
        
        // Option 1: Calculate based on height (use full height)
        let widthFromHeight = imageSize.height * CGFloat(targetRatio)
        
        // Option 2: Calculate based on width (use full width)
        let heightFromWidth = imageSize.width / CGFloat(targetRatio)
        
        // Determine which option fits within the image bounds
        if widthFromHeight <= imageSize.width {
            // Option 1 fits: Full height, adjusted width
            return CGSize(width: widthFromHeight, height: imageSize.height)
        } else if heightFromWidth <= imageSize.height {
            // Option 2 fits: Full width, adjusted height
            return CGSize(width: imageSize.width, height: heightFromWidth)
        }
        
        // Fallback: Should not occur with valid input
        assertionFailure("Unable to calculate crop size - invalid image dimensions")
        return imageSize
    }
    
    /// Calculates the default centered position for a crop box
    ///
    /// Centers the crop box within the image by calculating equal margins
    /// on all sides.
    ///
    /// - Parameters:
    ///   - imageSize: The size of the image in pixels
    ///   - cropSize: The size of the crop box
    /// - Returns: The top-left corner position for a centered crop box
    ///
    /// - Note: The returned point represents the top-left corner in standard
    ///         Core Graphics coordinates (origin at top-left)
    func calculateDefaultPosition(for imageSize: CGSize, cropSize: CGSize) -> CGPoint {
        let x = (imageSize.width - cropSize.width) / 2.0
        let y = (imageSize.height - cropSize.height) / 2.0
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Aspect Ratio Utilities

/// Utility extension for aspect ratio calculations
extension AspectRatio {
    /// Calculates the simplified aspect ratio of an image size
    ///
    /// Uses the greatest common divisor to reduce the ratio to its simplest form.
    /// For example, a 1920×1080 image returns (16, 9).
    ///
    /// - Parameter size: The image size to analyze
    /// - Returns: A tuple containing the simplified width and height ratio
    ///
    /// Example:
    /// ```swift
    /// let size = CGSize(width: 1920, height: 1080)
    /// let ratio = AspectRatio.calculateSimplified(from: size)
    /// // ratio = (width: 16, height: 9)
    /// ```
    static func calculateSimplified(from size: CGSize) -> (width: Int, height: Int) {
        let gcd = greatestCommonDivisor(Int(size.width), Int(size.height))
        return (Int(size.width) / gcd, Int(size.height) / gcd)
    }
    
    /// Calculates the greatest common divisor using Euclid's algorithm
    ///
    /// - Parameters:
    ///   - a: First integer
    ///   - b: Second integer
    /// - Returns: The greatest common divisor of a and b
    ///
    /// - Note: This is a private helper method used for aspect ratio simplification
    private static func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        let absA = abs(a)
        let absB = abs(b)
        
        // Base case: if b is zero, return a
        if absB == 0 {
            return absA
        }
        
        // Recursive case: gcd(a, b) = gcd(b, a mod b)
        return greatestCommonDivisor(absB, absA % absB)
    }
}

// MARK: - Global Helper Function (Backward Compatibility)

/// Calculates the simplified aspect ratio of an image
///
/// This global function is maintained for backward compatibility with existing code.
/// New code should use `AspectRatio.calculateSimplified(from:)` instead.
///
/// - Parameter size: The image size to analyze
/// - Returns: A tuple containing the simplified width and height ratio
///
/// - Note: Deprecated - Use `AspectRatio.calculateSimplified(from:)` instead
func calculateImageAspectRatio(size: CGSize) -> (width: Int, height: Int) {
    return AspectRatio.calculateSimplified(from: size)
}
