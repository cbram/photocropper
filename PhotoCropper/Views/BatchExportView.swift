//
//  BatchExportView.swift
//  PhotoCropper
//
//  Batch export dialog for multiple images
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
    @State private var imagesToExport: [BatchImageItem] = []  // List is created once!
    
    struct ExportResult {
        let filename: String
        let success: Bool
        let message: String
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("BATCH EXPORT")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if !showResults {
                // Configuration
                VStack(alignment: .leading, spacing: 16) {
                    // Number of images
                    HStack {
                        Image(systemName: "photo.stack")
                            .foregroundColor(.blue)
                        Text("\(batchManager.readyCount) images ready to export")
                            .font(.callout)
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    Divider()
                    
                    // Output directory
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Output Directory:")
                            .font(.callout)
                            .fontWeight(.semibold)
                        HStack {
                            Text(outputDirectory?.path ?? "Not selected")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Spacer()
                            Button("Select...") {
                                selectOutputDirectory()
                            }
                        }
                        Text("Default: Original directory of each image")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Options
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Overwrite original", isOn: $overwriteOriginal)
                            .foregroundColor(overwriteOriginal ? .red : .primary)
                        
                        if overwriteOriginal {
                            Toggle("Create backup of original", isOn: $createBackup)
                                .padding(.leading, 20)
                        }
                        
                        Divider()
                        
                        Toggle("Save crop data in EXIF", isOn: $saveCropMetadata)
                            .fontWeight(saveCropMetadata ? .semibold : .regular)
                        
                        if saveCropMetadata {
                            Toggle("Metadata only (don't physically crop image)", isOn: $onlyMetadata)
                                .padding(.leading, 20)
                            
                            if onlyMetadata {
                                HStack(spacing: 4) {
                                    Image(systemName: "tag.fill")
                                        .foregroundColor(.purple)
                                        .font(.caption)
                                    Text("Only EXIF tags will be written")
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
                        ProgressView(value: Double(currentExportIndex), total: Double(imagesToExport.count))
                        Text("Exporting \(currentExportIndex + 1) of \(imagesToExport.count)...")
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
                            Text("Cancel")
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
                            Text(isExporting ? "Exporting..." : "Save All")
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
                // Results
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        Text("Export completed")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    let successCount = exportResults.filter { $0.success }.count
                    let skippedCount = exportResults.filter { $0.success && $0.message.contains("Skipped") }.count
                    let writtenCount = successCount - skippedCount
                    let failCount = exportResults.count - successCount
                    
                    HStack(spacing: 20) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("\(writtenCount) written")
                        }
                        
                        if skippedCount > 0 {
                            HStack {
                                Image(systemName: "forward.circle.fill")
                                    .foregroundColor(.blue)
                                Text("\(skippedCount) skipped")
                            }
                        }
                        
                        if failCount > 0 {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("\(failCount) failed")
                            }
                        }
                    }
                    .font(.callout)
                    
                    Divider()
                    
                    // Result list
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(exportResults.enumerated()), id: \.offset) { index, result in
                                HStack(spacing: 8) {
                                    if result.success && result.message.contains("Skipped") {
                                        Image(systemName: "forward.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                    } else {
                                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(result.success ? .green : .red)
                                            .font(.caption)
                                    }
                                    
                                    Text(result.filename)
                                        .font(.caption)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    if result.success && result.message.contains("Skipped") {
                                        Text(result.message)
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    } else if !result.success {
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
        // Default: Directory of the first image
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
        
        // IMPORTANT: Create list ONCE at the beginning, NOT on each call!
        imagesToExport = batchManager.images.filter { item in
            if case .ready = item.status { return true }
            if case .editing = item.status { return true }
            return false
        }
        
        print("🚀 Starting batch export with \(imagesToExport.count) images")
        
        // Export all images sequentially
        exportNextImage()
    }
    
    private func exportNextImage() {
        print("📊 exportNextImage: currentIndex=\(currentExportIndex), totalCount=\(imagesToExport.count)")
        
        guard currentExportIndex < imagesToExport.count else {
            // Done!
            print("✅ All images exported!")
            isExporting = false
            showResults = true
            return
        }
        
        let item = imagesToExport[currentExportIndex]
        print("📤 Exporting image \(currentExportIndex + 1)/\(imagesToExport.count): \(item.imageData.url.lastPathComponent)")
        
        // Export image
        exportImage(item) { result in
            if result.success {
                print("📥 Export result for image \(self.currentExportIndex + 1): ✅ Success - \(result.filename)")
            } else {
                print("📥 Export result for image \(self.currentExportIndex + 1): ❌ Error - \(result.message)")
            }
            
            self.exportResults.append(result)
            
            // Mark as exported (must be on main thread!)
            DispatchQueue.main.async {
                if result.success {
                    item.status = .exported
                } else {
                    item.status = .error(result.message)
                }
            }
            
            self.currentExportIndex += 1
            
            // Next image (with small delay for UI update)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("🔄 Starting next image...")
                self.exportNextImage()
            }
        }
    }
    
    private func exportImage(_ item: BatchImageItem, completion: @escaping (ExportResult) -> Void) {
        // Execute export in background thread
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cropSettings = item.cropSettings else {
                DispatchQueue.main.async {
                    completion(ExportResult(
                        filename: item.imageData.url.lastPathComponent,
                        success: false,
                        message: "No crop settings"
                    ))
                }
                return
            }
            
            // Check if crop data is unchanged (only when "Metadata only" is active)
            if self.onlyMetadata && self.saveCropMetadata {
                if let existingMetadata = item.imageData.cropMetadata {
                    let imageSize = item.imageData.pixelSize
                    let normalized = cropSettings.normalizedCoordinates(for: imageSize)
                    
                    // Compare with tolerance due to float precision
                    let tolerance = 0.0001
                    let originMatches = abs(normalized.origin.x - existingMetadata.originX) < tolerance &&
                                       abs(normalized.origin.y - existingMetadata.originY) < tolerance
                    let sizeMatches = abs(normalized.size.width - existingMetadata.width) < tolerance &&
                                     abs(normalized.size.height - existingMetadata.height) < tolerance
                    let modeMatches = cropSettings.mode.rawValue == existingMetadata.cropMode
                    let ratioMatches = cropSettings.targetRatio.id == existingMetadata.targetRatio
                    
                    if originMatches && sizeMatches && modeMatches && ratioMatches {
                        print("⏭️ Skipping \(item.imageData.url.lastPathComponent) - Crop data is already identical")
                        DispatchQueue.main.async {
                            completion(ExportResult(
                                filename: item.imageData.url.lastPathComponent,
                                success: true,
                                message: "Skipped (no changes)"
                            ))
                        }
                        return
                    }
                }
            }
            
            // Generate filename
            let baseFilename = ExifDateParser.generateFilename(from: item.imageData)
            let ratioSuffix = ExifDateParser.suffixForRatio(cropSettings.targetRatio)
            let nameWithoutExtension = (baseFilename as NSString).deletingPathExtension
            let extensionString = item.imageData.url.pathExtension
            let filename = "\(nameWithoutExtension)_\(ratioSuffix).\(extensionString)"
        
            // Determine output URL
            let outputURL: URL
            if self.overwriteOriginal {
                outputURL = item.imageData.url
            } else {
                let directory = self.outputDirectory ?? item.imageData.url.deletingLastPathComponent()
                outputURL = directory.appendingPathComponent(filename)
            }
            
            print("📂 Target: \(outputURL.path)")
            print("📄 Source: \(item.imageData.url.path)")
            print("⚙️ Mode: \(self.onlyMetadata ? "Metadata only" : "Normal"), Overwrite: \(self.overwriteOriginal)")
            print("💾 Backup: \(self.createBackup ? "Yes" : "No")")
            
            // Create backup if requested
            if self.createBackup && self.overwriteOriginal {
                print("💾 Creating backup...")
                self.createBackupFile(for: item.imageData.url)
            }
            
            // Perform export
            if self.onlyMetadata {
                // Metadata only: Copy file if necessary
                if !self.overwriteOriginal {
                    do {
                        print("📋 Copying for metadata mode...")
                        try FileManager.default.copyItem(at: item.imageData.url, to: outputURL)
                    } catch {
                        print("❌ Copy failed: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            completion(ExportResult(
                                filename: filename,
                                success: false,
                                message: "Copy failed: \(error.localizedDescription)"
                            ))
                        }
                        return
                    }
                }
            } else {
                // Physical crop mode
                if cropSettings.mode == .mcuSensitive && item.imageData.format == .jpeg {
                    print("✂️ MCU mode: Lossless JPEG cropping...")
                    // MCU-lossless cropping for JPEG
                    let result = JPEGService.cropLossless(
                        imageURL: item.imageData.url,
                        cropRect: cropSettings.cropBox,
                        outputURL: outputURL
                    )
                    
                    if case .failure(let error) = result {
                        print("❌ MCU cropping failed: \(error.localizedDescription)")
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
                    print("✂️ Standard mode: Physical cropping (all formats)...")
                    // Standard cropping for all formats (HEIC, PNG, JPEG, etc.)
                    let result = ImageCropService.cropStandard(
                        imageURL: item.imageData.url,
                        cropRect: cropSettings.cropBox,
                        outputURL: outputURL
                    )
                    
                    if case .failure(let error) = result {
                        print("❌ Standard cropping failed: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            completion(ExportResult(
                                filename: filename,
                                success: false,
                                message: error.localizedDescription
                            ))
                        }
                        return
                    }
                }
            }
            
            // Save metadata ONLY if metadata-only mode is active
            // IMPORTANT: Don't save crop metadata if image was physically cropped
            // to prevent double-cropping in other applications!
            if self.saveCropMetadata && self.onlyMetadata {
                print("💾 Saving crop metadata (metadata-only mode)...")
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
                            message: "Metadata error: \(error.localizedDescription)"
                        ))
                    }
                    return
                }
            } else if !self.onlyMetadata {
                print("💾 Skipping crop metadata (image was physically cropped)")
            }
            
            // Success!
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
                print("   ⚠️ Removing old backup: \(backupURL.lastPathComponent)")
                try fileManager.removeItem(at: backupURL)
            }
            try fileManager.copyItem(at: url, to: backupURL)
            print("   ✅ Backup created: \(backupURL.lastPathComponent)")
        } catch {
            print("   ❌ Backup creation failed: \(error.localizedDescription)")
        }
    }
}

