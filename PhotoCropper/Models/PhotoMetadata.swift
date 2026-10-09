//
//  PhotoMetadata.swift
//  PhotoCropper
//
//  Editable descriptive metadata (date, location, description, GPS)
//

import Foundation

/// Logical metadata fields that can be edited in the UI.
///
/// Each field may be stored in several physical locations (EXIF, XMP, IPTC);
/// `PhotoMetadataService` keeps those locations identical.
enum MetadataField: String, CaseIterable {
    case captureDate
    case city
    case region
    case description
    case coordinates
}

/// Editable metadata values as entered in the UI.
///
/// All values are kept as strings so that empty input can express "delete this field".
/// - `captureDate` uses the display format `yyyy-MM-dd HH:mm:ss`
/// - `latitude` / `longitude` are signed decimal degrees (comma or dot as separator)
struct PhotoMetadata: Equatable {
    var captureDate = ""
    var city = ""
    var region = ""
    var description = ""
    var latitude = ""
    var longitude = ""

    /// Display format of the capture date in the editor
    static let displayDateFormat = "yyyy-MM-dd HH:mm:ss"

    private static let latitudeRange = -90.0...90.0
    private static let longitudeRange = -180.0...180.0
    private static let coordinateDecimalPlaces = 6

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = displayDateFormat
        formatter.isLenient = false
        return formatter
    }()

    // MARK: - Validation

    /// Human-readable validation error, or `nil` if all values can be written
    var validationError: String? {
        let date = captureDate.trimmed
        if !date.isEmpty && Self.displayDateFormatter.date(from: date) == nil {
            return "Date must have the format \(Self.displayDateFormat)"
        }

        let lat = latitude.trimmed
        let lon = longitude.trimmed
        if lat.isEmpty != lon.isEmpty {
            return "Enter both latitude and longitude, or clear both"
        }
        if !lat.isEmpty {
            guard let latValue = Self.parseCoordinate(lat), Self.latitudeRange.contains(latValue) else {
                return "Latitude must be a number between -90 and 90"
            }
            guard let lonValue = Self.parseCoordinate(lon), Self.longitudeRange.contains(lonValue) else {
                return "Longitude must be a number between -180 and 180"
            }
        }
        return nil
    }

    /// Returns a copy with trimmed text and coordinates in canonical form,
    /// so that UI input and values read back from the file compare equal.
    func normalized() -> PhotoMetadata {
        PhotoMetadata(
            captureDate: captureDate.trimmed,
            city: city.trimmed,
            region: region.trimmed,
            description: description.trimmed,
            latitude: Self.canonicalCoordinate(latitude),
            longitude: Self.canonicalCoordinate(longitude)
        )
    }

    /// Signed latitude in decimal degrees, `nil` if empty or invalid
    var latitudeValue: Double? { Self.parseCoordinate(latitude.trimmed) }

    /// Signed longitude in decimal degrees, `nil` if empty or invalid
    var longitudeValue: Double? { Self.parseCoordinate(longitude.trimmed) }

    // MARK: - Conversions

    /// Formats a coordinate with at most six decimals and without trailing zeros
    static func formatCoordinate(_ value: Double) -> String {
        var text = String(format: "%.\(coordinateDecimalPlaces)f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    /// Converts an EXIF date (`yyyy:MM:dd HH:mm:ss[...]`) to the display format.
    /// Subseconds and time zone suffixes are dropped; they live in separate EXIF tags.
    static func displayDate(fromExif exifDate: String) -> String {
        let core = String(exifDate.prefix(19))
        guard core.count == 19 else { return exifDate }
        return core.replacingOccurrences(of: ":", with: "-", options: [], range: core.startIndex..<core.index(core.startIndex, offsetBy: 10))
    }

    /// Converts a display date (`yyyy-MM-dd HH:mm:ss`) to the EXIF format
    static func exifDate(fromDisplay displayDate: String) -> String {
        let core = displayDate.trimmed
        guard core.count == 19 else { return core }
        return core.replacingOccurrences(of: "-", with: ":", options: [], range: core.startIndex..<core.index(core.startIndex, offsetBy: 10))
    }

    private static func parseCoordinate(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private static func canonicalCoordinate(_ text: String) -> String {
        guard let value = parseCoordinate(text.trimmed) else { return text.trimmed }
        return formatCoordinate(value)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
