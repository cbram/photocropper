//
//  MetadataService.swift
//  PhotoCropper
//
//  Handles EXIF/XMP metadata: Reading and writing of crop coordinates
//
//  This service acts as a facade, delegating to specialized components:
//  - MetadataReader: Reading crop metadata
//  - MetadataWriter: Writing crop metadata (via exiftool)
//  - ImageIO fallback: Writing metadata when exiftool is unavailable
//

import Foundation
import ImageIO
import CoreGraphics

/// Facade service for metadata operations (EXIF/XMP)
///
/// This service provides a simplified interface for reading and writing crop metadata.
/// It automatically selects the best strategy based on available tools:
/// - **Primary**: Uses `exiftool` via `MetadataWriter` (lossless, no image modification)
/// - **Fallback**: Uses ImageIO framework (may re-encode image)
///
/// ## Architecture
/// ```
/// MetadataService (Facade)
///     ├── MetadataReader: Reading crop metadata
///     ├── MetadataWriter: Writing via exiftool (preferred)
///     └── ImageIO Fallback: Writing when exiftool unavailable
/// ```
///
/// ## Usage Example
/// ```swift
/// // Save metadata
/// let result = MetadataService.saveCropMetadata(
///     imageURL: url,
///     cropBox: CGRect(x: 100, y: 100, width: 800, height: 600),
///     imageSize: CGSize(width: 1920, height: 1080),
///     targetRatio: .ratio16_9,
///     mode: .mcuSensitive,
///     originalRatio: "16:9"
/// )
///
/// // Read metadata
/// if let metadata = MetadataService.readCropMetadata(imageURL: url) {
///     print("Crop found: \(metadata.origin), size: \(metadata.size)")
/// }
/// ```
class MetadataService {
    
    // MARK: - Constants
    
    /// XMP namespace URIs
    private enum XMPNamespace {
        static let adobeXAP = "http://ns.adobe.com/xap/1.0/"
        static let photoCropper = "http://photocropper.app/1.0/"
    }
    
    /// Number of decimal places for coordinate rounding
    private static let decimalPlaces = 5
    
    // MARK: - Public Interface
    
    /// Saves crop metadata to an image file
    ///
    /// This method automatically selects the best writing strategy:
    /// 1. **Preferred**: Uses exiftool (lossless, no image modification)
    /// 2. **Fallback**: Uses ImageIO (may re-encode image)
    ///
    /// - Parameters:
    ///   - imageURL: URL to the image file
    ///   - cropBox: Crop rectangle in pixel coordinates
    ///   - imageSize: Original image size
    ///   - targetRatio: Target aspect ratio
    ///   - mode: Crop mode (MCU-sensitive or standard)
    ///   - originalRatio: Original aspect ratio as string
    /// - Returns: Result indicating success or failure
    static func saveCropMetadata(
        imageURL: URL,
        cropBox: CGRect,
        imageSize: CGSize,
        targetRatio: AspectRatio,
        mode: CropMode,
        originalRatio: String
    ) -> Result<Void, Error> {
        
        // Try exiftool first (preferred method)
        guard let exiftoolPath = ExiftoolPathResolver.findExiftoolPath() else {
            print("⚠️ exiftool not found - falling back to ImageIO")
            return saveWithImageIO(
                imageURL: imageURL,
                cropBox: cropBox,
                imageSize: imageSize,
                targetRatio: targetRatio,
                mode: mode,
                originalRatio: originalRatio
            )
        }
        
        return saveWithExiftool(
            exiftoolPath: exiftoolPath,
            imageURL: imageURL,
            cropBox: cropBox,
            imageSize: imageSize,
            targetRatio: targetRatio,
            mode: mode,
            originalRatio: originalRatio
        )
    }
    
    /// Reads crop metadata from an image file
    ///
    /// - Parameter imageURL: URL to the image file
    /// - Returns: `CropMetadata` if crop data found, otherwise `nil`
    static func readCropMetadata(imageURL: URL) -> CropMetadata? {
        return MetadataReader.readCropMetadata(imageURL: imageURL)
    }
    
