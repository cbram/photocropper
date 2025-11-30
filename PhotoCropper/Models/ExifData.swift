//
//  ExifData.swift
//  PhotoCropper
//
//  Data structures for EXIF/XMP metadata manipulation
//

import Foundation
import CoreGraphics

// MARK: - Crop Metadata

/// Represents crop metadata stored in EXIF/XMP tags.
///
/// This structure encapsulates normalized crop coordinates and additional metadata
/// that can be embedded in image files using EXIF and XMP standards.
///
/// All coordinate values (origin and size) are normalized to the range 0.0-1.0,
/// where (0,0) represents the top-left corner and (1,1) the bottom-right corner.
///
/// - Note: Coordinate validation is performed during initialization to ensure values
///   remain within the valid normalized range.
struct CropMetadata {
    // MARK: Properties
    
    /// The normalized X coordinate of the crop origin (0.0-1.0).
    ///
    /// Corresponds to the EXIF `DefaultCropOrigin` tag (X component).
    let originX: Double
    
    /// The normalized Y coordinate of the crop origin (0.0-1.0).
    ///
    /// Corresponds to the EXIF `DefaultCropOrigin` tag (Y component).
    let originY: Double
    
    /// The normalized width of the crop region (0.0-1.0).
    ///
    /// Corresponds to the EXIF `DefaultCropSize` tag (width component).
    let width: Double
    
    /// The normalized height of the crop region (0.0-1.0).
    ///
    /// Corresponds to the EXIF `DefaultCropSize` tag (height component).
    let height: Double
    
    /// The cropping mode used (e.g., "mcuSensitive", "standard").
    ///
    /// Stored in custom XMP metadata.
    let cropMode: String
    
    /// The original aspect ratio of the image before cropping.
    ///
    /// Stored in custom XMP metadata.
    let originalRatio: String
    
    /// The target aspect ratio applied during cropping.
    ///
    /// Stored in custom XMP metadata.
    let targetRatio: String
    
    /// The date and time when the crop was applied.
    ///
    /// Stored in custom XMP metadata.
    let cropDateTime: Date
    
    // MARK: Initialization
    
    /// Creates crop metadata from normalized coordinates and crop settings.
    ///
    /// - Parameters:
    ///   - origin: The normalized origin point (both x and y must be in 0.0-1.0 range)
    ///   - size: The normalized size (both width and height must be in 0.0-1.0 range)
    ///   - mode: The crop mode applied
    ///   - originalRatio: The original aspect ratio identifier
    ///   - targetRatio: The target aspect ratio identifier
    ///
    /// - Note: Values outside the 0.0-1.0 range will trigger an assertion in debug builds
    ///   and be clamped to valid values in release builds.
    init(origin: CGPoint, size: CGSize, mode: CropMode, originalRatio: String, targetRatio: String) {
        let originX = Double(origin.x)
        let originY = Double(origin.y)
        let width = Double(size.width)
        let height = Double(size.height)
        
        // Validate normalized coordinates
        assert((0.0...1.0).contains(originX), "Origin X (\(originX)) must be in range 0.0-1.0")
        assert((0.0...1.0).contains(originY), "Origin Y (\(originY)) must be in range 0.0-1.0")
        assert((0.0...1.0).contains(width), "Width (\(width)) must be in range 0.0-1.0")
        assert((0.0...1.0).contains(height), "Height (\(height)) must be in range 0.0-1.0")
        
        // Clamp to valid range in release builds
        self.originX = min(max(originX, 0.0), 1.0)
        self.originY = min(max(originY, 0.0), 1.0)
        self.width = min(max(width, 0.0), 1.0)
        self.height = min(max(height, 0.0), 1.0)
        
        self.cropMode = mode.rawValue
        self.originalRatio = originalRatio
        self.targetRatio = targetRatio
        self.cropDateTime = Date()
    }
}

// MARK: - Convenience Methods

extension CropMetadata {
    /// The normalized origin as a CGPoint.
    var origin: CGPoint {
        CGPoint(x: originX, y: originY)
    }
    
