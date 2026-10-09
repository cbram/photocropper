//
//  ImageData.swift
//  PhotoCropper
//
//  Represents a loaded image with all its metadata
//

import Foundation
import AppKit
import CoreGraphics
import ImageIO
import Combine
import UniformTypeIdentifiers

// MARK: - Image Format

/// Supported image format types
///
/// Represents the various image formats that can be loaded and processed
/// by the application.
enum ImageFormat {
    case jpeg
    case heic
    case png
    case tiff
    case unknown
    
    /// Human-readable name for the format
    var displayName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .heic: return "HEIC"
        case .png: return "PNG"
        case .tiff: return "TIFF"
        case .unknown: return "Unknown"
        }
    }
    
    /// Indicates whether this format supports lossless MCU-based cropping
    var supportsMCUCropping: Bool {
        return self == .jpeg
    }

    /// Types a matching file extension may conform to, empty for unknown formats
    /// (public.heic does not conform to public.heif, so both are listed)
    private var contentTypes: [UTType] {
        switch self {
        case .jpeg: return [.jpeg]
        case .heic: return [.heic, .heif]
        case .png: return [.png]
        case .tiff: return [.tiff]
        case .unknown: return []
        }
    }

    /// Warning if the file extension of `url` does not match this (content-detected) format.
    ///
    /// exiftool picks the writer by file extension, so a JPEG named `.png` cannot be written.
    func extensionMismatchWarning(for url: URL) -> String? {
        guard !contentTypes.isEmpty else { return nil }
        if let extensionType = UTType(filenameExtension: url.pathExtension),
           contentTypes.contains(where: { extensionType.conforms(to: $0) }) {
            return nil
        }
        return "File is a \(displayName) but has the extension .\(url.pathExtension) — rename it to a \(displayName) extension before writing metadata."
    }
}

// MARK: - Image Data

/// Represents a loaded image with comprehensive metadata
///
/// This class encapsulates all information about a loaded image, including:
/// - The image itself and its dimensions
/// - EXIF metadata (orientation, creation date)
/// - Format information
/// - Crop metadata (if previously saved)
/// - MCU information for JPEG images
///
/// The class is an `ObservableObject` to support SwiftUI reactive updates.
///
/// Example:
/// ```swift
/// let imageData = ImageData(url: imageURL)
/// print("Format: \(imageData.format.displayName)")
/// print("Size: \(imageData.pixelSize)")
/// ```
class ImageData: ObservableObject {
    
    // MARK: - Properties
    
    /// The URL of the image file
    let url: URL
    
    /// The loaded NSImage for display purposes
    @Published var image: NSImage?
    
    /// Original pixel dimensions (before orientation correction)
    @Published var pixelSize: CGSize = .zero
    
    /// EXIF orientation value (1-8)
    ///
    /// - Note: 1 = Normal, 3 = 180° rotated, 6 = 90° CW, 8 = 90° CCW, etc.
    @Published var exifOrientation: Int = 1
    
    /// Display size after applying EXIF orientation correction
    @Published var displaySize: CGSize = .zero
    
    /// Detected image format
    @Published var format: ImageFormat = .unknown
    
    /// Simplified aspect ratio as a string (e.g., "3:2", "16:9")
    @Published var aspectRatioString: String = ""
    
    /// Image creation date extracted from EXIF metadata
    @Published var creationDate: Date?
    
    /// MCU (Minimum Coded Unit) size for JPEG images
    ///
    /// Only applicable for JPEG format. Typically 8×8 or 16×16 pixels.
    @Published var mcuSize: CGSize?
    
    /// Previously saved crop metadata, if any
    @Published var cropMetadata: CropMetadata?
    
    /// Flag indicating whether the image has saved crop metadata
    @Published var hasCropMetadata: Bool = false
    
    /// Raw metadata dictionary from ImageIO
    ///
    /// Contains all EXIF, TIFF, and other metadata extracted from the image file.
    var metadata: [String: Any] = [:]
    
    // MARK: - Initialization
    
