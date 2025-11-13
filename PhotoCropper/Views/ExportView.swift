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
    @State private var onlyMetadata: Bool = false  // NUR Metadaten speichern, nicht croppen
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
                    
    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Crop-Daten in EXIF speichern", isOn: $saveCropMetadata)
                            .fontWeight(saveCropMetadata ? .semibold : .regular)
                        
                        if saveCropMetadata {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("DefaultCropOrigin, DefaultCropSize & XMP Tags werden gespeichert")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 20)
                                
                                // Zusätzliche Option: Nur Metadaten
                                Toggle("Nur Metadaten (Bild nicht physisch croppen)", isOn: $onlyMetadata)
                                    .font(.callout)
                                    .padding(.leading, 20)
                                
                                if onlyMetadata {
                                    HStack(spacing: 4) {
                                        Image(systemName: "tag.fill")
                                            .foregroundColor(.purple)
                                            .font(.caption)
                                        Text("Bild bleibt unverändert, nur EXIF-Tags werden geschrieben")
                                            .font(.caption2)
                                            .foregroundColor(.purple)
                                    }
                                    .padding(.leading, 40)
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "crop")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text("Bild wird gecroppt UND EXIF-Tags werden geschrieben")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                    .padding(.leading, 40)
                                }
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Bild wird gecroppt, aber keine EXIF Crop-Metadaten")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                            .padding(.leading, 20)
                        }
                    }
                }
                
                // Ergebnis-Anzeige (kompakt)
                if let result = exportResult {
                    switch result {
                    case .success(let url, let metadataSaved, let cropData):
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                Text("Erfolgreich gespeichert!")
                                    .foregroundColor(.green)
                                    .fontWeight(.semibold)
                            }
                            
                            Text(url.lastPathComponent)
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            Text(url.deletingLastPathComponent().path)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            // EXIF-Metadaten Bestätigung (kompakt)
                            if metadataSaved {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption2)
                                    Text("EXIF Crop-Metadaten gespeichert:")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    
                                    // Zeige ob nur Metadaten oder auch gecroppt
                                    if cropData.contains("NUR METADATEN") {
                                        Image(systemName: "tag.fill")
                                            .foregroundColor(.purple)
                                            .font(.caption2)
                                    } else {
                                        Image(systemName: "crop")
                                            .foregroundColor(.green)
                                            .font(.caption2)
                                    }
                                }
                                
                                Text(cropData)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(10)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        
                    case .failure(let error):
                        VStack(spacing: 6) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.title3)
                                Text("Fehler beim Speichern")
                                    .foregroundColor(.red)
                                    .fontWeight(.semibold)
                            }
                            
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                // Buttons - Variieren je nach Status
                HStack(spacing: 12) {
                    if exportResult != nil {
                        // Nach Export: Nur OK Button zum Schließen
                        Button(action: {
                            exportResult = nil
                            isPresented = false
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("OK")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Vor Export: Abbrechen + Speichern
                        Button(action: {
                            isPresented = false
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Abbrechen")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            exportImage()
                        }) {
                            HStack {
                                if isExporting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "square.and.arrow.down.fill")
                                }
                                Text(isExporting ? "Speichere..." : "Speichern")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(filename.isEmpty || isExporting ? Color.blue.opacity(0.5) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isExporting || filename.isEmpty)
                    }
                }
            }
        }
        .padding()
        .frame(width: 550, height: 500)
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
        
        print("\n" + String(repeating: "=", count: 80))
        print("🎬 EXPORT GESTARTET")
        print(String(repeating: "=", count: 80))
        
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
        
        // SCHRITT 1: Datei kopieren/croppen (oder nur bei Metadaten-Only überspringen)
        print("\n📋 SCHRITT 1: Datei vorbereiten")
        print("  Mode: \(cropSettings.mode.rawValue)")
        print("  Format: \(imageData.format)")
        print("  Nur Metadaten: \(onlyMetadata)")
        
        if onlyMetadata {
            // NUR METADATEN: Originalfile wird direkt mit Metadaten beschrieben
            print("  📋 Nur-Metadaten-Modus: Kein Cropping, Original wird behalten")
            // Bei "Original überschreiben" wird direkt ins Original geschrieben
            // Ansonsten erst kopieren, dann Metadaten schreiben
            if !overwriteOriginal {
                print("  📄 Kopiere Original zu Zielort...")
                copyImage(from: imageData.url, to: outputURL)
            }
        } else {
            // NORMALER MODUS: Bild wird physisch gecroppt
            if cropSettings.mode == .mcuSensitive && imageData.format == .jpeg {
                print("  🔄 MCU-Modus: Rufe performLosslessCrop auf...")
                // Bei MCU-Modus: Verlustfreies Cropping durchführen
                performLosslessCrop(sourceURL: imageData.url, outputURL: outputURL, cropBox: cropSettings.cropBox)
            } else {
                print("  📄 Standard-Modus: Kopiere Datei...")
                // Standard-Cropping: Bild kopieren
                copyImage(from: imageData.url, to: outputURL)
            }
        }
        
        print("  ✓ Schritt 1 abgeschlossen")
        
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
                let modeString = onlyMetadata ? "NUR METADATEN" : cropSettings.mode.rawValue
                cropDataString = String(format: 
                    "Origin: (%.3f, %.3f)\nSize: (%.3f, %.3f)\nMode: %@\nRatio: %@",
                    normalized.origin.x, normalized.origin.y,
                    normalized.size.width, normalized.size.height,
                    modeString,
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
        
        print("\n" + String(repeating: "=", count: 80))
        print("✅ EXPORT ERFOLGREICH ABGESCHLOSSEN")
        print(String(repeating: "=", count: 80) + "\n")
        
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


