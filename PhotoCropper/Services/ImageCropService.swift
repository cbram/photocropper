//
//  ImageCropService.swift
//  PhotoCropper
//
//  Service for standard image cropping (non-MCU, all formats)
//

import Foundation
import AppKit
import CoreGraphics
import ImageIO

/// Service for standard image cropping operations
///
/// This service handles physical cropping of images in all supported formats
/// (JPEG, HEIC, PNG, TIFF, etc.) using CoreGraphics. Unlike MCU-sensitive
/// cropping, this method re-encodes the image but works with all formats.
class ImageCropService {
    
    // MARK: - Errors
    
    enum ImageCropError: LocalizedError {
        case cannotReadImage
        case cannotCreateCGImage
        case invalidCropRect
        case cannotCreateDestination
        case cannotWriteImage
        
        var errorDescription: String? {
            switch self {
            case .cannotReadImage:
                return "Cannot read source image"
            case .cannotCreateCGImage:
                return "Cannot create CGImage from source"
            case .invalidCropRect:
                return "Crop rectangle is outside image bounds"
            case .cannotCreateDestination:
                return "Cannot create image destination"
            case .cannotWriteImage:
                return "Cannot write cropped image to disk"
            }
        }
    }
    
    // MARK: - Standard Cropping
    
    /// Crops an image to the specified rectangle (standard mode)
    ///
    /// This method physically crops the image and re-encodes it in its original format.
    /// All metadata (EXIF, XMP, IPTC) is preserved in the output file.
    ///
    /// - Parameters:
    ///   - imageURL: URL of the source image
    ///   - cropRect: Rectangle to crop (in pixel coordinates)
    ///   - outputURL: URL where the cropped image will be saved
    ///
    /// - Returns: Result indicating success or failure with error
    ///
    /// - Note: This method re-encodes the image, which may result in quality loss
    ///   for lossy formats like JPEG. The output quality is set to maximum (1.0).
    static func cropStandard(
        imageURL: URL,
        cropRect: CGRect,
        outputURL: URL
    ) -> Result<Void, ImageCropError> {
        
        print("✂️ ImageCropService: Standard cropping")
        print("  Source: \(imageURL.lastPathComponent)")
        print("  Crop rect: \(cropRect)")
        print("  Output: \(outputURL.lastPathComponent)")
        
        // Load image source
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            print("  ❌ Cannot read image source")
            return .failure(.cannotReadImage)
        }
        
        // Get UTI (format) of the source image
        guard let imageUTI = CGImageSourceGetType(imageSource) else {
            print("  ❌ Cannot determine image format")
            return .failure(.cannotReadImage)
        }
        
        print("  Format: \(imageUTI)")
        
        // Load CGImage
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            print("  ❌ Cannot create CGImage")
            return .failure(.cannotCreateCGImage)
        }
        
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        
        print("  Image size: \(imageWidth)×\(imageHeight)")
        
        // Validate crop rectangle
        guard cropRect.origin.x >= 0,
              cropRect.origin.y >= 0,
              cropRect.maxX <= imageWidth,
              cropRect.maxY <= imageHeight,
              cropRect.width > 0,
              cropRect.height > 0 else {
            print("  ❌ Invalid crop rectangle")
            return .failure(.invalidCropRect)
        }
        
        // Perform crop
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            print("  ❌ Cropping failed")
            return .failure(.invalidCropRect)
        }
        
        print("  ✅ Image cropped to \(croppedCGImage.width)×\(croppedCGImage.height)")
        
        // Read original metadata to preserve it
        let originalMetadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]
        
        // Create destination
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            imageUTI,
            1,
            nil
        ) else {
            print("  ❌ Cannot create destination")
            return .failure(.cannotCreateDestination)
        }
        
        // Prepare properties for writing
        // Start with original metadata to preserve all settings including compression
        var imageProperties: [String: Any] = [:]
        
        if let metadata = originalMetadata {
            for (key, value) in metadata {
                imageProperties[key] = value
            }
        }
        
        // For HEIC/HEIF files, use reasonable compression to maintain small file sizes
        // For JPEG, use 0.85 quality as a good balance
        // Note: We don't override if metadata already contains quality settings
        let formatString = imageUTI as String
        if formatString.contains("heic") || formatString.contains("heif") {
            // HEIC: Use 0.75 for good compression (HEIC is very efficient)
            imageProperties[kCGImageDestinationLossyCompressionQuality as String] = 0.75
            print("  ℹ️ HEIC format: Using compression quality 0.75")
        } else if formatString.contains("jpeg") {
            // JPEG: Use 0.85 for good quality
            imageProperties[kCGImageDestinationLossyCompressionQuality as String] = 0.85
            print("  ℹ️ JPEG format: Using compression quality 0.85")
        } else {
            // PNG/TIFF and other lossless formats: no compression quality needed
            print("  ℹ️ Lossless format: No compression quality set")
        }
        
        // Remove any existing crop metadata to prevent double-cropping
        // Since we physically cropped, there should be no crop metadata in the output
        if var exifDict = imageProperties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            exifDict.removeValue(forKey: "DefaultCropOrigin")
            exifDict.removeValue(forKey: "DefaultCropSize")
            imageProperties[kCGImagePropertyExifDictionary as String] = exifDict
        }
        
        // Remove XMP crop tags
        if var xmpDict = imageProperties["http://ns.adobe.com/xap/1.0/" as String] as? [String: Any] {
            xmpDict.removeValue(forKey: "crs:CropTop")
            xmpDict.removeValue(forKey: "crs:CropLeft")
            xmpDict.removeValue(forKey: "crs:CropBottom")
            xmpDict.removeValue(forKey: "crs:CropRight")
            imageProperties["http://ns.adobe.com/xap/1.0/" as String] = xmpDict
        }
        
        // Update image dimensions in metadata
        if var tiffDict = imageProperties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            tiffDict["ImageWidth"] = croppedCGImage.width
            tiffDict["ImageLength"] = croppedCGImage.height
            imageProperties[kCGImagePropertyTIFFDictionary as String] = tiffDict
        }
        
        // Also update PixelXDimension and PixelYDimension in EXIF
        if var exifDict = imageProperties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            exifDict["PixelXDimension"] = croppedCGImage.width
            exifDict["PixelYDimension"] = croppedCGImage.height
            imageProperties[kCGImagePropertyExifDictionary as String] = exifDict
        }
        
        // Add cropped image to destination with metadata
        CGImageDestinationAddImage(destination, croppedCGImage, imageProperties as CFDictionary)
        
        // Finalize and write to disk
        guard CGImageDestinationFinalize(destination) else {
            print("  ❌ Cannot finalize destination")
            return .failure(.cannotWriteImage)
        }
        
        print("  ✅ Cropped image saved successfully")
        
        return .success(())
    }
    
    // MARK: - Validation
    
    /// Validates if a crop rectangle is within image bounds
    ///
    /// - Parameters:
    ///   - cropRect: The crop rectangle to validate
    ///   - imageSize: The size of the source image
    ///
    /// - Returns: `true` if the crop rectangle is valid
    static func isValidCropRect(_ cropRect: CGRect, for imageSize: CGSize) -> Bool {
        return cropRect.origin.x >= 0 &&
               cropRect.origin.y >= 0 &&
               cropRect.maxX <= imageSize.width &&
               cropRect.maxY <= imageSize.height &&
               cropRect.width > 0 &&
               cropRect.height > 0
    }
}

