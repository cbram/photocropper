//
//  MetadataEditorView.swift
//  PhotoCropper
//
//  Edits date, location, description and GPS metadata of the current image
//

import SwiftUI

struct MetadataEditorView: View {
    var imageData: ImageData?

    @State private var fields = PhotoMetadata()
    @State private var loadedFields = PhotoMetadata()
    @State private var inconsistentFields = Set<MetadataField>()
    @State private var statusMessage: StatusMessage?

    private enum StatusMessage {
        case success(String)
        case failure(String)
    }

    private var hasChanges: Bool { fields.normalized() != loadedFields.normalized() }
    private var canSave: Bool { hasChanges && fields.validationError == nil }

    var body: some View {
        CollapsibleSection(title: "METADATA") {
            if let imageData = imageData {
                editor(for: imageData)
            } else {
                Text("No image loaded")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: imageData?.url) {
            loadMetadata()
        }
    }

    // MARK: - Editor

    @ViewBuilder
    private func editor(for imageData: ImageData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledField("Date taken", field: .captureDate) {
                TextField(PhotoMetadata.displayDateFormat, text: $fields.captureDate)
            }
            labeledField("City / District", field: .city) {
                TextField("", text: $fields.city)
            }
            labeledField("Region (e.g. Lofoten)", field: .region) {
                TextField("", text: $fields.region)
            }
            labeledField("Description", field: .description) {
                TextField("", text: $fields.description, axis: .vertical)
                    .lineLimit(2...4)
            }
            labeledField("GPS (decimal degrees)", field: .coordinates) {
                HStack {
                    TextField("Latitude", text: $fields.latitude)
                    TextField("Longitude", text: $fields.longitude)
                }
            }

            hints(for: imageData)
            actionButtons(for: imageData)
            statusView
        }
        .textFieldStyle(.roundedBorder)
    }

    private func labeledField<Field: View>(_ label: String, field: MetadataField, @ViewBuilder content: () -> Field) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            content()
            if inconsistentFields.contains(field) {
                Label("Values differ between metadata locations — saving aligns them", systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }

    @ViewBuilder
    private func hints(for imageData: ImageData) -> some View {
        if let validationError = fields.validationError {
            Label(validationError, systemImage: "xmark.octagon")
                .font(.caption)
                .foregroundColor(.red)
        }
        if imageData.format != .jpeg && imageData.format != .tiff {
            Text("This format carries no IPTC — only XMP and EXIF are written; the description also goes to EXIF UserComment.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        Text("An empty field is removed from all metadata locations on save.")
            .font(.caption2)
            .foregroundColor(.secondary)
    }

    private func actionButtons(for imageData: ImageData) -> some View {
        HStack(spacing: 8) {
            Button("Save") { saveMetadata(for: imageData) }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            Button("Revert") {
                fields = loadedFields
                statusMessage = nil
            }
            .buttonStyle(.bordered)
            .disabled(!hasChanges)
            Button("Clear location") { clearLocation() }
                .buttonStyle(.bordered)
                .help("Clears city, region and GPS coordinates (written on Save)")
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch statusMessage {
        case .success(let message):
            Label(message, systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundColor(.secondary)
        case .failure(let message):
            Label(message, systemImage: "xmark.octagon")
                .font(.caption)
                .foregroundColor(.red)
        case nil:
            EmptyView()
        }
    }

    // MARK: - Actions

    private func loadMetadata() {
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

    private func saveMetadata(for imageData: ImageData) {
        let access = imageData.url.startAccessingSecurityScopedResource()
        let result = PhotoMetadataService.write(fields, imageURL: imageData.url, format: imageData.format)
        if access { imageData.url.stopAccessingSecurityScopedResource() }

        switch result {
        case .success:
            loadMetadata()
            imageData.creationDate = ExifDateParser.parseDate(from: PhotoMetadata.exifDate(fromDisplay: loadedFields.captureDate))
            statusMessage = .success("Metadata saved")
        case .failure(let error):
            statusMessage = .failure(error.localizedDescription)
        }
    }

    private func clearLocation() {
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
