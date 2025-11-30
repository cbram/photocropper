//
//  ImageService.swift
//  PhotoCropper
//
//  Service for image loading, orientation, and format detection
//

import Foundation
import AppKit
import CoreGraphics
import ImageIO

// MARK: - Image Service

/// Service for image operations and manipulation
///
/// This service provides methods for loading images, converting formats,
/// generating thumbnails, and handling image orientation.
///
/// All methods use Result types for consistent error handling.
class ImageService {
    
    // MARK: - Constants
    
    /// Default JPEG quality for conversions
    private static let defaultJPEGQuality: CGFloat = 0.85
    
    /// EXIF orientation values that require dimension swap (portrait orientations)
    private static let portraitOrientations: Set<Int> = [5, 6, 7, 8]
    
    // MARK: - Image Loading
    
    /// Loads an image and creates an ImageData object
    ///
    /// This is a convenience method that wraps the ImageData initializer.
    ///
    /// - Parameter url: URL of the image file to load
    /// - Returns: ImageData object, or `nil` if loading fails
    ///
    /// - Note: Consider using `ImageData(url:)` directly instead of this wrapper.
    static func loadImage(from url: URL) -> ImageData? {
        return ImageData(url: url)
    }
    
    /// Loads multiple images for batch processing
    ///
    /// - Parameter urls: Array of image file URLs to load
    /// - Returns: Array of successfully loaded ImageData objects
    ///
    /// - Note: Failed loads are silently filtered out. Check the array count
    ///   to determine how many images loaded successfully.
    static func loadImages(from urls: [URL]) -> [ImageData] {
        let images = urls.compactMap { ImageData(url: $0) }
        print("📥 Loaded \(images.count) of \(urls.count) images")
        return images
    }
    
    // MARK: - Format Conversion
    
    /// Converts a HEIC image to JPEG format
    ///
    /// This method is useful for MCU cropping operations which require JPEG format.
    /// The conversion preserves all metadata (EXIF, XMP, IPTC).
    ///
    /// - Parameters:
    ///   - heicURL: URL of the source HEIC file
    ///   - outputURL: URL where the JPEG file will be saved
    ///   - quality: JPEG compression quality (0.0 to 1.0, default: 0.85)
    ///
    /// - Returns: Result indicating success or failure
    ///
    /// Example:
    /// ```swift
    /// let result = ImageService.convertHEICToJPEG(
    ///     heicURL: sourceURL,
    ///     outputURL: destURL,
    ///     quality: 0.9
    /// )
    /// ```
    static func convertHEICToJPEG(
        heicURL: URL,
        outputURL: URL,
        quality: CGFloat = defaultJPEGQuality
    ) -> Result<Void, ImageServiceError> {
        
        print("🔄 Converting HEIC to JPEG: \(heicURL.lastPathComponent)")
        print("  Quality: \(quality)")
        
        // Load source image
        guard let imageSource = CGImageSourceCreateWithURL(heicURL as CFURL, nil),
              let imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            print("  ❌ Cannot read HEIC image")
            return .failure(.cannotReadImage)
        }
        
