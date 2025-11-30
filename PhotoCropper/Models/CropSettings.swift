//
//  CropSettings.swift
//  PhotoCropper
//
//  Stores all crop-related settings and coordinates
//

import Foundation
import CoreGraphics

// MARK: - Crop Mode

/// Defines the cropping mode for JPEG images
///
/// - `mcuSensitive`: Lossless JPEG cropping aligned to MCU (Minimum Coded Unit) boundaries
/// - `standard`: Standard cropping without MCU alignment (may re-encode image)
enum CropMode: String, Codable {
    case mcuSensitive = "MCU-Sensitive"
    case standard = "Standard"
    
    /// Human-readable description of the crop mode
    var displayName: String {
        return self.rawValue
    }
    
    /// Indicates whether this mode requires MCU alignment
    var requiresMCUAlignment: Bool {
        switch self {
        case .mcuSensitive:
            return true
        case .standard:
            return false
        }
    }
}

// MARK: - Crop Settings

/// Container for all crop-related settings and coordinates
///
/// This structure holds the complete crop configuration including the crop box coordinates,
/// target aspect ratio, cropping mode, and metadata. It provides methods for coordinate
/// normalization to support resolution-independent storage.
///
/// Example:
/// ```swift
/// let settings = CropSettings(
///     cropBox: CGRect(x: 100, y: 100, width: 1600, height: 900),
///     targetRatio: .ratio16_9,
///     mode: .mcuSensitive,
///     originalRatio: "3:2"
/// )
/// ```
struct CropSettings {
    
    // MARK: - Properties
    
    /// Crop box in pixel coordinates
    ///
    /// Represents the rectangular region to be cropped from the original image.
    /// Coordinates are in pixels relative to the top-left corner of the image.
    var cropBox: CGRect
    
    /// Target aspect ratio for the crop
    var targetRatio: AspectRatio
    
    /// Cropping mode (MCU-sensitive or standard)
    var mode: CropMode
    
    /// Original aspect ratio of the source image
    ///
    /// Stored as a string representation (e.g., "16:9", "3:2") for reference.
    var originalRatio: String
    
    /// Timestamp when the crop settings were created
    ///
    /// Automatically set to the current date/time when initialized.
    let cropDateTime: Date
    
    /// MCU (Minimum Coded Unit) size for JPEG images
    ///
    /// Only relevant when `mode` is `.mcuSensitive`. Typically 8×8 or 16×16 pixels.
    /// `nil` for non-JPEG images or when MCU information is unavailable.
    var mcuSize: CGSize?
    
    // MARK: - Initialization
    
    /// Creates crop settings with the specified parameters
    ///
    /// - Parameters:
    ///   - cropBox: The crop rectangle in pixel coordinates
    ///   - targetRatio: The desired aspect ratio
    ///   - mode: The cropping mode to use
    ///   - originalRatio: The original image's aspect ratio as a string
    ///   - mcuSize: Optional MCU size for JPEG images (default: nil)
    ///   - cropDateTime: Optional custom timestamp (default: current date/time)
    ///
    /// - Note: The crop box coordinates are not validated in the initializer.
    ///         Use `validate(for:)` to ensure the crop box is within image bounds.
    init(
        cropBox: CGRect,
        targetRatio: AspectRatio,
        mode: CropMode,
        originalRatio: String,
        mcuSize: CGSize? = nil,
        cropDateTime: Date = Date()
    ) {
        self.cropBox = cropBox
        self.targetRatio = targetRatio
        self.mode = mode
        self.originalRatio = originalRatio
        self.mcuSize = mcuSize
        self.cropDateTime = cropDateTime
    }
    
    // MARK: - Coordinate Conversion
    
    /// Converts pixel coordinates to normalized values (0.0 - 1.0)
    ///
    /// Normalizes the crop box coordinates relative to the image size, making them
    /// resolution-independent. This is useful for storing crop metadata that should
    /// work across different image resolutions.
    ///
    /// - Parameter imageSize: The size of the image in pixels
    /// - Returns: A tuple containing the normalized origin point and size
    ///
    /// - Note: The normalized values are in the range 0.0 to 1.0, where:
    ///   - (0.0, 0.0) represents the top-left corner
    ///   - (1.0, 1.0) represents the bottom-right corner
    ///
    /// Example:
    /// ```swift
    /// let imageSize = CGSize(width: 3000, height: 2000)
    /// let (origin, size) = settings.normalizedCoordinates(for: imageSize)
    /// // origin.x might be 0.1 (10% from left edge)
    /// // size.width might be 0.8 (80% of image width)
    /// ```
    func normalizedCoordinates(for imageSize: CGSize) -> (origin: CGPoint, size: CGSize) {
        guard imageSize.width > 0 && imageSize.height > 0 else {
            assertionFailure("Image size must have positive dimensions")
            return (origin: .zero, size: .zero)
        }
        
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
    
    // MARK: - Validation
    
    /// Validates that the crop box is within the image bounds
    ///
    /// - Parameter imageSize: The size of the image in pixels
    /// - Returns: `true` if the crop box is completely within the image bounds
    ///
    /// Example:
    /// ```swift
    /// if settings.validate(for: imageSize) {
    ///     // Crop settings are valid
    /// } else {
    ///     // Crop box extends beyond image boundaries
    /// }
    /// ```
    func validate(for imageSize: CGSize) -> Bool {
        guard cropBox.width > 0 && cropBox.height > 0 else {
            return false
        }
        
        guard cropBox.origin.x >= 0 && cropBox.origin.y >= 0 else {
            return false
        }
        
        guard cropBox.maxX <= imageSize.width && cropBox.maxY <= imageSize.height else {
            return false
        }
        
        return true
    }
}

// MARK: - Convenience Extensions

extension CropSettings {
    /// Creates crop settings from normalized coordinates
    ///
    /// Convenience initializer for creating crop settings from normalized coordinates
    /// (typically read from metadata).
    ///
    /// - Parameters:
    ///   - normalizedOrigin: The crop origin as normalized coordinates (0.0-1.0)
    ///   - normalizedSize: The crop size as normalized coordinates (0.0-1.0)
    ///   - imageSize: The actual image size in pixels
    ///   - targetRatio: The target aspect ratio
    ///   - mode: The cropping mode
    ///   - originalRatio: The original image aspect ratio as a string
    ///   - mcuSize: Optional MCU size
    ///   - cropDateTime: Optional timestamp
    /// - Returns: A new `CropSettings` instance with pixel coordinates
    static func fromNormalized(
        origin normalizedOrigin: CGPoint,
        size normalizedSize: CGSize,
        imageSize: CGSize,
        targetRatio: AspectRatio,
        mode: CropMode,
        originalRatio: String,
        mcuSize: CGSize? = nil,
        cropDateTime: Date = Date()
    ) -> CropSettings {
        let pixelCropBox = CGRect(
            x: normalizedOrigin.x * imageSize.width,
            y: normalizedOrigin.y * imageSize.height,
            width: normalizedSize.width * imageSize.width,
            height: normalizedSize.height * imageSize.height
        )
        
        return CropSettings(
            cropBox: pixelCropBox,
            targetRatio: targetRatio,
            mode: mode,
            originalRatio: originalRatio,
            mcuSize: mcuSize,
            cropDateTime: cropDateTime
        )
    }
}
