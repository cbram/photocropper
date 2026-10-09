//
//  MetadataEditorView.swift
//  PhotoCropper
//
//  Edits date, location, description and GPS metadata of the current image
//

import SwiftUI

struct MetadataEditorView: View {
    var imageData: ImageData?
    @ObservedObject var model: MetadataEditorModel

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
            model.load(imageData)
        }
    }

    // MARK: - Editor

    @ViewBuilder
    private func editor(for imageData: ImageData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledField("Date taken", field: .captureDate) {
                TextField(PhotoMetadata.displayDateFormat, text: $model.fields.captureDate)
            }
            labeledField("City / District", field: .city) {
                TextField("", text: $model.fields.city)
            }
            labeledField("Region (e.g. Lofoten)", field: .region) {
                TextField("", text: $model.fields.region)
            }
            labeledField("Description", field: .description) {
                TextField("", text: $model.fields.description, axis: .vertical)
                    .lineLimit(2...4)
            }
            labeledField("GPS (decimal degrees)", field: .coordinates) {
                HStack {
                    TextField("Latitude", text: $model.fields.latitude)
                    TextField("Longitude", text: $model.fields.longitude)
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
            if model.inconsistentFields.contains(field) {
                Label("Values differ between metadata locations — saving aligns them", systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }

    @ViewBuilder
    private func hints(for imageData: ImageData) -> some View {
        if let validationError = model.fields.validationError {
            Label(validationError, systemImage: "xmark.octagon")
                .font(.caption)
                .foregroundColor(.red)
        }
        if let mismatchWarning = imageData.format.extensionMismatchWarning(for: imageData.url) {
            Label(mismatchWarning, systemImage: "exclamationmark.triangle")
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
            Button("Save") { model.save(for: imageData) }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canSave)
            Button("Revert") { model.revert() }
                .buttonStyle(.bordered)
                .disabled(!model.hasChanges)
            Button("Clear location") { model.clearLocation() }
                .buttonStyle(.bordered)
                .help("Clears city, region and GPS coordinates (written on Save)")
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch model.statusMessage {
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
}
