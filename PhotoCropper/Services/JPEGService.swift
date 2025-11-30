//
//  JPEGService.swift
//  PhotoCropper
//
//  Handles JPEG-specific operations: MCU parsing, jpegtran wrapper
//

import Foundation
import AppKit
import CoreGraphics

// MARK: - Constants

/// Constants for JPEG operations
private enum JPEGConstants {
    /// Standard MCU (Minimum Coded Unit) sizes for JPEG images
    static let standardMCUSize = CGSize(width: 8, height: 8)
    
    /// Possible installation paths for jpegtran binary
    static let jpegtranPaths = [
        "/opt/homebrew/bin/jpegtran",  // Homebrew on Apple Silicon
        "/usr/local/bin/jpegtran",      // Homebrew on Intel
        "/usr/bin/jpegtran",            // System installation
        "/opt/local/bin/jpegtran"       // MacPorts
    ]
    
    /// Environment PATH for spawned processes
    static let processPath = "PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
}

// MARK: - JPEG Service

/// Service for JPEG-specific operations with MCU (Minimum Coded Unit) support
///
/// This service provides lossless JPEG cropping using the jpegtran tool,
/// MCU grid snapping for optimal compression preservation, and JPEG format detection.
///
/// ## MCU (Minimum Coded Unit)
/// JPEG images are compressed in blocks called MCUs, typically 8×8 or 16×16 pixels.
/// For truly lossless cropping, crop coordinates must align with MCU boundaries.
///
/// ## jpegtran Requirement
/// This service requires the jpegtran command-line tool from libjpeg-turbo.
/// Install via Homebrew: `brew install jpeg-turbo`
class JPEGService {
    
    // MARK: - jpegtran Availability
    
    /// Checks if jpegtran is available on the system
    ///
    /// Searches for jpegtran in common installation paths:
    /// - `/opt/homebrew/bin/jpegtran` (Homebrew on Apple Silicon)
    /// - `/usr/local/bin/jpegtran` (Homebrew on Intel)
    /// - `/usr/bin/jpegtran` (System installation)
    /// - `/opt/local/bin/jpegtran` (MacPorts)
    ///
    /// - Returns: `true` if jpegtran is found, `false` otherwise
    static func isJPEGTranAvailable() -> Bool {
        let available = findJPEGTranPath() != nil
        print("🔍 jpegtran available: \(available)")
        return available
    }
    
    /// Finds the path to the jpegtran executable
    ///
    /// - Returns: Full path to jpegtran if found, `nil` otherwise
    private static func findJPEGTranPath() -> String? {
        return JPEGConstants.jpegtranPaths.first { 
            FileManager.default.fileExists(atPath: $0) 
        }
    }
    
    // MARK: - MCU Detection & Snapping
    
    /// Detects the MCU (Minimum Coded Unit) size for a JPEG image
    ///
    /// This is a simplified implementation that returns the standard MCU size (8×8).
    /// A complete implementation would use libjpeg to determine the actual MCU size
    /// based on chroma subsampling (4:4:4, 4:2:2, 4:2:0, etc.).
    ///
    /// - Parameter imageURL: URL of the JPEG file
    /// - Returns: MCU size, or `nil` if detection fails
    ///
    /// ## Common MCU Sizes
    /// - **8×8**: Standard for 4:4:4 subsampling (no chroma subsampling)
    /// - **8×16** or **16×8**: Common for 4:2:2 subsampling
    /// - **16×16**: Common for 4:2:0 subsampling (most JPEGs)
    ///
    /// - Note: Currently returns 8×8 for all images. For precise detection,
    ///   libjpeg integration would be needed.
    static func detectMCUSize(for imageURL: URL) -> CGSize? {
        // Verify it's a valid image
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              CGImageSourceCreateImageAtIndex(imageSource, 0, nil) != nil else {
            return nil
        }
        
        // Return standard MCU size (8×8)
        // TODO: Implement actual MCU detection using libjpeg for precise sizes
        return JPEGConstants.standardMCUSize
    }
    
    /// Snaps coordinates to the nearest MCU grid boundaries
    ///
    /// For lossless JPEG cropping, crop coordinates must align with MCU boundaries.
    /// This method adjusts the crop rectangle:
    /// - Origin is rounded **down** to the nearest MCU boundary
    /// - Size is rounded **up** to the nearest MCU boundary
    ///
    /// - Parameters:
    ///   - coordinates: Original crop rectangle
    ///   - mcuSize: MCU size (typically 8×8 or 16×16)
    ///
    /// - Returns: Adjusted crop rectangle aligned to MCU grid
    ///
    /// Example:
    /// ```swift
    /// let original = CGRect(x: 11, y: 13, width: 100, height: 100)
    /// let mcuSize = CGSize(width: 8, height: 8)
    /// let snapped = JPEGService.snapToMCUGrid(coordinates: original, mcuSize: mcuSize)
    /// // snapped = CGRect(x: 8, y: 8, width: 104, height: 104)
    /// ```
    static func snapToMCUGrid(coordinates: CGRect, mcuSize: CGSize) -> CGRect {
        let snappedX = floor(coordinates.origin.x / mcuSize.width) * mcuSize.width
        let snappedY = floor(coordinates.origin.y / mcuSize.height) * mcuSize.height
        let snappedWidth = ceil(coordinates.width / mcuSize.width) * mcuSize.width
        let snappedHeight = ceil(coordinates.height / mcuSize.height) * mcuSize.height
        
        return CGRect(
            x: snappedX,
            y: snappedY,
            width: snappedWidth,
            height: snappedHeight
        )
    }
    
