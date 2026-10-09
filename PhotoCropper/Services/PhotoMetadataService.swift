//
//  PhotoMetadataService.swift
//  PhotoCropper
//
//  Reads and writes descriptive metadata (date, location, description, GPS) via exiftool
//

import Foundation

/// Reads and writes the editable photo metadata and keeps duplicated fields identical.
///
/// ## Storage locations
/// | Field        | Written to                                            |
/// |--------------|-------------------------------------------------------|
/// | Capture date | EXIF DateTimeOriginal + TIFF DateTime (IFD0 ModifyDate) + XMP photoshop:DateCreated |
/// | City         | XMP photoshop:City + IPTC City                        |
/// | Region       | XMP photoshop:State + IPTC Province/State             |
/// | Description  | IPTC Caption/Abstract + EXIF ImageDescription; without IPTC also EXIF UserComment |
/// | Coordinates  | EXIF GPS latitude/longitude including Ref             |
///
/// IPTC-IIM is only written for formats that carry it (JPEG, TIFF). HEIC and PNG
/// get the XMP/EXIF locations only; there EXIF UserComment takes over the role of
/// IPTC Caption/Abstract as the description fallback for SMB sources in PhotoTV.
///
/// Every field is always written to **all** its locations in one exiftool call;
/// an empty value deletes the field in all locations. After writing, the file is
/// read back and the call fails if any location differs from the requested value.
enum PhotoMetadataService {

    /// Result of reading metadata from a file
    struct ReadResult {
        /// Effective values, taken from the highest-priority location
        let metadata: PhotoMetadata
        /// Fields whose locations currently hold different values
        let inconsistentFields: Set<MetadataField>
    }

    // MARK: - Tag Locations

    /// Which image formats a storage location is used for
    private enum Availability {
        case allFormats
        /// Only formats that carry IPTC-IIM
        case iptcFormatsOnly
        /// Only formats without IPTC-IIM (replacement location)
        case nonIPTCFormatsOnly
    }
    
    /// One physical storage location of a metadata field
    private struct TagLocation {
        /// Tag name used for writing, e.g. `XMP-photoshop:City`
        let writeTag: String
        /// Key in exiftool's `-j -G0` output, e.g. `XMP:City`
        let jsonKey: String
        var availability = Availability.allFormats
    }

    /// Text locations per field, in read priority order (first non-empty value wins)
    private static let textLocations: [MetadataField: [TagLocation]] = [
        .captureDate: [
            TagLocation(writeTag: "ExifIFD:DateTimeOriginal", jsonKey: "EXIF:DateTimeOriginal")
        ],
        .city: [
            TagLocation(writeTag: "XMP-photoshop:City", jsonKey: "XMP:City"),
            TagLocation(writeTag: "IPTC:City", jsonKey: "IPTC:City", availability: .iptcFormatsOnly)
        ],
        .region: [
            TagLocation(writeTag: "XMP-photoshop:State", jsonKey: "XMP:State"),
            TagLocation(writeTag: "IPTC:Province-State", jsonKey: "IPTC:Province-State", availability: .iptcFormatsOnly)
        ],
        .description: [
            TagLocation(writeTag: "IPTC:Caption-Abstract", jsonKey: "IPTC:Caption-Abstract", availability: .iptcFormatsOnly),
            TagLocation(writeTag: "IFD0:ImageDescription", jsonKey: "EXIF:ImageDescription"),
            TagLocation(writeTag: "ExifIFD:UserComment", jsonKey: "EXIF:UserComment", availability: .nonIPTCFormatsOnly)
        ]
    ]

    /// Tags that mirror the capture date on write: TIFF DateTime (SMB fallback) and
    /// XMP DateCreated (set by iPhone and Lightroom). They are not part of the consistency
    /// check, because editing software legitimately updates TIFF DateTime later.
    private static let captureDateMirrorTags = ["IFD0:ModifyDate", "XMP-photoshop:DateCreated"]