    /// Initializes image data from a file URL
    ///
    /// - Parameter url: The URL of the image file to load
    ///
    /// - Note: Image loading happens synchronously in the initializer.
    ///         Consider using async loading for better performance with large images.
    init(url: URL) {
        self.url = url
        loadImage()
    }
    
    // MARK: - Image Loading
    
    /// Loads the image and extracts all metadata
    ///
    /// This method performs the following operations:
    /// 1. Loads the image using ImageIO
    /// 2. Determines the image format
    /// 3. Extracts pixel dimensions
    /// 4. Reads EXIF orientation
    /// 5. Calculates display size
    /// 6. Parses creation date
    /// 7. Reads existing crop metadata if present
    ///
    /// - Note: Failed operations are handled gracefully with default values
    private func loadImage() {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            print("⚠️ Failed to load image: \(url.lastPathComponent)")
            return
        }
        
        // Determine image format from UTI
        if let uti = CGImageSourceGetType(imageSource) {
            format = ImageFormat.from(uti: uti as String)
        }
        
        // Extract pixel dimensions
        pixelSize = CGSize(width: imageRef.width, height: imageRef.height)
        
        // Load properties once and reuse
        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]
        
        // Extract EXIF orientation
        if let orientation = properties?[kCGImagePropertyOrientation as String] as? Int {
            exifOrientation = orientation
        }
        
        // Calculate display size (corrected for orientation)
        displaySize = Self.calculateDisplaySize(from: pixelSize, orientation: exifOrientation)
        
        // Calculate simplified aspect ratio
        let ratio = AspectRatio.calculateSimplified(from: displaySize)
        aspectRatioString = "\(ratio.width):\(ratio.height)"
        
        // Extract creation date from EXIF
        if let exifDict = properties?[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateTimeOriginal = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            creationDate = ExifDateParser.parseDate(from: dateTimeOriginal)
        }
        
        // Store raw metadata
        if let properties = properties {
            metadata = properties
        }
        
        // Create NSImage for display
        image = NSImage(cgImage: imageRef, size: displaySize)
        
        // Read existing crop metadata if present
        if let cropMeta = MetadataService.readCropMetadata(imageURL: url) {
            cropMetadata = cropMeta
            hasCropMetadata = true
            print("✅ Image has saved crop metadata: \(url.lastPathComponent)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Calculates display size based on EXIF orientation
    ///
    /// For orientations 5-8 (90° or 270° rotation), width and height are swapped.
    ///
    /// - Parameters:
    ///   - size: The original pixel size
    ///   - orientation: EXIF orientation value (1-8)
    /// - Returns: The corrected display size
    ///
    /// - Note: Orientation values:
    ///   - 1, 2: Normal or horizontal flip
    ///   - 3, 4: 180° rotation or vertical flip
    ///   - 5, 6, 7, 8: 90° or 270° rotation → swap dimensions
    private static func calculateDisplaySize(from size: CGSize, orientation: Int) -> CGSize {
        switch orientation {
        case 5, 6, 7, 8:
            // 90° or 270° rotation: swap width and height
            return CGSize(width: size.height, height: size.width)
        default:
            // No dimension change needed
            return size
        }
    }
}

// MARK: - Image Format Extension

extension ImageFormat {
    /// Creates an ImageFormat from a UTI (Uniform Type Identifier) string
    ///
    /// - Parameter uti: The UTI string (e.g., "public.jpeg")
    /// - Returns: The corresponding ImageFormat case
    ///
    /// Example:
    /// ```swift
    /// let format = ImageFormat.from(uti: "public.jpeg")
    /// // format == .jpeg
    /// ```
    static func from(uti: String) -> ImageFormat {
        switch uti {
        case "public.jpeg":
            return .jpeg
        case "public.heic", "public.heif":
            return .heic
        case "public.png":
            return .png
        case "public.tiff":
            return .tiff
        default:
            return .unknown
        }
    }
}

// MARK: - EXIF Date Parser Extension

extension ExifDateParser {
    /// Parses an EXIF date string into a Date object
    ///
    /// This is a convenience wrapper around the ExifDateParser service
}
