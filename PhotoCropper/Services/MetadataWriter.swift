//
//  MetadataWriter.swift
//  PhotoCropper
//
//  Handles writing of EXIF/XMP crop metadata to image files using exiftool
//

import Foundation
import CoreGraphics

/// Service responsible for writing crop metadata to images using exiftool
///
/// This class handles writing crop coordinates and related metadata to image files using
/// a **three-pass strategy** to ensure data integrity and avoid metadata conflicts.
///
/// ## Three-Pass Strategy
/// 1. **Pass 1 (Delete)**: Remove all existing crop-related tags
/// 2. **Pass 2 (Write)**: Write new crop coordinates and PhotoCropper tags
/// 3. **Pass 3 (Sync)**: Synchronize XMP-dc:Subject → IPTC:Keywords
///
/// ## Why Three Passes?
/// - Ensures clean metadata state without conflicts
/// - Preserves existing non-PhotoCropper tags
/// - Maintains XMP ↔ IPTC synchronization
/// - Prevents tag duplication
///
/// ## Usage Example
/// ```swift
/// let result = MetadataWriter.saveCropMetadata(
///     exiftoolPath: "/opt/homebrew/bin/exiftool",
///     imageURL: url,
///     cropBox: CGRect(x: 100, y: 100, width: 800, height: 600),
///     imageSize: CGSize(width: 1920, height: 1080),
///     targetRatio: .ratio16_9,
///     mode: .mcuSensitive,
///     originalRatio: "16:9"
/// )
/// ```
class MetadataWriter {
    
    // MARK: - Constants
    
    /// PhotoCropper tag prefix for XMP-dc:Subject
    private static let photoCropperPrefix = "PhotoCropper:"
    
    /// Environment for exiftool execution
    private static let exiftoolEnvironment = ["PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"]
    
    // MARK: - Public Interface
    
    /// Saves crop metadata to image file using exiftool (lossless!)
    ///
    /// This method uses a three-pass strategy to ensure metadata integrity:
    /// 1. Delete existing crop tags and Subject/Keywords
    /// 2. Write new crop coordinates and PhotoCropper tags
    /// 3. Synchronize XMP → IPTC
    ///
    /// - Parameters:
    ///   - exiftoolPath: Path to the exiftool executable
    ///   - imageURL: URL to the image file
    ///   - cropBox: Crop rectangle in pixel coordinates
    ///   - imageSize: Original image size
    ///   - targetRatio: Target aspect ratio
    ///   - mode: Crop mode (MCU-sensitive or standard)
    ///   - originalRatio: Original aspect ratio as string
    /// - Returns: `Result<Void, MetadataWriterError>` indicating success or failure
    static func saveCropMetadata(
        exiftoolPath: String,
        imageURL: URL,
        cropBox: CGRect,
        imageSize: CGSize,
        targetRatio: AspectRatio,
        mode: CropMode,
        originalRatio: String
    ) -> Result<Void, MetadataWriterError> {
        
        // Calculate normalized coordinates
        let normalized = MetadataFormatter.normalizeCoordinates(
            cropBox: cropBox,
            imageSize: imageSize
        )
        
        print("📊 Metadata Writer (exiftool):")
        print("  exiftool: \(exiftoolPath)")
        print("  Image: \(imageURL.lastPathComponent)")
        print("  Size: \(imageSize.width)×\(imageSize.height)")
        print("  Crop: \(cropBox)")
        print("  💡 3-Pass Strategy:")
        print("     PASS 1: Delete all XMP-crs:Crop*, XMP-dc:Subject and IPTC:Keywords")
        print("     PASS 2: Write new crop coordinates + filtered Subject tags")
        print("     PASS 3: Synchronize XMP→IPTC and update IPTCDigest")
        
        // Read existing tags to preserve non-PhotoCropper tags
        let existingSubjects = MetadataReader.readNonPhotoCropperSubjectTags(
            exiftoolPath: exiftoolPath,
            imageURL: imageURL
        )
        let existingKeywords = MetadataReader.readNonPhotoCropperIPTCKeywords(
            exiftoolPath: exiftoolPath,
            imageURL: imageURL
        )
        
        if !existingSubjects.isEmpty {
            print("  📋 Preserving \(existingSubjects.count) existing Subject tags (non-PhotoCropper)")
        }
        if !existingKeywords.isEmpty {
            print("  📋 Preserving \(existingKeywords.count) existing IPTC Keywords")
        }
        
        // Pass 1: Delete existing crop tags
        let deleteResult = deleteExistingCropTags(
            exiftoolPath: exiftoolPath,
            imageURL: imageURL
        )
        guard case .success = deleteResult else {
            return deleteResult
        }
        
        // Pass 2: Write new crop tags
        let writeResult = writeNewCropTags(
            exiftoolPath: exiftoolPath,
            imageURL: imageURL,
            normalized: normalized,
            targetRatio: targetRatio,
            mode: mode,
            originalRatio: originalRatio,
            existingSubjects: existingSubjects,
            existingKeywords: existingKeywords
        )
        guard case .success = writeResult else {
            return writeResult
        }
        
        // Pass 3: Synchronize XMP → IPTC
        return synchronizeXMPtoIPTC(
            exiftoolPath: exiftoolPath,
            imageURL: imageURL
        )
    }
    