    /// Checks if XMP data exists in an image file
    ///
    /// - Parameter imageURL: URL to the image file
    /// - Returns: `true` if XMP data exists, otherwise `false`
    static func hasXMPData(imageURL: URL) -> Bool {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return false
        }
        
        // Check various possible XMP locations
        return properties[kCGImagePropertyMakerAppleDictionary as String] != nil ||
               properties[kCGImagePropertyIPTCDictionary as String] != nil
    }
    
    /// Ensures XMP data exists in image file
    ///
    /// - Parameter imageURL: URL to the image file
    /// - Returns: Result indicating success or failure
    ///
    /// - Note: Currently a no-op; XMP data is created automatically when saving metadata
    static func ensureXMPData(imageURL: URL) -> Result<Void, Error> {
        if hasXMPData(imageURL: imageURL) {
            return .success(())
        }
        
        // XMP data will be created automatically on next metadata save
        return .success(())
    }
    
    // MARK: - Private Methods - Writing Strategies
    
    /// Saves crop metadata using exiftool (preferred, lossless)
    ///
    /// This method delegates to `MetadataWriter` which uses exiftool's three-pass strategy
    /// to ensure metadata integrity without modifying the image data.
    ///
    /// - Parameters:
    ///   - exiftoolPath: Path to the exiftool executable
    ///   - imageURL: URL to the image file
    ///   - cropBox: Crop rectangle in pixel coordinates
    ///   - imageSize: Original image size
    ///   - targetRatio: Target aspect ratio
    ///   - mode: Crop mode
    ///   - originalRatio: Original aspect ratio
    /// - Returns: Result indicating success or failure
    private static func saveWithExiftool(
        exiftoolPath: String,
        imageURL: URL,
        cropBox: CGRect,
        imageSize: CGSize,
        targetRatio: AspectRatio,
        mode: CropMode,
        originalRatio: String
    ) -> Result<Void, Error> {
        let result = MetadataWriter.saveCropMetadata(
            exiftoolPath: exiftoolPath,
            imageURL: imageURL,
            cropBox: cropBox,
            imageSize: imageSize,
            targetRatio: targetRatio,
            mode: mode,
            originalRatio: originalRatio
        )
        
        return result.mapError { $0 as Error }
    }
    
    /// Saves crop metadata using ImageIO framework (fallback, may re-encode)
    ///
    /// This fallback method is used when exiftool is not available.
    /// **Warning**: This method may re-encode the image, potentially changing file size
    /// and losing some metadata like MakerNotes.
    ///
    /// - Parameters:
    ///   - imageURL: URL to the image file
    ///   - cropBox: Crop rectangle in pixel coordinates
    ///   - imageSize: Original image size
    ///   - targetRatio: Target aspect ratio
    ///   - mode: Crop mode
    ///   - originalRatio: Original aspect ratio
    /// - Returns: Result indicating success or failure
    private static func saveWithImageIO(
        imageURL: URL,
        cropBox: CGRect,
        imageSize: CGSize,
        targetRatio: AspectRatio,
        mode: CropMode,
        originalRatio: String
    ) -> Result<Void, Error> {
        
        print("⚠️ Using ImageIO fallback (may re-encode image!)")
        
        // Normalize coordinates
        let normalized = MetadataFormatter.normalizeCoordinates(
            cropBox: cropBox,
            imageSize: imageSize
        )
        
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            return .failure(MetadataServiceError.cannotReadImage)
        }
        
        // Read existing metadata
        var metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] ?? [:]
        
        print("📊 Metadata Service (ImageIO):")
        print("  Image Size: \(imageSize.width)×\(imageSize.height)")
        print("  Crop Box: \(cropBox)")
        print("  Normalized: origin=(\(normalized.origin.x), \(normalized.origin.y)) size=(\(normalized.size.width), \(normalized.size.height))")
        
        // Update EXIF dictionary
        var exifDict = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        exifDict["DefaultCropOrigin"] = [NSNumber(value: normalized.origin.x), NSNumber(value: normalized.origin.y)]
        exifDict["DefaultCropSize"] = [NSNumber(value: normalized.size.width), NSNumber(value: normalized.size.height)]
        metadata[kCGImagePropertyExifDictionary as String] = exifDict
        
        // Update XMP dictionary with Adobe Lightroom-compatible tags
        var xmpDict = metadata[XMPNamespace.adobeXAP as String] as? [String: Any] ?? [:]
        xmpDict["crs:CropTop"] = NSNumber(value: normalized.origin.y)
        xmpDict["crs:CropLeft"] = NSNumber(value: normalized.origin.x)
        xmpDict["crs:CropBottom"] = NSNumber(value: normalized.cropBottom)
        xmpDict["crs:CropRight"] = NSNumber(value: normalized.cropRight)
        metadata[XMPNamespace.adobeXAP as String] = xmpDict
        
        // Add custom PhotoCropper tags to IPTC dictionary
        var iptcDict = metadata[kCGImagePropertyIPTCDictionary as String] as? [String: Any] ?? [:]
        iptcDict[EXIFTags.Custom.cropMode] = mode.rawValue
        iptcDict[EXIFTags.Custom.originalRatio] = originalRatio
        iptcDict[EXIFTags.Custom.targetRatio] = targetRatio.id
        iptcDict[EXIFTags.Custom.cropDateTime] = ISO8601DateFormatter().string(from: Date())
        metadata[kCGImagePropertyIPTCDictionary as String] = iptcDict
        
        print("  ✅ Metadata prepared (EXIF, XMP, IPTC)")
        
        // Write to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("photocropper_\(UUID().uuidString).\(imageURL.pathExtension)")
        
        guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, CGImageSourceGetType(imageSource)!, 1, nil) else {
            return .failure(MetadataServiceError.cannotCreateDestination)
        }
        
        // Use merge mode to preserve all existing metadata
        let options: [String: Any] = [
            kCGImageDestinationLossyCompressionQuality as String: 1.0,  // Maximum quality
            kCGImageDestinationMetadata as String: metadata,
            kCGImageDestinationMergeMetadata as String: true  // Merge instead of replace
        ]
        
        CGImageDestinationAddImageFromSource(destination, imageSource, 0, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: tempURL)
            return .failure(MetadataServiceError.cannotFinalize)
        }
        
        print("  ✅ Image written with metadata (merge mode)")
        
        // Replace original file with atomic operation
        return replaceFileAtomically(original: imageURL, replacement: tempURL)
    }
    
    // MARK: - Private Helpers
    
    /// Replaces a file atomically with backup/restore on failure
    ///
    /// - Parameters:
    ///   - original: URL of the original file to replace
    ///   - replacement: URL of the replacement file
    /// - Returns: Result indicating success or failure
    private static func replaceFileAtomically(original: URL, replacement: URL) -> Result<Void, Error> {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let backupURL = tempDir.appendingPathComponent("photocropper_backup_\(UUID().uuidString).\(original.pathExtension)")
        
        do {
            // Create backup of original file
            if fileManager.fileExists(atPath: original.path) {
                try fileManager.moveItem(at: original, to: backupURL)
            }
            
            // Move replacement to original location
            do {
                try fileManager.moveItem(at: replacement, to: original)
                // Delete backup on success
                try? fileManager.removeItem(at: backupURL)
                return .success(())
            } catch {
                // Restore backup on failure
                if fileManager.fileExists(atPath: backupURL.path) {
                    try? fileManager.moveItem(at: backupURL, to: original)
                }
                try? fileManager.removeItem(at: replacement)
                return .failure(error)
            }
        } catch {
            try? fileManager.removeItem(at: replacement)
            return .failure(error)
        }
    }
}

// MARK: - Error Types

/// Errors that can occur during metadata operations
enum MetadataServiceError: LocalizedError {
    case cannotReadImage
    case cannotCreateDestination
    case cannotFinalize
    case exiftoolFailed
    case xmpCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .cannotReadImage:
            return "Could not read image"
        case .cannotCreateDestination:
            return "Could not create destination file"
        case .cannotFinalize:
            return "Could not finalize metadata"
        case .exiftoolFailed:
            return "exiftool could not write metadata"
        case .xmpCreationFailed:
            return "Could not create XMP data"
        }
    }
}