    /// The normalized size as a CGSize.
    var size: CGSize {
        CGSize(width: width, height: height)
    }
    
    /// The normalized crop rectangle.
    var normalizedRect: CGRect {
        CGRect(origin: origin, size: size)
    }
    
    /// Converts the normalized coordinates to pixel coordinates for a given image size.
    ///
    /// - Parameter imageSize: The size of the image in pixels
    /// - Returns: The crop rectangle in pixel coordinates
    func toPixelCoordinates(imageSize: CGSize) -> CGRect {
        CGRect(
            x: originX * imageSize.width,
            y: originY * imageSize.height,
            width: width * imageSize.width,
            height: height * imageSize.height
        )
    }
    
    /// Checks if the crop metadata is valid for a given image.
    ///
    /// - Returns: `true` if the crop region is fully contained within the normalized bounds
    var isValid: Bool {
        originX >= 0.0 && originY >= 0.0 &&
        width > 0.0 && height > 0.0 &&
        originX + width <= 1.0 &&
        originY + height <= 1.0
    }
}

// MARK: - EXIF Tag Constants

/// Constants for EXIF and XMP metadata tags.
///
/// This structure organizes all tag names and namespaces used for storing
/// crop metadata in image files. Tags are grouped into standard EXIF tags,
/// custom XMP tags, and namespace definitions.
struct EXIFTags {
    
    // MARK: Standard EXIF Tags
    
    /// Standard EXIF tags defined by the EXIF specification.
    struct Standard {
        /// The origin point of the default crop region (2-element array of normalized values).
        static let defaultCropOrigin = "DefaultCropOrigin"
        
        /// The size of the default crop region (2-element array of normalized values).
        static let defaultCropSize = "DefaultCropSize"
    }
    
    // MARK: Custom XMP Tags
    
    /// Custom tags stored in XMP metadata for PhotoCropper-specific information.
    struct Custom {
        /// The crop mode used (e.g., "mcuSensitive", "standard").
        static let cropMode = "CropMode"
        
        /// The original aspect ratio before cropping.
        static let originalRatio = "OriginalRatio"
        
        /// The target aspect ratio applied during cropping.
        static let targetRatio = "TargetRatio"
        
        /// The date and time when the crop was applied.
        static let cropDateTime = "CropDateTime"
    }
    
    // MARK: Namespaces
    
    /// XML namespaces used for XMP metadata.
    struct Namespaces {
        /// Standard Adobe XMP namespace.
        static let xmp = "http://ns.adobe.com/xap/1.0/"
        
        /// PhotoCropper custom namespace for app-specific metadata.
        static let photoCropper = "http://photocropper.app/1.0/"
    }
    
    // MARK: Legacy Compatibility
    
    /// Legacy tag names for backward compatibility (deprecated, use nested structs instead).
    @available(*, deprecated, message: "Use EXIFTags.Standard.defaultCropOrigin instead")
    static let defaultCropOrigin = Standard.defaultCropOrigin
    
    @available(*, deprecated, message: "Use EXIFTags.Standard.defaultCropSize instead")
    static let defaultCropSize = Standard.defaultCropSize
    
    @available(*, deprecated, message: "Use EXIFTags.Custom.cropMode instead")
    static let cropMode = Custom.cropMode
    
    @available(*, deprecated, message: "Use EXIFTags.Custom.originalRatio instead")
    static let originalRatio = Custom.originalRatio
    
    @available(*, deprecated, message: "Use EXIFTags.Custom.targetRatio instead")
    static let targetRatio = Custom.targetRatio
    
    @available(*, deprecated, message: "Use EXIFTags.Custom.cropDateTime instead")
    static let cropDateTime = Custom.cropDateTime
    
    @available(*, deprecated, message: "Use EXIFTags.Namespaces.xmp instead")
    static let xmpNamespace = Namespaces.xmp
    
    @available(*, deprecated, message: "Use EXIFTags.Namespaces.photoCropper instead")
    static let customNamespace = Namespaces.photoCropper
}

