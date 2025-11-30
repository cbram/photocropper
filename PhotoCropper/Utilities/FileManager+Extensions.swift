//
//  FileManager+Extensions.swift
//  PhotoCropper
//
//  FileManager helper functions for common file operations
//

import Foundation
import UniformTypeIdentifiers

/// Extensions to FileManager for image file operations
extension FileManager {
    
    // MARK: - Image File Detection
    
    /// Supported image file extensions
    private static let imageExtensions = ["jpg", "jpeg", "heic", "heif", "png", "tiff", "tif"]
    
    /// Checks if a file is a supported image file
    ///
    /// Supports common image formats:
    /// - JPEG (.jpg, .jpeg)
    /// - HEIC/HEIF (.heic, .heif)
    /// - PNG (.png)
    /// - TIFF (.tiff, .tif)
    ///
    /// - Parameter url: URL of the file to check
    /// - Returns: `true` if file is a supported image format, otherwise `false`
    ///
    /// ## Usage Example
    /// ```swift
    /// if FileManager.default.isImageFile(at: fileURL) {
    ///     // Process image file
    /// }
    /// ```
    func isImageFile(at url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return Self.imageExtensions.contains(ext)
    }
    
    /// Filters image files from a list of URLs
    ///
    /// - Parameter urls: Array of file URLs to filter
    /// - Returns: Array containing only supported image file URLs
    func filterImageFiles(from urls: [URL]) -> [URL] {
        return urls.filter { isImageFile(at: $0) }
    }
    
    // MARK: - File Size
    
    /// Gets the size of a file in bytes
    ///
    /// - Parameter url: URL of the file
    /// - Returns: File size in bytes, or `nil` if file doesn't exist or size couldn't be determined
    func fileSize(at url: URL) -> Int64? {
        guard let attributes = try? attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return nil
        }
        return size.int64Value
    }
    
    /// Formats file size as human-readable string
    ///
    /// - Parameter bytes: File size in bytes
    /// - Returns: Formatted string (e.g., "1.5 MB", "234 KB")
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Safe File Operations
    
    /// Safely creates a directory if it doesn't exist
    ///
    /// - Parameter url: URL of the directory to create
    /// - Returns: `true` if directory exists or was created successfully, otherwise `false`
    @discardableResult
    func createDirectoryIfNeeded(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        
        // Check if already exists
        if fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }
        
        // Create directory
        do {
            try createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            return true
        } catch {
            print("❌ Failed to create directory at \(url.path): \(error)")
            return false
        }
    }
    
    /// Safely moves a file with automatic conflict resolution
    ///
    /// If the destination already exists, adds a number suffix (e.g., "file (2).jpg")
    ///
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - destinationURL: Destination file URL
    /// - Returns: Final destination URL if successful, otherwise `nil`
    @discardableResult
    func moveItemSafely(from sourceURL: URL, to destinationURL: URL) -> URL? {
        var finalDestination = destinationURL
        var counter = 1
        
        // Find available filename if destination exists
        while fileExists(atPath: finalDestination.path) {
            let filename = destinationURL.deletingPathExtension().lastPathComponent
            let ext = destinationURL.pathExtension
            let directory = destinationURL.deletingLastPathComponent()
            
            finalDestination = directory.appendingPathComponent("\(filename) (\(counter)).\(ext)")
            counter += 1
            
            // Safety limit
            if counter > 1000 {
                print("❌ Too many conflicting filenames for \(destinationURL.lastPathComponent)")
                return nil
            }
        }
        
        do {
            try moveItem(at: sourceURL, to: finalDestination)
            return finalDestination
        } catch {
            print("❌ Failed to move file: \(error)")
            return nil
        }
    }
    
    /// Safely copies a file with automatic conflict resolution
    ///
    /// If the destination already exists, adds a number suffix (e.g., "file (2).jpg")
    ///
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - destinationURL: Destination file URL
    /// - Returns: Final destination URL if successful, otherwise `nil`
    @discardableResult
    func copyItemSafely(from sourceURL: URL, to destinationURL: URL) -> URL? {
        var finalDestination = destinationURL
        var counter = 1
        
        // Find available filename if destination exists
        while fileExists(atPath: finalDestination.path) {
            let filename = destinationURL.deletingPathExtension().lastPathComponent
            let ext = destinationURL.pathExtension
            let directory = destinationURL.deletingLastPathComponent()
            
            finalDestination = directory.appendingPathComponent("\(filename) (\(counter)).\(ext)")
            counter += 1
            
            // Safety limit
            if counter > 1000 {
                print("❌ Too many conflicting filenames for \(destinationURL.lastPathComponent)")
                return nil
            }
        }
        
        do {
            try copyItem(at: sourceURL, to: finalDestination)
            return finalDestination
        } catch {
            print("❌ Failed to copy file: \(error)")
            return nil
        }
    }
}