    // MARK: - Private Methods - Three Passes
    
    /// Pass 1: Deletes all existing crop-related tags
    ///
    /// This removes:
    /// - All XMP-crs:Crop* tags (Lightroom/Adobe tags)
    /// - All XMP-dc:Subject tags
    /// - All IPTC:Keywords
    ///
    /// - Important: Does NOT use `-n` flag to allow deletion of numeric tags like CropConstrainToUnitSquare
    ///
    /// - Parameters:
    ///   - exiftoolPath: Path to exiftool executable
    ///   - imageURL: URL to the image file
    /// - Returns: Result indicating success or failure
    private static func deleteExistingCropTags(
        exiftoolPath: String,
        imageURL: URL
    ) -> Result<Void, MetadataWriterError> {
        print("  🧹 PASS 1: Delete old tags...")
        
        let arguments = buildDeleteArguments(imageURL: imageURL)
        
        let result = ProcessExecutor.executeAndVerify(
            command: exiftoolPath,
            arguments: arguments,
            environment: exiftoolEnvironment
        )
        
        switch result {
        case .success:
            print("  ✅ PASS 1 successful")
            return .success(())
        case .failure(let error):
            print("  ❌ PASS 1 failed: \(error)")
            return .failure(.pass1Failed(underlying: error))
        }
    }
    
    /// Pass 2: Writes new crop coordinates and PhotoCropper tags
    ///
    /// This writes:
    /// - XMP-crs:Crop* tags (Lightroom-compatible)
    /// - PhotoCropper-specific tags in XMP-dc:Subject
    /// - Preserved existing Subject tags (non-PhotoCropper)
    /// - Preserved existing IPTC Keywords
    ///
    /// - Parameters:
    ///   - exiftoolPath: Path to exiftool executable
    ///   - imageURL: URL to the image file
    ///   - normalized: Normalized crop coordinates
    ///   - targetRatio: Target aspect ratio
    ///   - mode: Crop mode
    ///   - originalRatio: Original aspect ratio
    ///   - existingSubjects: Existing non-PhotoCropper Subject tags to preserve
    ///   - existingKeywords: Existing IPTC Keywords to preserve
    /// - Returns: Result indicating success or failure
    private static func writeNewCropTags(
        exiftoolPath: String,
        imageURL: URL,
        normalized: NormalizedCropCoordinates,
        targetRatio: AspectRatio,
        mode: CropMode,
        originalRatio: String,
        existingSubjects: [String],
        existingKeywords: [String]
    ) -> Result<Void, MetadataWriterError> {
        print("  📝 PASS 2: Write new tags...")
        
        let arguments = buildWriteArguments(
            imageURL: imageURL,
            normalized: normalized,
            targetRatio: targetRatio,
            mode: mode,
            originalRatio: originalRatio,
            existingSubjects: existingSubjects,
            existingKeywords: existingKeywords
        )
        
        let result = ProcessExecutor.executeAndVerify(
            command: exiftoolPath,
            arguments: arguments,
            environment: exiftoolEnvironment
        )
        
        switch result {
        case .success:
            print("  ✅ PASS 2 successful")
            return .success(())
        case .failure(let error):
            print("  ❌ PASS 2 failed: \(error)")
            return .failure(.pass2Failed(underlying: error))
        }
    }
    
