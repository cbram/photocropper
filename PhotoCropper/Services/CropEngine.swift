//
//  CropEngine.swift
//  PhotoCropper
//
//  Core logic for crop calculations: Ratios, snapping, positioning
//

import Foundation
import CoreGraphics

/// Engine for crop box calculations and transformations
///
/// This class provides the core mathematical logic for crop operations:
/// - **Crop Box Calculation**: Determines crop dimensions and position based on aspect ratios
/// - **MCU Grid Snapping**: Aligns crop coordinates to JPEG MCU boundaries for lossless cropping
/// - **Coordinate Transformation**: Converts between pixel and normalized (0.0-1.0) coordinates
/// - **Validation**: Ensures crop boxes stay within image boundaries
///
/// ## Architecture
/// All methods are static and pure (no side effects), making them:
/// - Thread-safe
/// - Easy to test
/// - Predictable and reliable
///
/// ## Usage Example
/// ```swift
/// // Calculate crop box for 16:9 aspect ratio
/// let cropBox = CropEngine.calculateCropBox(
///     inputDimensions: CGSize(width: 1920, height: 1080),
///     inputRatio: "16:9",
///     targetRatio: .ratio16_9
/// )
///
/// // Normalize coordinates for metadata storage
/// let normalized = CropEngine.normalizeCoordinates(
///     pixelCoords: cropBox,
///     imageSize: CGSize(width: 1920, height: 1080)
/// )
/// ```
class CropEngine {
    
    // MARK: - Constants
    
    /// Minimum crop size in pixels (prevents zero or negative dimensions)
    private static let minimumCropSize: CGFloat = 1.0
    
    /// Coordinate tolerance for floating-point comparisons
    private static let coordinateTolerance: CGFloat = 0.001
    
    // MARK: - Public Interface - Crop Box Calculation
    
    /// Calculates crop box based on input dimensions and target aspect ratio
    ///
    /// This method determines the optimal crop size to achieve the target aspect ratio,
    /// then positions it either at the user-specified location or centered on the image.
    ///
    /// The resulting crop box is guaranteed to:
    /// - Match the target aspect ratio (within tolerance)
    /// - Stay within image boundaries
    /// - Have non-zero dimensions
    ///
    /// - Parameters:
    ///   - inputDimensions: Original image dimensions
    ///   - inputRatio: Original image aspect ratio as string (e.g., "16:9")
    ///   - targetRatio: Target aspect ratio for the crop
    ///   - userPosition: Optional user-specified position for crop box origin. If `nil`, crop is centered
    /// - Returns: Calculated crop box in pixel coordinates
    ///
    /// - Precondition: `inputDimensions` must have positive width and height
    static func calculateCropBox(
        inputDimensions: CGSize,
        inputRatio: String,
        targetRatio: AspectRatio,
        userPosition: CGPoint? = nil
    ) -> CGRect {
        precondition(inputDimensions.width > 0 && inputDimensions.height > 0,
                     "Input dimensions must be positive: \(inputDimensions)")
        
        // Calculate crop size based on target aspect ratio
        let cropSize = targetRatio.calculateCropSize(for: inputDimensions)
        
        // Determine position (user-specified or centered)
        let position: CGPoint
        if let userPos = userPosition {
            position = userPos
        } else {
            position = targetRatio.calculateDefaultPosition(for: inputDimensions, cropSize: cropSize)
        }
        
        // Clamp position to ensure crop box stays within image boundaries
        let clampedX = max(0, min(position.x, inputDimensions.width - cropSize.width))
        let clampedY = max(0, min(position.y, inputDimensions.height - cropSize.height))
        
        // Adjust crop size if necessary (for edge cases at image boundaries)
        let finalWidth = min(cropSize.width, inputDimensions.width - clampedX)
        let finalHeight = min(cropSize.height, inputDimensions.height - clampedY)
        
        return CGRect(
            x: clampedX,
            y: clampedY,
            width: finalWidth,
            height: finalHeight
        )
    }
    
