//
//  ExportView.swift
//  PhotoCropper
//
//  Export-Dialog mit Dateinamen-Generierung und Speicher-Optionen
//

import SwiftUI
import AppKit

struct ExportView: View {
    @Binding var isPresented: Bool
    var imageData: ImageData?
    var cropSettings: CropSettings?
    
    @State private var filename: String = ""
    @State private var suffix: String = ""
    @State private var outputDirectory: URL?
    @State private var overwriteOriginal: Bool = false
    @State private var createBackup: Bool = false
    @State private var isExporting: Bool = false
    @State private var exportResult: ExportResult?
    
    enum ExportResult {
        case success(URL, metadataSaved: Bool, cropData: String)
        case failure(String)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("SPEICHERN & EXPORT")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if imageData != nil {
                // Dateiname
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dateiname:")
                    TextField("Dateiname", text: $filename)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Suffix (optional):")
                    TextField("z.B. _16-9", text: $suffix)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Zielordner
                VStack(alignment: .leading, spacing: 8) {
                    Text("Zielordner:")
                    HStack {
                        Text(outputDirectory?.path ?? "Nicht ausgewählt")
                            .foregroundColor(.secondary)
                        Button("Auswählen...") {
                            selectOutputDirectory()
                        }
                    }
                }
                
                // Optionen
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Original überschreiben", isOn: $overwriteOriginal)
                        .foregroundColor(overwriteOriginal ? .red : .primary)
                    
                    Toggle("Backup des Originals erstellen", isOn: $createBackup)
                }
                
                // Ergebnis-Anzeige
                if let result = exportResult {
                    switch result {
                    case .success(let url, let metadataSaved, let cropData):
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Erfolgreich gespeichert")
                                    .foregroundColor(.green)
                                    .fontWeight(.bold)
                            }
                            
                            Text(url.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Divider()
                            
                            // EXIF-Metadaten Bestätigung
                            if metadataSaved {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                            .foregroundColor(.blue)
                                        Text("EXIF Crop-Metadaten gespeichert:")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    Text("• DefaultCropOrigin")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("• DefaultCropSize")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("• Custom XMP Tags")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Text(cropData)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .padding(4)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .padding(.vertical, 4)
                            } else {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Metadaten konnten nicht gespeichert werden")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        
                    case .failure(let error):
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Fehler: \(error)")
                                .foregroundColor(.red)
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                // Buttons
                HStack {
                    Button("Abbrechen") {
                        isPresented = false
                    }
                    
                    Spacer()
                    
                    Button("Speichern") {
                        exportImage()
                    }
                    .disabled(isExporting || filename.isEmpty)
                }
            }
        }
        .padding()
        .frame(width: 500, height: 400)
        .onAppear {
            setupDefaultFilename()
        }
    }
    
    private func setupDefaultFilename() {
        guard let imageData = imageData, let cropSettings = cropSettings else { return }
        
        let baseFilename = ExifDateParser.generateFilename(from: imageData)
        let ratioSuffix = ExifDateParser.suffixForRatio(cropSettings.targetRatio)
        
        let nameWithoutExtension = (baseFilename as NSString).deletingPathExtension
        let extensionString = imageData.url.pathExtension
        
        filename = "\(nameWithoutExtension)_\(ratioSuffix).\(extensionString)"
    }
    
    private func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            outputDirectory = panel.url
        }
    }
    
    private func exportImage() {
        guard let imageData = imageData, let cropSettings = cropSettings else { return }
        
        isExporting = true
        
        // Backup erstellen falls gewünscht
        if createBackup {
            createBackupFile(for: imageData.url)
        }
        
        // Ziel-URL bestimmen
        let outputURL: URL
        if overwriteOriginal {
            outputURL = imageData.url
        } else {
            let directory = outputDirectory ?? imageData.url.deletingLastPathComponent()
            let finalFilename = suffix.isEmpty ? filename : (filename as NSString).deletingPathExtension + "_\(suffix)." + imageData.url.pathExtension
            outputURL = directory.appendingPathComponent(finalFilename)
        }
        
        // Metadaten speichern
        let result = MetadataService.saveCropMetadata(
            imageURL: overwriteOriginal ? imageData.url : outputURL,
            cropBox: cropSettings.cropBox,
            imageSize: imageData.pixelSize,
            targetRatio: cropSettings.targetRatio,
            mode: cropSettings.mode,
            originalRatio: cropSettings.originalRatio
        )
        
        switch result {
        case .success:
            // Erstelle Crop-Data String für Anzeige
            let normalized = cropSettings.normalizedCoordinates(for: imageData.pixelSize)
            let cropDataString = String(format: 
                "Origin: (%.3f, %.3f)\nSize: (%.3f, %.3f)\nMode: %@\nRatio: %@",
                normalized.origin.x, normalized.origin.y,
                normalized.size.width, normalized.size.height,
                cropSettings.mode.rawValue,
                cropSettings.targetRatio.id
            )
            
            // Bei MCU-Modus: Verlustfreies Cropping durchführen
            if cropSettings.mode == .mcuSensitive && imageData.format == .jpeg {
                performLosslessCrop(sourceURL: imageData.url, outputURL: outputURL, cropBox: cropSettings.cropBox)
            } else {
                // Standard-Cropping: Bild kopieren (Metadaten bereits gespeichert)
                copyImage(from: imageData.url, to: outputURL)
            }
            
            exportResult = .success(outputURL, metadataSaved: true, cropData: cropDataString)
        case .failure(let error):
            exportResult = .failure(error.localizedDescription)
        }
        
        isExporting = false
    }
    
    private func performLosslessCrop(sourceURL: URL, outputURL: URL, cropBox: CGRect) {
        let result = JPEGService.cropLossless(imageURL: sourceURL, cropRect: cropBox, outputURL: outputURL)
        if case .failure(let error) = result {
            exportResult = .failure("MCU-Cropping fehlgeschlagen: \(error.localizedDescription)")
        }
    }
    
    private func copyImage(from sourceURL: URL, to destURL: URL) {
        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destURL)
        } catch {
            exportResult = .failure("Kopieren fehlgeschlagen: \(error.localizedDescription)")
        }
    }
    
    private func createBackupFile(for url: URL) {
        let backupURL = url.deletingPathExtension().appendingPathExtension("backup.\(url.pathExtension)")
        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            try fileManager.copyItem(at: url, to: backupURL)
        } catch {
            print("Backup-Erstellung fehlgeschlagen: \(error)")
        }
    }
}