        // Create JPEG destination
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTI.jpeg as CFString,
            1,
            nil
        ) else {
            print("  ❌ Cannot create JPEG destination")
            return .failure(.cannotCreateDestination)
        }
        
        // Preserve metadata from source
        let metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
        
        // Set JPEG quality
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        
        // Add image with metadata and quality settings
        CGImageDestinationAddImage(destination, imageRef, metadata)
        CGImageDestinationSetProperties(destination, properties as CFDictionary)
        
        // Finalize and write to disk
        guard CGImageDestinationFinalize(destination) else {
            print("  ❌ Cannot finalize JPEG file")
            return .failure(.cannotFinalize)
        }
        
        print("  ✅ HEIC converted to JPEG successfully")
        return .success(())
    }
    
    // MARK: - Orientation
    
    /// Checks if an image is in portrait orientation
    ///
    /// Takes into account the EXIF orientation tag to determine if the
    /// displayed image (after orientation correction) is taller than it is wide.
    ///
    /// - Parameters:
    ///   - imageSize: The pixel dimensions of the image
    ///   - orientation: EXIF orientation value (1-8)
    ///
    /// - Returns: `true` if the image is portrait, `false` if landscape or square
    static func isPortrait(imageSize: CGSize, orientation: Int) -> Bool {
        let displaySize = calculateDisplaySize(from: imageSize, orientation: orientation)
        return displaySize.height > displaySize.width
    }
    
    /// Calculates the display size based on EXIF orientation
    ///
    /// For orientations 5-8 (portrait), the width and height are swapped.
    ///
    /// - Parameters:
    ///   - size: The original pixel dimensions
    ///   - orientation: EXIF orientation value (1-8)
    ///
    /// - Returns: The display size after orientation correction
    private static func calculateDisplaySize(from size: CGSize, orientation: Int) -> CGSize {
        if portraitOrientations.contains(orientation) {
            return CGSize(width: size.height, height: size.width)
        }
        return size
    }
    
    // MARK: - Display Image Creation
    
    /// Creates an NSImage with correct orientation for display
    ///
    /// - Parameter imageData: The image data containing URL and display size
    /// - Returns: An NSImage ready for display, or `nil` if creation fails
    ///
    /// - Note: In a complete implementation, this would apply orientation
    ///   transformations. Currently, it creates a basic NSImage.
    static func createDisplayImage(from imageData: ImageData) -> NSImage? {
        guard let imageSource = CGImageSourceCreateWithURL(imageData.url as CFURL, nil),
              let imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        
        // Create NSImage with display size
        // TODO: Apply orientation transformation if needed
        return NSImage(cgImage: imageRef, size: imageData.displaySize)
    }
    
    // MARK: - Thumbnail Generation
    
    /// Generates a thumbnail from an NSImage
    ///
    /// Creates a proportionally scaled thumbnail that fits within the specified maximum size
    /// while maintaining the original aspect ratio.
    ///
    /// - Parameters:
    ///   - image: The source image to create a thumbnail from
    ///   - maxSize: Maximum size for the thumbnail (width and height)
    ///
    /// - Returns: A thumbnail NSImage, or `nil` if generation fails
    ///
    /// - Note: This method uses high-quality interpolation for better results.
    ///   The actual thumbnail size may be smaller than `maxSize` to maintain aspect ratio.
    static func generateThumbnail(from image: NSImage?, maxSize: CGSize) -> NSImage? {
        guard let image = image else {
            return nil
        }
        
        return image.resized(to: maxSize)
    }
    
    // MARK: - Validation
    
    /// Validates if a file is a supported image format
    ///
    /// - Parameter url: URL of the file to validate
    /// - Returns: Result with ImageFormat if valid, error if invalid
    ///
    /// Supported formats: JPEG, HEIC/HEIF, PNG, TIFF
    static func validateImageFile(at url: URL) -> Result<ImageFormat, ImageServiceError> {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure(.fileNotFound)
        }
        
        // Try to create image source
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let uti = CGImageSourceGetType(imageSource) else {
            return .failure(.cannotReadImage)
        }
        
        // Determine format
        let utiString = uti as String
        let format = ImageFormat.from(uti: utiString)
        
        // Check if format is supported (not .unknown)
        guard format != .unknown else {
            return .failure(.unsupportedFormat)
        }
        
        return .success(format)
    }
}

// MARK: - Image Service Errors

/// Errors that can occur during image service operations
enum ImageServiceError: LocalizedError {
    /// Unable to read the image file
    case cannotReadImage
    
    /// Unable to create the destination file
    case cannotCreateDestination
    
    /// Unable to finalize and write the image
    case cannotFinalize
    
    /// Image format is not supported
    case unsupportedFormat
    
    /// File does not exist at the specified path
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .cannotReadImage:
            return "Cannot read image file"
        case .cannotCreateDestination:
            return "Cannot create destination file"
        case .cannotFinalize:
            return "Cannot finalize image file"
        case .unsupportedFormat:
            return "Unsupported image format"
        case .fileNotFound:
            return "File not found"
        }
    }
}

// MARK: - UTI Constants

/// Uniform Type Identifiers for image formats
private enum UTI {
    static let jpeg = "public.jpeg"
    static let heic = "public.heic"
    static let png = "public.png"
    static let tiff = "public.tiff"
}
