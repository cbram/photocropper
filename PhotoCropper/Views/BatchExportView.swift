//
//  BatchExportView.swift
//  PhotoCropper
//
//  Batch-Export-Dialog für mehrere Bilder
//

import SwiftUI
import AppKit

struct BatchExportView: View {
    @Binding var isPresented: Bool
    @ObservedObject var batchManager: BatchImageManager
    
    @State private var outputDirectory: URL?
    @State private var overwriteOriginal: Bool = false
    @State private var createBackup: Bool = false
    @State private var saveCropMetadata: Bool = true
    @State private var onlyMetadata: Bool = false
    @State private var isExporting: Bool = false
    @State private var currentExportIndex: Int = 0
    @State private var exportResults: [ExportResult] = []
    @State private var showResults: Bool = false
    
    struct ExportResult {
        let filename: String
        let success: Bool
        let message: String
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("BATCH-EXPORT")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if !showResults {
                // Konfiguration
                VStack(alignment: .leading, spacing: 16) {
                    // Anzahl Bilder
                    HStack {
                        Image(systemName: "photo.stack")
                            .foregroundColor(.blue)
                        Text("\(batchManager.readyCount) Bilder bereit zum Export")
                            .font(.callout)
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    Divider()
                    
                    // Zielordner
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Zielordner:")
                            .font(.callout)
                            .fontWeight(.semibold)
                        HStack {
                            Text(outputDirectory?.path ?? "Nicht ausgewählt")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Spacer()
                            Button("Auswählen...") {
                                selectOutputDirectory()
                            }
                        }
                        Text("Standard: Ursprungsordner jedes Bildes")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Optionen
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Original überschreiben", isOn: $overwriteOriginal)
                            .foregroundColor(overwriteOriginal ? .red : .primary)
                        
                        if overwriteOriginal {
                            Toggle("Backup des Originals erstellen", isOn: $createBackup)
                                .padding(.leading, 20)
                        }
                        
                        Divider()
                        
                        Toggle("Crop-Daten in EXIF speichern", isOn: $saveCropMetadata)
                            .fontWeight(saveCropMetadata ? .semibold : .regular)
                        
                        if saveCropMetadata {
                            Toggle("Nur Metadaten (Bild nicht physisch croppen)", isOn: $onlyMetadata)
                                .padding(.leading, 20)
                            
                            if onlyMetadata {
                                HStack(spacing: 4) {
                                    Image(systemName: "tag.fill")
                                        .foregroundColor(.purple)
                                        .font(.caption)
                                    Text("Nur EXIF-Tags werden geschrieben")
                                        .font(.caption2)
                                        .foregroundColor(.purple)
                                }
                                .padding(.leading, 40)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Progress
                if isExporting {
                    VStack(spacing: 8) {
                        ProgressView(value: Double(currentExportIndex), total: Double(batchManager.readyCount))
                        Text("Exportiere \(currentExportIndex + 1) von \(batchManager.readyCount)...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Buttons
                HStack(spacing: 12) {
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
                    .disabled(isExporting)
                    
                    Button(action: {
                        startBatchExport()
                    }) {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "square.and.arrow.down.on.square.fill")
                            }
                            Text(isExporting ? "Exportiere..." : "Alle speichern")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isExporting ? Color.blue.opacity(0.5) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isExporting || batchManager.readyCount == 0)
                }
            } else {
                // Ergebnisse
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        Text("Export abgeschlossen")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    let successCount = exportResults.filter { $0.success }.count
                    let failCount = exportResults.count - successCount
                    
                    HStack(spacing: 20) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("\(successCount) erfolgreich")
                        }
                        
                        if failCount > 0 {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("\(failCount) fehlgeschlagen")
                            }
                        }
                    }
                    .font(.callout)
                    
                    Divider()
                    
                    // Ergebnis-Liste
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(exportResults.enumerated()), id: \.offset) { index, result in
                                HStack(spacing: 8) {
                                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(result.success ? .green : .red)
                                        .font(.caption)
                                    
                                    Text(result.filename)
                                        .font(.caption)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    if !result.success {
                                        Text(result.message)
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(height: 200)
                    
                    Button(action: {
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
                }
            }
        }
        .padding()
        .frame(width: 600, height: 550)
        .onAppear {
            setupDefaultOutputDirectory()
        }
    }
    
    private func setupDefaultOutputDirectory() {
        // Standard: Ordner des ersten Bildes
        if let firstImage = batchManager.images.first {
            outputDirectory = firstImage.imageData.url.deletingLastPathComponent()
        }
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
    
    private func startBatchExport() {
        isExporting = true
        exportResults = []
        currentExportIndex = 0
        
        // Exportiere alle Bilder nacheinander
        exportNextImage()
    }
    
    private func exportNextImage() {
        let readyImages = batchManager.images.filter { item in
            if case .ready = item.status { return true }
            if case .editing = item.status { return true }
            return false
        }
        
        guard currentExportIndex < readyImages.count else {
            // Fertig!
            isExporting = false
            showResults = true
            return
        }
        
        let item = readyImages[currentExportIndex]
        
        // Exportiere Bild
        exportImage(item) { result in
            exportResults.append(result)
            
            // Markiere als exportiert
            if result.success {
                item.status = .exported
            } else {
                item.status = .error(result.message)
            }
            
            currentExportIndex += 1
            
            // Nächstes Bild (mit kleiner Verzögerung für UI-Update)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                exportNextImage()
            }
        }
    }
    
    private func exportImage(_ item: BatchImageItem, completion: @escaping (ExportResult) -> Void) {
        // Führe Export in Background-Thread aus
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cropSettings = item.cropSettings else {
                DispatchQueue.main.async {
                    completion(ExportResult(
                        filename: item.imageData.url.lastPathComponent,
                        success: false,
                        message: "Keine Crop-Einstellungen"
                    ))
                }
                return
            }
            
            // Dateiname generieren
            let baseFilename = ExifDateParser.generateFilename(from: item.imageData)
            let ratioSuffix = ExifDateParser.suffixForRatio(cropSettings.targetRatio)
            let nameWithoutExtension = (baseFilename as NSString).deletingPathExtension
            let extensionString = item.imageData.url.pathExtension
            let filename = "\(nameWithoutExtension)_\(ratioSuffix).\(extensionString)"
        
            // Ziel-URL bestimmen
            let outputURL: URL
            if self.overwriteOriginal {
                outputURL = item.imageData.url
            } else {
                let directory = self.outputDirectory ?? item.imageData.url.deletingLastPathComponent()
                outputURL = directory.appendingPathComponent(filename)
            }
            
            // Backup falls gewünscht
            if self.createBackup && self.overwriteOriginal {
                self.createBackupFile(for: item.imageData.url)
            }
            
            // Export durchführen
            if self.onlyMetadata {
                // Nur Metadaten: Datei kopieren falls nötig
                if !self.overwriteOriginal {
                    do {
                        try FileManager.default.copyItem(at: item.imageData.url, to: outputURL)
                    } catch {
                        DispatchQueue.main.async {
                            completion(ExportResult(
                                filename: filename,
                                success: false,
                                message: "Kopieren fehlgeschlagen"
                            ))
                        }
                        return
                    }
                }
            } else {
                // Normaler Export mit Cropping
                if cropSettings.mode == .mcuSensitive && item.imageData.format == .jpeg {
                    // MCU-lossless cropping
                    let result = JPEGService.cropLossless(
                        imageURL: item.imageData.url,
                        cropRect: cropSettings.cropBox,
                        outputURL: outputURL
                    )
                    
                    if case .failure(let error) = result {
                        DispatchQueue.main.async {
                            completion(ExportResult(
                                filename: filename,
                                success: false,
                                message: error.localizedDescription
                            ))
                        }
                        return
                    }
                } else {
                    // Standard: Datei kopieren
                    do {
                        if FileManager.default.fileExists(atPath: outputURL.path) {
                            try FileManager.default.removeItem(at: outputURL)
                        }
                        try FileManager.default.copyItem(at: item.imageData.url, to: outputURL)
                    } catch {
                        DispatchQueue.main.async {
                            completion(ExportResult(
                                filename: filename,
                                success: false,
                                message: "Kopieren fehlgeschlagen"
                            ))
                        }
                        return
                    }
                }
            }
            
            // Metadaten speichern falls gewünscht
            if self.saveCropMetadata {
                let result = MetadataService.saveCropMetadata(
                    imageURL: outputURL,
                    cropBox: cropSettings.cropBox,
                    imageSize: item.imageData.pixelSize,
                    targetRatio: cropSettings.targetRatio,
                    mode: cropSettings.mode,
                    originalRatio: cropSettings.originalRatio
                )
                
                if case .failure(let error) = result {
                    DispatchQueue.main.async {
                        completion(ExportResult(
                            filename: filename,
                            success: false,
                            message: "Metadaten-Fehler: \(error.localizedDescription)"
                        ))
                    }
                    return
                }
            }
            
            // Erfolg!
            DispatchQueue.main.async {
                completion(ExportResult(
                    filename: filename,
                    success: true,
                    message: "OK"
                ))
            }
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