    /// Pass 3: Synchronizes XMP-dc:Subject → IPTC:Keywords
    ///
    /// This ensures that:
    /// - IPTC:Keywords match XMP-dc:Subject tags
    /// - IPTCDigest is updated correctly
    /// - Metadata is consistent across XMP and IPTC
    ///
    /// - Parameters:
    ///   - exiftoolPath: Path to exiftool executable
    ///   - imageURL: URL to the image file
    /// - Returns: Result indicating success or failure
    private static func synchronizeXMPtoIPTC(
        exiftoolPath: String,
        imageURL: URL
    ) -> Result<Void, MetadataWriterError> {
        print("  🔄 PASS 3: Synchronize XMP→IPTC...")
        
        let arguments = buildSyncArguments(imageURL: imageURL)
        
        let result = ProcessExecutor.executeAndVerify(
            command: exiftoolPath,
            arguments: arguments,
            environment: exiftoolEnvironment
        )
        
        switch result {
        case .success:
            print("  ✅ PASS 3 successful - XMP↔IPTC synchronized, IPTCDigest updated!")
            print("  ✅ Metadata fully written without image modification!")
            return .success(())
        case .failure(let error):
            print("  ❌ PASS 3 failed: \(error)")
            print("  ⚠️ Metadata was written, but synchronization failed")
            return .failure(.pass3Failed(underlying: error))
        }
    }
    
    // MARK: - Private Methods - Argument Builders
    
    /// Builds arguments for Pass 1 (delete)
    ///
    /// - Parameter imageURL: URL to the image file
    /// - Returns: Array of command-line arguments
    private static func buildDeleteArguments(imageURL: URL) -> [String] {
        var args = [String]()
        args.append("-overwrite_original")
        // IMPORTANT: NO "-n" flag here! It prevents deletion of numeric tags like CropConstrainToUnitSquare
        
        // Delete XMP-crs Crop tags
        args.append("-XMP-crs:CropTop=")
        args.append("-XMP-crs:CropLeft=")
        args.append("-XMP-crs:CropBottom=")
        args.append("-XMP-crs:CropRight=")
        args.append("-XMP-crs:CropAngle=")
        args.append("-XMP-crs:CropConstrainToWarp=")
        args.append("-XMP-crs:CropConstrainToUnitSquare=")
        args.append("-XMP-crs:HasCrop=")
        args.append("-XMP-crs:HasSettings=")
        
        // Delete ALL Subject tags (will be rewritten in Pass 2)
        args.append("-XMP-dc:Subject=")
        
        // Delete ALL IPTC Keywords (to avoid duplicates)
        args.append("-IPTC:Keywords=")
        
        args.append(imageURL.path)
        
        return args
    }
    
    /// Builds arguments for Pass 2 (write)
    ///
    /// - Parameters:
    ///   - imageURL: URL to the image file
    ///   - normalized: Normalized crop coordinates
    ///   - targetRatio: Target aspect ratio
    ///   - mode: Crop mode
    ///   - originalRatio: Original aspect ratio
    ///   - existingSubjects: Existing Subject tags to preserve
    ///   - existingKeywords: Existing IPTC Keywords to preserve
    /// - Returns: Array of command-line arguments
    private static func buildWriteArguments(
        imageURL: URL,
        normalized: NormalizedCropCoordinates,
        targetRatio: AspectRatio,
        mode: CropMode,
        originalRatio: String,
        existingSubjects: [String],
        existingKeywords: [String]
    ) -> [String] {
        var args = [String]()
        args.append("-overwrite_original")
        args.append("-n")  // Numeric mode for coordinates
        args.append("-codedcharacterset=utf8")
        
        // Write new XMP-crs Crop tags (Lightroom-compatible)
        args.append("-XMP-crs:CropTop=\(normalized.origin.y)")
        args.append("-XMP-crs:CropLeft=\(normalized.origin.x)")
        args.append("-XMP-crs:CropBottom=\(normalized.cropBottom)")
        args.append("-XMP-crs:CropRight=\(normalized.cropRight)")
        
        // Preserve existing (non-PhotoCropper) Subject tags
        for subject in existingSubjects {
            args.append("-XMP-dc:Subject+=\(subject)")
        }
        
        // Write new PhotoCropper Subject tags
        args.append("-XMP-dc:Subject+=\(photoCropperPrefix)CropMode=\(mode.rawValue)")
        args.append("-XMP-dc:Subject+=\(photoCropperPrefix)TargetRatio=\(targetRatio.id)")
        args.append("-XMP-dc:Subject+=\(photoCropperPrefix)OriginalRatio=\(originalRatio)")
        args.append("-XMP-dc:Subject+=\(photoCropperPrefix)CropOriginX=\(normalized.origin.x)")
        args.append("-XMP-dc:Subject+=\(photoCropperPrefix)CropOriginY=\(normalized.origin.y)")
        args.append("-XMP-dc:Subject+=\(photoCropperPrefix)CropWidth=\(normalized.size.width)")
        args.append("-XMP-dc:Subject+=\(photoCropperPrefix)CropHeight=\(normalized.size.height)")
        
        // Re-add existing (non-PhotoCropper) IPTC Keywords
        for keyword in existingKeywords {
            args.append("-IPTC:Keywords+=\(keyword)")
        }
        
        args.append(imageURL.path)
        
        return args
    }
    