    /// Calculates the maximum possible crop box for a given aspect ratio
    ///
    /// This method finds the largest crop box that:
    /// - Fits within the image boundaries
    /// - Maintains the target aspect ratio
    /// - Is centered on the image
    ///
    /// - Parameters:
    ///   - imageSize: Original image dimensions
    ///   - targetRatio: Target aspect ratio for the crop
    /// - Returns: Maximum crop box in pixel coordinates
    ///
    /// - Precondition: `imageSize` must have positive width and height
    static func maximizeCropBox(
        imageSize: CGSize,
        targetRatio: AspectRatio
    ) -> CGRect {
        precondition(imageSize.width > 0 && imageSize.height > 0,
                     "Image size must be positive: \(imageSize)")
        
        let cropSize = targetRatio.calculateCropSize(for: imageSize)
        let position = targetRatio.calculateDefaultPosition(for: imageSize, cropSize: cropSize)
        return CGRect(origin: position, size: cropSize)
    }
    
    /// Centers a crop box within the image
    ///
    /// - Parameters:
    ///   - cropBox: Crop box to center
    ///   - imageSize: Image dimensions
    /// - Returns: Centered crop box
    ///
    /// - Precondition: Crop box must fit within image boundaries
    static func centerCropBox(
        cropBox: CGRect,
        imageSize: CGSize
    ) -> CGRect {
        precondition(cropBox.width <= imageSize.width && cropBox.height <= imageSize.height,
                     "Crop box (\(cropBox.size)) must fit within image (\(imageSize))")
        
        let centerX = (imageSize.width - cropBox.width) / 2.0
        let centerY = (imageSize.height - cropBox.height) / 2.0
        
        return CGRect(
            x: centerX,
            y: centerY,
            width: cropBox.width,
            height: cropBox.height
        )
    }
    
    // MARK: - Public Interface - MCU Grid Snapping
    
    /// Snaps crop coordinates to MCU grid boundaries for lossless JPEG cropping
    ///
    /// When MCU mode is enabled, this method aligns the crop box to JPEG Minimum Coded Unit (MCU)
    /// boundaries, allowing for lossless cropping. When disabled, returns coordinates unchanged.
    ///
    /// - Parameters:
    ///   - coordinates: Crop box to snap
    ///   - mcuSize: MCU grid size (typically 8×8 or 16×16)
    ///   - enabled: Whether MCU snapping is enabled
    /// - Returns: Snapped crop box (or original if disabled)
    ///
    /// - Note: Delegates to `JPEGService` for actual MCU snapping logic
    static func snapToMCUGrid(
        coordinates: CGRect,
        mcuSize: CGSize,
        enabled: Bool
    ) -> CGRect {
        guard enabled else {
            return coordinates
        }
        
        precondition(mcuSize.width > 0 && mcuSize.height > 0,
                     "MCU size must be positive: \(mcuSize)")
        
        return JPEGService.snapToMCUGrid(coordinates: coordinates, mcuSize: mcuSize)
    }
    
    // MARK: - Public Interface - Coordinate Transformation
    
    /// Converts pixel coordinates to normalized values (0.0-1.0 range)
    ///
    /// Normalized coordinates are used for:
    /// - Metadata storage (resolution-independent)
    /// - Lightroom/Adobe compatibility (CRS format)
    /// - Cross-application crop data exchange
    ///
    /// - Parameters:
    ///   - pixelCoords: Crop box in pixel coordinates
    ///   - imageSize: Original image dimensions
    /// - Returns: Normalized crop box (0.0-1.0 range)
    ///
    /// - Precondition: `imageSize` must have positive dimensions
    static func normalizeCoordinates(
        pixelCoords: CGRect,
        imageSize: CGSize
    ) -> CGRect {
        precondition(imageSize.width > 0 && imageSize.height > 0,
                     "Image size must be positive: \(imageSize)")
        
        return CGRect(
            x: pixelCoords.origin.x / imageSize.width,
            y: pixelCoords.origin.y / imageSize.height,
            width: pixelCoords.width / imageSize.width,
            height: pixelCoords.height / imageSize.height
        )
    }
    
