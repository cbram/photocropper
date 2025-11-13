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
    @State private var saveCropMetadata: Bool = true  // Neue Option für EXIF-Speicherung
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
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Crop-Daten in EXIF speichern", isOn: $saveCropMetadata)
                            .fontWeight(saveCropMetadata ? .semibold : .regular)
                        
                        if saveCropMetadata {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("DefaultCropOrigin, DefaultCropSize & XMP Tags werden gespeichert")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 20)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Nur Datei wird gespeichert, keine EXIF Crop-Metadaten")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                            .padding(.leading, 20)
                        }
                    }
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
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundColor(.gray)
                                        Text("EXIF Crop-Metadaten:")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Text("Nicht gespeichert (Checkbox war deaktiviert)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                                .padding(.vertical, 4)
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
            setupDefaultOutputDirectory()
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
    
    private func setupDefaultOutputDirectory() {
        guard let imageData = imageData else { return }
        
        // Standard-Zielordner ist der Ordner des Original-Fotos
        outputDirectory = imageData.url.deletingLastPathComponent()
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
        
        // Security-Scoped Resource Access starten
        let sourceAccess = imageData.url.startAccessingSecurityScopedResource()
        defer {
            if sourceAccess {
                imageData.url.stopAccessingSecurityScopedResource()
            }
        }
        
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
        
        // Security-Scoped Access für Output-Verzeichnis
        let outputAccess = outputURL.startAccessingSecurityScopedResource()
        defer {
            if outputAccess {
                outputURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // SCHRITT 1: Datei erst kopieren/croppen (damit sie am Zielort existiert)
        if cropSettings.mode == .mcuSensitive && imageData.format == .jpeg {
            // Bei MCU-Modus: Verlustfreies Cropping durchführen
            performLosslessCrop(sourceURL: imageData.url, outputURL: outputURL, cropBox: cropSettings.cropBox)
        } else {
            // Standard-Cropping: Bild kopieren
            copyImage(from: imageData.url, to: outputURL)
        }
        
        // Falls copyImage oder performLosslessCrop fehlgeschlagen ist, abbrechen
        if exportResult != nil {
            isExporting = false
            return
        }
        
        // SCHRITT 2: Metadaten speichern (nur wenn Checkbox aktiviert)
        // Wichtig: Jetzt in die bereits existierende Ziel-Datei schreiben!
        var metadataSaved = false
        var cropDataString = "Metadaten nicht gespeichert"
        
        if saveCropMetadata {
            let result = MetadataService.saveCropMetadata(
                imageURL: outputURL,  // Immer in die Ziel-Datei schreiben (die jetzt existiert!)
                cropBox: cropSettings.cropBox,
                imageSize: imageData.pixelSize,
                targetRatio: cropSettings.targetRatio,
                mode: cropSettings.mode,
                originalRatio: cropSettings.originalRatio
            )
            
            switch result {
            case .success:
                metadataSaved = true
                // Erstelle Crop-Data String für Anzeige
                let normalized = cropSettings.normalizedCoordinates(for: imageData.pixelSize)
                cropDataString = String(format: 
                    "Origin: (%.3f, %.3f)\nSize: (%.3f, %.3f)\nMode: %@\nRatio: %@",
                    normalized.origin.x, normalized.origin.y,
                    normalized.size.width, normalized.size.height,
                    cropSettings.mode.rawValue,
                    cropSettings.targetRatio.id
                )
            case .failure(let error):
                // Warnung bei Metadaten-Fehler, aber Datei ist bereits gespeichert
                print("⚠️ Metadaten konnten nicht gespeichert werden: \(error)")
                metadataSaved = false
                cropDataString = "Fehler beim Speichern: \(error.localizedDescription)"
            }
        }
        
        exportResult = .success(outputURL, metadataSaved: metadataSaved, cropData: cropDataString)
        
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

