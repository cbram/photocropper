//
//  MetadataReader.swift
//  PhotoCropper
//
//  Handles reading of EXIF/XMP crop metadata from image files
//

import Foundation
import ImageIO
import CoreGraphics

/// Service responsible for reading crop metadata from images
///
/// This class handles reading crop coordinates and related metadata from image files using both:
/// - `exiftool` for comprehensive XMP-dc:Subject tag reading
/// - ImageIO framework as fallback for standard EXIF tags
///
/// ## Metadata Strategy
/// PhotoCropper stores crop information in two places:
/// 1. **Primary**: XMP-dc:Subject tags with `PhotoCropper:` prefix
/// 2. **Fallback**: Standard EXIF DefaultCropOrigin/DefaultCropSize tags
///
/// ## Usage Example
/// ```swift
/// if let metadata = MetadataReader.readCropMetadata(imageURL: url) {
///     print("Found crop: \(metadata.origin) size: \(metadata.size)")
/// }
/// ```
class MetadataReader {
    
    // MARK: - Public Interface
    
    /// Reads crop metadata from an image file
    ///
    /// This method attempts to read crop metadata using the following strategy:
    /// 1. First tries to read PhotoCropper-specific tags from XMP-dc:Subject using exiftool
    /// 2. Falls back to reading standard EXIF DefaultCropOrigin/DefaultCropSize tags
    ///
    /// - Parameter imageURL: URL to the image file
    /// - Returns: `CropMetadata` if crop data is found, otherwise `nil`
    static func readCropMetadata(imageURL: URL) -> CropMetadata? {
        // Try exiftool for PhotoCropper-specific tags first
        if let exiftoolPath = ExiftoolPathResolver.findExiftoolPath() {
            if let cropTags = readPhotoCropperTagsWithExiftool(
                exiftoolPath: exiftoolPath,
                imageURL: imageURL
            ) {
                return parsePhotoCropperTags(cropTags)
            }
        }
        
        // Fallback to standard EXIF tags
        return readStandardEXIFCropMetadata(imageURL: imageURL)
    }
    