    /// Builds arguments for Pass 3 (sync)
    ///
    /// - Parameter imageURL: URL to the image file
    /// - Returns: Array of command-line arguments
    private static func buildSyncArguments(imageURL: URL) -> [String] {
        var args = [String]()
        args.append("-overwrite_original")
        args.append("-codedcharacterset=utf8")
        
        // Synchronize XMP-dc:Subject → IPTC:Keywords
        // This is the exact command that works for the user!
        args.append("-IPTC:Keywords<XMP-dc:Subject")
        
        // Force IPTCDigest recalculation to ensure XMP and IPTC are in sync
        args.append("-IPTCDigest=new")
        
        args.append(imageURL.path)
        
        return args
    }
}

// MARK: - Metadata Formatter

/// Utility for formatting and normalizing metadata coordinates
struct MetadataFormatter {
    /// Number of decimal places for coordinate rounding
    private static let decimalPlaces = 5
    
    /// Normalizes crop coordinates to 0.0-1.0 range
    ///
    /// - Parameters:
    ///   - cropBox: Crop rectangle in pixel coordinates
    ///   - imageSize: Original image size
    /// - Returns: Normalized crop coordinates rounded to 5 decimal places
    static func normalizeCoordinates(
        cropBox: CGRect,
        imageSize: CGSize
    ) -> NormalizedCropCoordinates {
        let normalizedOriginX = round(cropBox.origin.x / imageSize.width, places: decimalPlaces)
        let normalizedOriginY = round(cropBox.origin.y / imageSize.height, places: decimalPlaces)
        let normalizedWidth = round(cropBox.width / imageSize.width, places: decimalPlaces)
        let normalizedHeight = round(cropBox.height / imageSize.height, places: decimalPlaces)
        
        let origin = CGPoint(x: normalizedOriginX, y: normalizedOriginY)
        let size = CGSize(width: normalizedWidth, height: normalizedHeight)
        let cropBottom = round(normalizedOriginY + normalizedHeight, places: decimalPlaces)
        let cropRight = round(normalizedOriginX + normalizedWidth, places: decimalPlaces)
        
        return NormalizedCropCoordinates(
            origin: origin,
            size: size,
            cropBottom: cropBottom,
            cropRight: cropRight
        )
    }
    
    /// Rounds a value to a specified number of decimal places
    ///
    /// - Parameters:
    ///   - value: Value to round
    ///   - places: Number of decimal places
    /// - Returns: Rounded value
    private static func round(_ value: Double, places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (value * multiplier).rounded() / multiplier
    }
}

// MARK: - Supporting Types

/// Normalized crop coordinates in 0.0-1.0 range
struct NormalizedCropCoordinates {
    /// Normalized origin (top-left corner)
    let origin: CGPoint
    
    /// Normalized size
    let size: CGSize
    
    /// Normalized bottom coordinate (origin.y + size.height)
    let cropBottom: Double
    
    /// Normalized right coordinate (origin.x + size.width)
    let cropRight: Double
}

/// Errors that can occur during metadata writing
enum MetadataWriterError: LocalizedError {
    case pass1Failed(underlying: ProcessExecutorError)
    case pass2Failed(underlying: ProcessExecutorError)
    case pass3Failed(underlying: ProcessExecutorError)
    
    var errorDescription: String? {
        switch self {
        case .pass1Failed(let error):
            return "Pass 1 (Delete) failed: \(error.localizedDescription)"
        case .pass2Failed(let error):
            return "Pass 2 (Write) failed: \(error.localizedDescription)"
        case .pass3Failed(let error):
            return "Pass 3 (Sync) failed: \(error.localizedDescription)"
        }
    }
}