    private static let latitudeTag = "GPS:GPSLatitude"
    private static let latitudeRefTag = "GPS:GPSLatitudeRef"
    private static let longitudeTag = "GPS:GPSLongitude"
    private static let longitudeRefTag = "GPS:GPSLongitudeRef"
    /// Composite tags deliver signed decimal degrees (Ref already applied)
    private static let latitudeReadTag = "Composite:GPSLatitude"
    private static let longitudeReadTag = "Composite:GPSLongitude"

    private static let iptcFormats: Set<ImageFormat> = [.jpeg, .tiff]
    private static let exiftoolEnvironment = ["PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"]

    // MARK: - Public Interface

    /// Reads the editable metadata of an image
    static func read(imageURL: URL, format: ImageFormat) -> Result<ReadResult, PhotoMetadataError> {
        guard let exiftoolPath = ExiftoolPathResolver.findExiftoolPath() else {
            return .failure(.exiftoolNotFound)
        }

        let locationTags = textLocations.values.flatMap { $0 }.map { "-\($0.writeTag)" }
        let arguments = ["-j", "-n", "-G0"] + locationTags +
            ["-\(latitudeReadTag)", "-\(longitudeReadTag)", imageURL.path]

        return runForJSON(exiftoolPath: exiftoolPath, arguments: arguments).map { json in
            buildReadResult(from: json, format: format)
        }
    }

    /// Writes the metadata to all locations of every field and verifies the result.
    ///
    /// Empty values delete the field in all of its locations.
    static func write(_ metadata: PhotoMetadata, imageURL: URL, format: ImageFormat) -> Result<Void, PhotoMetadataError> {
        if let validationError = metadata.validationError {
            return .failure(.invalidInput(validationError))
        }
        guard let exiftoolPath = ExiftoolPathResolver.findExiftoolPath() else {
            return .failure(.exiftoolNotFound)
        }

        let expected = metadata.normalized()
        let arguments = buildWriteArguments(for: expected, imageURL: imageURL, format: format)

        let writeResult = ProcessExecutor.executeAndVerify(
            command: exiftoolPath,
            arguments: arguments,
            environment: exiftoolEnvironment
        )
        if case .failure(let error) = writeResult {
            return .failure(.writeFailed(error))
        }

        return verify(expected: expected, imageURL: imageURL, format: format)
    }

    // MARK: - Reading

    private static func buildReadResult(from json: [String: Any], format: ImageFormat) -> ReadResult {
        var effective: [MetadataField: String] = [:]
        var inconsistent = Set<MetadataField>()

        for (field, locations) in textLocations {
            let values = supportedLocations(locations, format: format).map { stringValue(json[$0.jsonKey]) }
            effective[field] = values.first { !$0.isEmpty } ?? ""
            if Set(values).count > 1 {
                inconsistent.insert(field)
            }
        }

        let metadata = PhotoMetadata(
            captureDate: PhotoMetadata.displayDate(fromExif: effective[.captureDate] ?? ""),
            city: effective[.city] ?? "",
            region: effective[.region] ?? "",
            description: effective[.description] ?? "",
            latitude: coordinateValue(json[latitudeReadTag]),
            longitude: coordinateValue(json[longitudeReadTag])
        )
        return ReadResult(metadata: metadata, inconsistentFields: inconsistent)
    }

    private static func stringValue(_ value: Any?) -> String {
        switch value {
        case let text as String:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case let number as NSNumber:
            return number.stringValue
        default:
            return ""
        }
    }

    private static func coordinateValue(_ value: Any?) -> String {
        guard let number = value as? NSNumber else { return "" }
        return PhotoMetadata.formatCoordinate(number.doubleValue)
    }

