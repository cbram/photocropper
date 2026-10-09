//
//  MetadataEditorModel.swift
//  PhotoCropper
//
//  Editing state of the metadata editor, shared with ContentView for save-on-Enter
//

import Foundation
import Combine

/// Holds the edited and the loaded metadata of the current image and saves it via exiftool.
///
/// Lives in `ContentView`, so that pressing Enter can save pending changes before
/// moving on to the next image.
final class MetadataEditorModel: ObservableObject {

    enum StatusMessage {
        case success(String)
        case failure(String)
    }

    @Published var fields = PhotoMetadata()
    @Published private(set) var loadedFields = PhotoMetadata()
    @Published private(set) var inconsistentFields = Set<MetadataField>()
    @Published var statusMessage: StatusMessage?

    var hasChanges: Bool { fields.normalized() != loadedFields.normalized() }
    var canSave: Bool { hasChanges && fields.validationError == nil }

    // MARK: - Loading

    func load(_ imageData: ImageData?) {
        statusMessage = nil
        guard let imageData = imageData else {
            applyReadResult(PhotoMetadata(), inconsistent: [])
            return
        }

        let access = imageData.url.startAccessingSecurityScopedResource()
        defer { if access { imageData.url.stopAccessingSecurityScopedResource() } }

        switch PhotoMetadataService.read(imageURL: imageData.url, format: imageData.format) {
        case .success(let result):
            applyReadResult(result.metadata, inconsistent: result.inconsistentFields)
        case .failure(let error):
            applyReadResult(PhotoMetadata(), inconsistent: [])
            statusMessage = .failure(error.localizedDescription)
        }
    }

    // MARK: - Saving

    /// Writes the edited fields to the image file.
    /// - Returns: `true` if the metadata was written and verified
    @discardableResult
    func save(for imageData: ImageData) -> Bool {
        let access = imageData.url.startAccessingSecurityScopedResource()
        let result = PhotoMetadataService.write(fields, imageURL: imageData.url, format: imageData.format)
        if access { imageData.url.stopAccessingSecurityScopedResource() }

        switch result {
        case .success:
            load(imageData)
            imageData.creationDate = ExifDateParser.parseDate(from: PhotoMetadata.exifDate(fromDisplay: loadedFields.captureDate))
            statusMessage = .success("Metadata saved")
            return true
        case .failure(let error):
            statusMessage = .failure(error.localizedDescription)
            return false
        }
    }

    /// Saves only if there are unsaved changes (used before moving to the next image).
    /// - Returns: `true` if there was nothing to save or saving succeeded
    func saveIfChanged(for imageData: ImageData) -> Bool {
        guard hasChanges else { return true }
        if let validationError = fields.validationError {
            statusMessage = .failure(validationError)
            return false
        }
        return save(for: imageData)
    }

    // MARK: - Editing

    func revert() {
        fields = loadedFields
        statusMessage = nil
    }

    func clearLocation() {
        fields.city = ""
        fields.region = ""
        fields.latitude = ""
        fields.longitude = ""
    }

    private func applyReadResult(_ metadata: PhotoMetadata, inconsistent: Set<MetadataField>) {
        fields = metadata
        loadedFields = metadata
        inconsistentFields = inconsistent
    }
}
