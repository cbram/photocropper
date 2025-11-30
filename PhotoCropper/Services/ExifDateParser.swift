//
//  ExifDateParser.swift
//  PhotoCropper
//
//  Extracts creation date from EXIF for filename generation
//

import Foundation

/// Service for parsing EXIF dates and generating filenames
///
/// This service provides utilities for:
/// - Generating filenames based on image creation dates
/// - Parsing EXIF date formats
/// - Creating filesystem-safe filename suffixes
///
/// ## Date Fallback Strategy
/// When generating filenames, the service uses this fallback order:
/// 1. **EXIF creation date** (preferred)
/// 2. **File modification date** (fallback)
/// 3. **Current date** (last resort)
///
/// ## Filename Format
/// Generated filenames follow this pattern:
/// - Basic: `YYYY-MM-DD_HH-MM-SS.ext`
/// - With suffix: `YYYY-MM-DD_HH-MM-SS_suffix.ext`
///
/// ## Usage Example
/// ```swift
/// let filename = ExifDateParser.generateFilename(
///     from: imageData,
///     suffix: "16-9"
/// )
/// // Result: "2025-08-13_10-04-10_16-9.jpg"
/// ```
class ExifDateParser {
    
    // MARK: - Constants
    
    /// Standard date format for filenames (filesystem-safe)
    private static let filenameDateFormat = "yyyy-MM-dd_HH-mm-ss"
    
    /// Alternative EXIF date formats to try when parsing
    private static let exifDateFormats = [
        "yyyy:MM:dd HH:mm:ss",      // Standard EXIF format
        "yyyy-MM-dd HH:mm:ss",      // Alternative format
        "yyyy:MM:dd HH:mm:ss.SSS",  // With milliseconds
        "yyyy-MM-dd'T'HH:mm:ss",    // ISO-like format
    ]
    
    /// Maximum length for suffix in filename
    private static let maxSuffixLength = 50
    
    /// Characters that are not allowed in filenames
    private static let invalidFilenameCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
    
    // MARK: - Public Interface
    
    /// Generates a filename from image data and optional suffix
    ///
    /// The filename is generated using the image's creation date or fallback dates.
    /// The suffix is sanitized to be filesystem-safe.
    ///
    /// - Parameters:
    ///   - imageData: Image data containing URL and creation date
    ///   - suffix: Optional suffix to append before file extension (e.g., "16-9")
    /// - Returns: Generated filename in format `YYYY-MM-DD_HH-MM-SS[_suffix].ext`
    ///
    /// ## Date Selection Priority
    /// 1. `imageData.creationDate` (from EXIF)
    /// 2. File modification date
    /// 3. Current date and time
    static func generateFilename(
        from imageData: ImageData,
        suffix: String = ""
    ) -> String {
        let date = selectDate(from: imageData)
        let dateString = formatDateForFilename(date)
        let sanitizedSuffix = sanitizeSuffix(suffix)
        let extensionString = imageData.url.pathExtension.lowercased()
        
        if sanitizedSuffix.isEmpty {
            return "\(dateString).\(extensionString)"
        } else {
            return "\(dateString)_\(sanitizedSuffix).\(extensionString)"
        }
    }
    
    /// Generates a filesystem-safe suffix based on aspect ratio
    ///
    /// - Parameter ratio: Aspect ratio to convert to suffix
    /// - Returns: Filesystem-safe suffix string (e.g., "16-9", "1-1", "4-3")
    static func suffixForRatio(_ ratio: AspectRatio) -> String {
        switch ratio {
        case .ratio16_9:
            return "16-9"
        case .ratio1_1:
            return "1-1"
        case .custom(let w, let h):
            return "\(w)-\(h)"
        }
    }
    
    /// Parses EXIF date string to Date object
    ///
    /// Tries multiple date formats to handle different EXIF date encodings.
    ///
    /// - Parameter dateString: EXIF date string to parse
    /// - Returns: Parsed Date, or `nil` if parsing failed
    static func parseDate(from dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        
        // Try all known EXIF date formats
        for format in exifDateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    
    /// Selects the best available date from image data
    ///
    /// - Parameter imageData: Image data to extract date from
    /// - Returns: Best available date (creation, modification, or current)
    private static func selectDate(from imageData: ImageData) -> Date {
        // Priority 1: EXIF creation date
        if let creationDate = imageData.creationDate {
            return creationDate
        }
        
        // Priority 2: File modification date
        if let attributes = try? FileManager.default.attributesOfItem(atPath: imageData.url.path),
           let modificationDate = attributes[.modificationDate] as? Date {
            return modificationDate
        }
        
        // Priority 3: Current date (last resort)
        return Date()
    }
    
    /// Formats a date for use in filenames
    ///
    /// - Parameter date: Date to format
    /// - Returns: Formatted date string (YYYY-MM-DD_HH-MM-SS)
    private static func formatDateForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = filenameDateFormat
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
    
    /// Sanitizes a suffix to be filesystem-safe
    ///
    /// Removes invalid characters and truncates to maximum length.
    ///
    /// - Parameter suffix: Raw suffix string
    /// - Returns: Sanitized suffix safe for use in filenames
    private static func sanitizeSuffix(_ suffix: String) -> String {
        guard !suffix.isEmpty else { return "" }
        
        // Remove invalid characters
        let components = suffix.components(separatedBy: invalidFilenameCharacters)
        var sanitized = components.joined(separator: "-")
        
        // Trim whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Truncate if too long
        if sanitized.count > maxSuffixLength {
            sanitized = String(sanitized.prefix(maxSuffixLength))
        }
        
        return sanitized
    }
}