    private static func runForJSON(exiftoolPath: String, arguments: [String]) -> Result<[String: Any], PhotoMetadataError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: exiftoolPath)
        process.arguments = arguments
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return .failure(.readFailed(error.localizedDescription))
        }
        // Read before waiting, so a full pipe buffer cannot block exiftool
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = entries.first else {
            return .failure(.readFailed("exiftool exit code \(process.terminationStatus)"))
        }
        return .success(first)
    }

    // MARK: - Writing

    private static func buildWriteArguments(for metadata: PhotoMetadata, imageURL: URL, format: ImageFormat) -> [String] {
        let writesIPTC = iptcFormats.contains(format)
        var args = ["-overwrite_original", "-n"]
        if writesIPTC {
            args.append("-IPTC:CodedCharacterSet=UTF8")
        }

        let exifDate = PhotoMetadata.exifDate(fromDisplay: metadata.captureDate)
        let values: [MetadataField: String] = [
            .captureDate: exifDate,
            .city: metadata.city,
            .region: metadata.region,
            .description: metadata.description
        ]
        for (field, locations) in textLocations {
            for location in supportedLocations(locations, format: format) {
                args.append("-\(location.writeTag)=\(values[field] ?? "")")
            }
        }
        args += captureDateMirrorTags.map { "-\($0)=\(exifDate)" }
        args += coordinateArguments(for: metadata)

        if writesIPTC {
            args.append("-IPTCDigest=new")
        }
        args.append(imageURL.path)
        return args
    }

    /// Latitude and longitude are always written or deleted together with their Ref tags
    private static func coordinateArguments(for metadata: PhotoMetadata) -> [String] {
        guard let latitude = metadata.latitudeValue, let longitude = metadata.longitudeValue else {
            return [latitudeTag, latitudeRefTag, longitudeTag, longitudeRefTag].map { "-\($0)=" }
        }
        return [
            "-\(latitudeTag)=\(PhotoMetadata.formatCoordinate(abs(latitude)))",
            "-\(latitudeRefTag)=\(latitude < 0 ? "S" : "N")",
            "-\(longitudeTag)=\(PhotoMetadata.formatCoordinate(abs(longitude)))",
            "-\(longitudeRefTag)=\(longitude < 0 ? "W" : "E")"
        ]
    }

    private static func supportedLocations(_ locations: [TagLocation], format: ImageFormat) -> [TagLocation] {
        let hasIPTC = iptcFormats.contains(format)
        return locations.filter { location in
            switch location.availability {
            case .allFormats: return true
            case .iptcFormatsOnly: return hasIPTC
            case .nonIPTCFormatsOnly: return !hasIPTC
            }
        }
    }

    // MARK: - Verification

    /// Reads the file back and fails if any field or location deviates from the expected values
    private static func verify(expected: PhotoMetadata, imageURL: URL, format: ImageFormat) -> Result<Void, PhotoMetadataError> {
        read(imageURL: imageURL, format: format).flatMap { readBack in
            var deviating = readBack.inconsistentFields
            deviating.formUnion(differingFields(readBack.metadata, expected))
            return deviating.isEmpty ? .success(()) : .failure(.verificationFailed(deviating))
        }
    }

    private static func differingFields(_ lhs: PhotoMetadata, _ rhs: PhotoMetadata) -> Set<MetadataField> {
        var fields = Set<MetadataField>()
        if lhs.captureDate != rhs.captureDate { fields.insert(.captureDate) }
        if lhs.city != rhs.city { fields.insert(.city) }
        if lhs.region != rhs.region { fields.insert(.region) }
        if lhs.description != rhs.description { fields.insert(.description) }
        if lhs.latitude != rhs.latitude || lhs.longitude != rhs.longitude { fields.insert(.coordinates) }
        return fields
    }
}

// MARK: - Errors

enum PhotoMetadataError: LocalizedError {
    case exiftoolNotFound
    case invalidInput(String)
    case readFailed(String)
    case writeFailed(ProcessExecutorError)
    case verificationFailed(Set<MetadataField>)

    var errorDescription: String? {
        switch self {
        case .exiftoolNotFound:
            return "exiftool not found (install with: brew install exiftool)"
        case .invalidInput(let message):
            return message
        case .readFailed(let message):
            return "Reading metadata failed: \(message)"
        case .writeFailed(let error):
            return "Writing metadata failed: \(error.localizedDescription)"
        case .verificationFailed(let fields):
            let names = fields.map(\.rawValue).sorted().joined(separator: ", ")
            return "Metadata written, but read-back differs for: \(names)"
        }
    }
}