    /// Converts normalized coordinates (0.0-1.0 range) back to pixel coordinates
    ///
    /// This is the inverse operation of `normalizeCoordinates()`, used when:
    /// - Loading crop data from metadata
    /// - Applying saved crop coordinates to images
    /// - Reconstructing crop boxes from stored data
    ///
    /// - Parameters:
    ///   - normalizedCoords: Crop box in normalized coordinates (0.0-1.0)
    ///   - imageSize: Target image dimensions
    /// - Returns: Crop box in pixel coordinates
    ///
    /// - Precondition: `imageSize` must have positive dimensions
    /// - Precondition: `normalizedCoords` should be in 0.0-1.0 range (though not enforced)
    static func denormalizeCoordinates(
        normalizedCoords: CGRect,
        imageSize: CGSize
    ) -> CGRect {
        precondition(imageSize.width > 0 && imageSize.height > 0,
                     "Image size must be positive: \(imageSize)")
        
        return CGRect(
            x: normalizedCoords.origin.x * imageSize.width,
            y: normalizedCoords.origin.y * imageSize.height,
            width: normalizedCoords.width * imageSize.width,
            height: normalizedCoords.height * imageSize.height
        )
    }
    
    // MARK: - Public Interface - Validation
    
    /// Validates and corrects a crop box to ensure it stays within image boundaries
    ///
    /// This method performs comprehensive validation:
    /// 1. Ensures crop dimensions are at least `minimumCropSize` pixels
    /// 2. Clamps crop size to fit within image boundaries
    /// 3. Clamps crop position to keep box fully inside image
    /// 4. Performs final size adjustment for edge cases
    ///
    /// - Parameters:
    ///   - cropBox: Crop box to validate
    ///   - imageSize: Image dimensions
    /// - Returns: Validated and corrected crop box
    ///
    /// - Precondition: `imageSize` must have positive dimensions
    static func validateCropBox(_ cropBox: CGRect, imageSize: CGSize) -> CGRect {
        precondition(imageSize.width > 0 && imageSize.height > 0,
                     "Image size must be positive: \(imageSize)")
        
        var validated = cropBox
        
        // Step 1: Constrain size to minimum and maximum (image size)
        validated.size.width = max(minimumCropSize, min(validated.size.width, imageSize.width))
        validated.size.height = max(minimumCropSize, min(validated.size.height, imageSize.height))
        
        // Step 2: Constrain position to keep crop box within image boundaries
        validated.origin.x = max(0, min(validated.origin.x, imageSize.width - validated.width))
        validated.origin.y = max(0, min(validated.origin.y, imageSize.height - validated.height))
        
        // Step 3: Final size adjustment (for cases where position is at edge)
        validated.size.width = min(validated.size.width, imageSize.width - validated.origin.x)
        validated.size.height = min(validated.size.height, imageSize.height - validated.origin.y)
        
        // Ensure minimum size is still respected after final adjustment
        validated.size.width = max(minimumCropSize, validated.size.width)
        validated.size.height = max(minimumCropSize, validated.size.height)
        
        return validated
    }
    
    // MARK: - Utility Methods
    
    /// Checks if a crop box is fully contained within image boundaries
    ///
    /// - Parameters:
    ///   - cropBox: Crop box to check
    ///   - imageSize: Image dimensions
    /// - Returns: `true` if crop box is fully inside image, otherwise `false`
    static func isValidCropBox(_ cropBox: CGRect, imageSize: CGSize) -> Bool {
        guard imageSize.width > 0 && imageSize.height > 0 else {
            return false
        }
        
        return cropBox.origin.x >= 0 &&
               cropBox.origin.y >= 0 &&
               cropBox.maxX <= imageSize.width + coordinateTolerance &&
               cropBox.maxY <= imageSize.height + coordinateTolerance &&
               cropBox.width >= minimumCropSize &&
               cropBox.height >= minimumCropSize
    }
}