    /// Reads existing Subject tags and filters out PhotoCropper tags
    ///
    /// This method is used during metadata writing to preserve existing Subject tags
    /// that were not created by PhotoCropper.
    ///
    /// - Parameters:
    ///   - exiftoolPath: Path to the exiftool executable
    ///   - imageURL: URL to the image file
    /// - Returns: Array of Subject tags that don't start with "PhotoCropper:"
    static func readNonPhotoCropperSubjectTags(
        exiftoolPath: String,
        imageURL: URL
    ) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: exiftoolPath)
        process.arguments = ["-XMP-dc:Subject", "-s3", imageURL.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return []
            }
            
            // exiftool outputs Subject tags line-by-line or comma-separated
            let subjects = output.components(separatedBy: .newlines)
                .flatMap { $0.components(separatedBy: ",") }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.hasPrefix("PhotoCropper:") }
            
            return subjects
        } catch {
            print("⚠️ Error reading Subject tags: \(error)")
            return []
        }
    }
    
    /// Reads existing IPTC Keywords and filters out PhotoCropper keywords
    ///
    /// This method is used during metadata writing to preserve existing IPTC keywords
    /// that were not created by PhotoCropper.
    ///
    /// - Parameters:
    ///   - exiftoolPath: Path to the exiftool executable
    ///   - imageURL: URL to the image file
    /// - Returns: Array of IPTC Keywords that don't start with PhotoCropper-specific prefixes
    static func readNonPhotoCropperIPTCKeywords(
        exiftoolPath: String,
        imageURL: URL
    ) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: exiftoolPath)
        process.arguments = ["-IPTC:Keywords", "-s3", imageURL.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return []
            }
            
            // exiftool outputs Keywords line-by-line or comma-separated
            let keywords = output.components(separatedBy: .newlines)
                .flatMap { $0.components(separatedBy: ",") }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { keyword in
                    !keyword.isEmpty &&
                    !keyword.hasPrefix("CropMode:") &&
                    !keyword.hasPrefix("TargetRatio:") &&
                    !keyword.hasPrefix("OriginalRatio:")
                }
            
            return keywords
        } catch {
            print("⚠️ Error reading IPTC Keywords: \(error)")
            return []
        }
    }
    
    // MARK: - Private Methods - Exiftool Reading
    
    /// Reads PhotoCropper tags from XMP-dc:Subject using exiftool
    ///
    /// - Parameters:
    ///   - exiftoolPath: Path to the exiftool executable
    ///   - imageURL: URL to the image file
    /// - Returns: Dictionary of PhotoCropper tag keys and values, or `nil` if none found
    private static func readPhotoCropperTagsWithExiftool(
        exiftoolPath: String,
        imageURL: URL
    ) -> [String: String]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: exiftoolPath)
        process.arguments = ["-XMP-dc:Subject", "-s3", imageURL.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            print("🔍 Raw exiftool output for XMP-dc:Subject:")
            print("   \(output)")
            
            return parsePhotoCropperSubjectTags(output)
        } catch {
            print("⚠️ Error reading PhotoCropper tags: \(error)")
            return nil
        }
    }
    
    /// Parses PhotoCropper tags from exiftool Subject output
    ///
    /// Handles both formats:
    /// - Line-separated: each tag on its own line
    /// - Comma-separated: all tags in one line separated by ", "
    ///
    /// - Parameter output: Raw exiftool output string
    /// - Returns: Dictionary of PhotoCropper tag keys and values
    private static func parsePhotoCropperSubjectTags(_ output: String) -> [String: String]? {
        var cropTags: [String: String] = [:]
        
        let allText = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let subjectItems = allText.components(separatedBy: ", ")
            .flatMap { $0.components(separatedBy: ",") }  // Also handle without space
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasPrefix("PhotoCropper:") }
        
        print("   Found \(subjectItems.count) PhotoCropper tags")
        
        for subject in subjectItems {
            let withoutPrefix = subject.dropFirst("PhotoCropper:".count)
            let parts = withoutPrefix.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                cropTags[key] = value
                print("   ✓ \(key) = \(value)")
            }
        }
        
        return cropTags.isEmpty ? nil : cropTags
    }
    
    /// Parses PhotoCropper tags dictionary into CropMetadata
    ///
    /// - Parameter tags: Dictionary of PhotoCropper tag keys and values
    /// - Returns: `CropMetadata` if all required tags are present, otherwise `nil`
    private static func parsePhotoCropperTags(_ tags: [String: String]) -> CropMetadata? {
        guard let cropOriginX = tags["CropOriginX"].flatMap(Double.init),
              let cropOriginY = tags["CropOriginY"].flatMap(Double.init),
              let cropWidth = tags["CropWidth"].flatMap(Double.init),
              let cropHeight = tags["CropHeight"].flatMap(Double.init) else {
            return nil
        }
        
        let origin = CGPoint(x: cropOriginX, y: cropOriginY)
        let size = CGSize(width: cropWidth, height: cropHeight)
        
        let cropModeString = tags["CropMode"] ?? CropMode.standard.rawValue
        let mode = CropMode(rawValue: cropModeString) ?? .standard
        let originalRatio = tags["OriginalRatio"] ?? "unknown"
        let targetRatioStr = tags["TargetRatio"] ?? "unknown"
        
        print("📖 PhotoCropper crop metadata found:")
        print("   Origin: (\(origin.x), \(origin.y))")
        print("   Size: (\(size.width), \(size.height))")
        print("   Mode: \(mode.rawValue)")
        print("   Target Ratio: \(targetRatioStr)")
        
        return CropMetadata(
            origin: origin,
            size: size,
            mode: mode,
            originalRatio: originalRatio,
            targetRatio: targetRatioStr
        )
    }
    
    // MARK: - Private Methods - ImageIO Reading
    
    /// Reads crop metadata from standard EXIF tags using ImageIO
    ///
    /// This is the fallback method when exiftool is not available or
    /// PhotoCropper-specific tags are not found.
    ///
    /// - Parameter imageURL: URL to the image file
    /// - Returns: `CropMetadata` if EXIF crop data is found, otherwise `nil`
    private static func readStandardEXIFCropMetadata(imageURL: URL) -> CropMetadata? {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }
        
        guard let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let originArray = exifDict["DefaultCropOrigin"] as? [Double],
              let sizeArray = exifDict["DefaultCropSize"] as? [Double],
              originArray.count == 2,
              sizeArray.count == 2 else {
            return nil
        }
        
        let origin = CGPoint(x: originArray[0], y: originArray[1])
        let size = CGSize(width: sizeArray[0], height: sizeArray[1])
        
        // Read custom tags from IPTC dictionary
        let iptcDict = properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any] ?? [:]
        let cropModeString = iptcDict[EXIFTags.Custom.cropMode] as? String ?? CropMode.standard.rawValue
        let mode = CropMode(rawValue: cropModeString) ?? .standard
        let originalRatio = iptcDict[EXIFTags.Custom.originalRatio] as? String ?? "unknown"
        let targetRatioStr = iptcDict[EXIFTags.Custom.targetRatio] as? String ?? "unknown"
        
        print("📖 Standard EXIF crop metadata found:")
        print("   Origin: (\(origin.x), \(origin.y))")
        print("   Size: (\(size.width), \(size.height))")
        
        return CropMetadata(
            origin: origin,
            size: size,
            mode: mode,
            originalRatio: originalRatio,
            targetRatio: targetRatioStr
        )
    }
}

// MARK: - Exiftool Path Resolver

/// Utility for locating the exiftool executable
///
/// Checks common installation paths in order of preference:
/// 1. Homebrew (Apple Silicon): `/opt/homebrew/bin/exiftool`
/// 2. Homebrew (Intel): `/usr/local/bin/exiftool`
/// 3. System: `/usr/bin/exiftool`
class ExiftoolPathResolver {
    /// Common exiftool installation paths
    private static let exiftoolPaths = [
        "/opt/homebrew/bin/exiftool",  // Homebrew (Apple Silicon)
        "/usr/local/bin/exiftool",     // Homebrew (Intel)
        "/usr/bin/exiftool"             // System
    ]
    
    /// Finds the first available exiftool executable
    ///
    /// - Returns: Path to exiftool if found, otherwise `nil`
    static func findExiftoolPath() -> String? {
        return exiftoolPaths.first { FileManager.default.fileExists(atPath: $0) }
    }
}