    // MARK: - Lossless Cropping
    
    /// Performs lossless JPEG cropping using jpegtran
    ///
    /// This method uses the jpegtran tool from libjpeg-turbo to crop a JPEG image
    /// without recompression, preserving image quality and metadata.
    ///
    /// - Parameters:
    ///   - imageURL: URL of the source JPEG file
    ///   - cropRect: Crop rectangle in pixel coordinates (should be MCU-aligned)
    ///   - outputURL: URL where the cropped JPEG will be saved
    ///
    /// - Returns: Result indicating success or failure with detailed error
    ///
    /// ## Requirements
    /// - jpegtran must be installed (`brew install jpeg-turbo`)
    /// - Source file must be a valid JPEG
    /// - Crop coordinates should be aligned to MCU boundaries for true lossless operation
    ///
    /// ## jpegtran Command
    /// The method executes: `jpegtran -crop WxH+X+Y -copy all -outfile output input`
    ///
    /// Example:
    /// ```swift
    /// let result = JPEGService.cropLossless(
    ///     imageURL: sourceURL,
    ///     cropRect: CGRect(x: 16, y: 16, width: 800, height: 600),
    ///     outputURL: destURL
    /// )
    /// ```
    static func cropLossless(imageURL: URL, cropRect: CGRect, outputURL: URL) -> Result<Void, JPEGServiceError> {
        // Check if jpegtran is available
        guard let jpegtranPath = findJPEGTranPath() else {
            print("❌ jpegtran not found")
            return .failure(.jpegtranNotAvailable)
        }
        
        // Build crop arguments
        let cropArgument = buildCropArgument(from: cropRect)
        
        print("✂️ Lossless JPEG crop: \(cropArgument)")
        print("   Input:  \(imageURL.lastPathComponent)")
        print("   Output: \(outputURL.lastPathComponent)")
        
        // Execute crop command
        let executeResult = executeCropCommand(
            jpegtranPath: jpegtranPath,
            cropArgument: cropArgument,
            inputURL: imageURL,
            outputURL: outputURL
        )
        
        // Check execution result
        switch executeResult {
        case .success:
            // Validate output
            return validateCropOutput(at: outputURL)
        case .failure(let error):
            return .failure(.cropFailed(error.localizedDescription))
        }
    }
    
    // MARK: - Private Helpers
    
    /// Builds the crop argument string for jpegtran
    ///
    /// - Parameter cropRect: Crop rectangle in pixel coordinates
    /// - Returns: Crop argument in format "WxH+X+Y"
    private static func buildCropArgument(from cropRect: CGRect) -> String {
        let x = Int(cropRect.origin.x)
        let y = Int(cropRect.origin.y)
        let w = Int(cropRect.width)
        let h = Int(cropRect.height)
        
        return "\(w)x\(h)+\(x)+\(y)"
    }
    
    /// Executes the jpegtran crop command
    ///
    /// - Parameters:
    ///   - jpegtranPath: Full path to jpegtran executable
    ///   - cropArgument: Crop argument string (e.g., "800x600+16+16")
    ///   - inputURL: Source JPEG file URL
    ///   - outputURL: Destination JPEG file URL
    ///
    /// - Returns: Result indicating success or failure
    private static func executeCropCommand(
        jpegtranPath: String,
        cropArgument: String,
        inputURL: URL,
        outputURL: URL
    ) -> Result<Void, ProcessExecutorError> {
        
        // Build arguments for jpegtran
        // Syntax: jpegtran -crop WxH+X+Y -copy all -outfile output input
        let arguments = [
            "-crop",
            cropArgument,
            "-copy",
            "all",
            "-outfile",
            outputURL.path,
            inputURL.path  // Input file must be last argument
        ]
        
        // Set up environment with PATH
        let environment = [JPEGConstants.processPath]
        
        // Execute using ProcessExecutor
        return ProcessExecutor.executeAndVerify(
            command: jpegtranPath,
            arguments: arguments,
            environment: environment
        )
    }
    
    /// Validates that the crop output file was created successfully
    ///
    /// - Parameter outputURL: URL of the output file to validate
    /// - Returns: Result indicating success or failure
    private static func validateCropOutput(at outputURL: URL) -> Result<Void, JPEGServiceError> {
        // Check if output file exists
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            print("❌ Output file was not created")
            return .failure(.cropFailed("Output file was not created"))
        }
        
        // Check file size for verification
        if let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
           let fileSize = attributes[.size] as? Int64 {
            
            guard fileSize > 0 else {
                print("❌ Output file is empty")
                return .failure(.cropFailed("Output file is empty"))
            }
            
            print("✅ Cropped successfully (\(fileSize) bytes)")
        } else {
            print("✅ Cropped successfully")
        }
        
        return .success(())
    }
    
    // MARK: - Format Detection
    
    /// Checks if a file is a JPEG image
    ///
    /// - Parameter url: URL of the file to check
    /// - Returns: `true` if the file is a JPEG, `false` otherwise
    static func isJPEG(url: URL) -> Bool {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let uti = CGImageSourceGetType(imageSource) else {
            return false
        }
        return uti as String == "public.jpeg"
    }
}

// MARK: - JPEG Service Errors

/// Errors that can occur during JPEG service operations
enum JPEGServiceError: LocalizedError {
    /// jpegtran tool is not installed on the system
    case jpegtranNotAvailable
    
    /// Cropping operation failed with a specific reason
    case cropFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .jpegtranNotAvailable:
            return "jpegtran is not installed. Please install it with: brew install jpeg-turbo"
        case .cropFailed(let message):
            return "Cropping failed: \(message)"
        }
    }
}
