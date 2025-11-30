//
//  ContentView.swift
//  PhotoCropper
//
//  Main view with canvas, controls, and navigation
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var batchManager: BatchImageManager
    @StateObject private var keyboardMonitor = KeyboardMonitor()
    @FocusState private var canvasHasFocus: Bool
    
    // Crop settings (applied to current image)
    @State private var cropBox: CGRect = .zero
    @State private var targetRatio: AspectRatio = .ratio16_9
    @State private var cropMode: CropMode = .mcuSensitive
    @State private var activeOverlay: OverlayGuide = .none
    @State private var customWidth: String = "16"
    @State private var customHeight: String = "9"
    @State private var showBatchExport: Bool = false
    
    // Flag to suppress onChange handlers when loading metadata
    @State private var isLoadingFromMetadata: Bool = false
    
    // Flag to suppress onChange handlers during drag operations
    @State private var isUpdatingFromDrag: Bool = false
    
    // Computed property for custom ratio
    private var effectiveTargetRatio: AspectRatio {
        if case .custom = targetRatio {
            if let width = Int(customWidth), let height = Int(customHeight), width > 0 && height > 0 {
                return .custom(width: width, height: height)
            }
        }
        return targetRatio
    }
    
    var body: some View {
        HSplitView {
            // Batch list (always visible)
            BatchImageListView(batchManager: batchManager)
                .onDrop(of: [.fileURL], delegate: BatchDropDelegate(batchManager: batchManager, onDrop: { urls in
                    loadBatchImages(from: urls)
                }))
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
            
            // Canvas area
            VStack(spacing: 0) {
                // Top Navigation - Compact for smaller screens
                HStack(spacing: 12) {
                    Text("PhotoCropper")
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Spacer(minLength: 8)
                    
                    // Compact Buttons
                    Button(action: {
                        batchManager.markCurrentAsReadyAndNext()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                            Text("Done")
                                .lineLimit(1)
                        }
                    }
                    .disabled(batchManager.currentImage == nil)
                    .help("Done & Next (Enter)")
                    
                    Button(action: {
                        showBatchExport = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down.on.square")
                            Text("Save")
                                .lineLimit(1)
                        }
                    }
                    .disabled(!batchManager.allReady)
                    .help("Save all")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                
                // Canvas
                if let displayImageData = currentDisplayImage {
                    CanvasView(
                        image: Binding(
                            get: { displayImageData.image },
                            set: { _ in }
                        ),
                        cropBox: $cropBox,
                        imageSize: displayImageData.pixelSize,
                        showMCUGrid: activeOverlay == .mcuGrid,
                        mcuSize: displayImageData.mcuSize ?? CGSize(width: 8, height: 8),
                        compositionOverlay: activeOverlay.asCompositionOverlay,
                        targetAspectRatio: {
                            switch targetRatio {
                            case .ratio16_9:
                                return 16.0 / 9.0
                            case .ratio1_1:
                                return 1.0
                            case .custom:
                                return nil
                            }
                        }(),
                        onCropBoxChanged: { newBox in
                            updateCropBox(newBox)
                        },
                        onRatioChanged: {
                            switchToCustomRatio()
                        }
                    )
                    .frame(minWidth: 300, minHeight: 300)
                    .background(Color.black)
                    .focused($canvasHasFocus)
                    .onAppear {
                        print("🖼️ Canvas appeared - Setting focus")
                        canvasHasFocus = true
                    }
                    .onTapGesture {
                        print("👆 Canvas tapped - Setting focus")
                        canvasHasFocus = true
                    }
                    .onChange(of: canvasHasFocus) { oldValue, newValue in
                        print("🎯 Canvas Focus changed: \(oldValue) -> \(newValue)")
                    }
                } else {
                    // Drag & drop area
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                VStack(spacing: 12) {
                                    Image(systemName: "photo.stack")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    Text("Drop images here")
                                        .foregroundColor(.secondary)
                                    Text("or open files")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            )
                    }
                    .onDrop(of: [.fileURL], delegate: BatchDropDelegate(batchManager: batchManager, onDrop: { urls in
                        loadBatchImages(from: urls)
                    }))
                }
            }
            
            // Controls panel - scrollbar when space is limited
            ScrollView {
                VStack(spacing: 0) {
                    ControlsView(
                        targetRatio: $targetRatio,
                        cropMode: $cropMode,
                        activeOverlay: $activeOverlay,
                        cropBox: $cropBox,
                        customWidth: $customWidth,
                        customHeight: $customHeight,
                        imageSize: currentDisplayImage?.pixelSize ?? .zero,
                        imageFormat: currentDisplayImage?.format,
                        onCenter: {
                            centerCropBox()
                        },
                        onReset: {
                            resetCropBox()
                        },
                        onMaximize: {
                            maximizeCropBox()
                        },
                        onCropBoxChanged: { newBox in
                            updateCropBox(newBox)
                        },
                        onCustomRatioChanged: {
                            // User changed custom ratio in text fields - adjust crop box
                            adjustCropBoxForCustomRatio()
                        }
                    )
                    .onChange(of: targetRatio) { oldValue, newValue in
                        // If we're currently loading metadata, do nothing!
                        guard !isLoadingFromMetadata else {
                            print("   ⏭️ onChange(targetRatio) skipped - loading from metadata")
                            return
                        }
                        
                        // When switching to custom, adopt previous ratio
                        if case .custom = newValue {
                            // Only if not already custom
                            switch oldValue {
                            case .ratio16_9:
                                customWidth = "16"
                                customHeight = "9"
                            case .ratio1_1:
                                customWidth = "1"
                                customHeight = "1"
                            case .custom:
                                break // Already custom, do nothing
                            }
                        }
                        
                        // Recalculate crop box when target format changes
                        updateCropBoxForNewImage()
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    InfoPanel(imageData: currentDisplayImage)
                }
            }
            .frame(minWidth: 250, idealWidth: 300, maxWidth: 350)
        }
        .sheet(isPresented: $showBatchExport) {
            BatchExportView(
                isPresented: $showBatchExport,
                batchManager: batchManager
            )
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: openFile) {
                    Label("Open", systemImage: "folder")
                }
            }
        }
        .onChange(of: batchManager.currentIndex) { oldValue, newValue in
            // When a new image is selected
            loadCurrentBatchImage()
        }
        .onAppear {
            print("📱 ContentView appeared - Starting keyboard monitor")
            keyboardMonitor.onSpacePressed = {
                print("⌨️ Space-Handler von KeyboardMonitor aufgerufen")
                toggleCompositionOverlay()
            }
            keyboardMonitor.onEnterPressed = {
                print("⌨️ Enter-Handler von KeyboardMonitor aufgerufen")
                batchManager.nextImage()
            }
            keyboardMonitor.startMonitoring()
        }
        .onDisappear {
            print("📱 ContentView disappeared - Stopping keyboard monitor")
            keyboardMonitor.stopMonitoring()
        }
    }
    
    // MARK: - Computed Properties
    
    var currentDisplayImage: ImageData? {
        return batchManager.currentImage?.imageData
    }
    
    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .heic, .png, .tiff]
        panel.allowsMultipleSelection = true  // Always allow multi-selection
        
        if panel.runModal() == .OK {
            // Filter out video files
            let imageURLs = panel.urls.filter { url in
                guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
                    return true
                }
                // Only images, no videos
                return type.conforms(to: .image) && !type.conforms(to: .movie) && !type.conforms(to: .video)
            }
            loadBatchImages(from: imageURLs)
        }
    }
    
    private func loadBatchImages(from urls: [URL]) {
        // Filter out video files
        let imageURLs = urls.filter { url in
            guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
                return true
            }
            // Only images, no videos
            return type.conforms(to: .image) && !type.conforms(to: .movie) && !type.conforms(to: .video)
        }
        
        let imageDatas = imageURLs.compactMap { ImageService.loadImage(from: $0) }
        
        // Determine MCU size for JPEGs
        for (index, url) in imageURLs.enumerated() {
            if imageDatas[index].format == .jpeg {
                imageDatas[index].mcuSize = JPEGService.detectMCUSize(for: url)
            }
        }
        
        batchManager.addImages(imageDatas)
        
        // Load first image
        if batchManager.hasImages {
            loadCurrentBatchImage()
        }
    }
    
    private func loadCurrentBatchImage() {
        guard let currentItem = batchManager.currentImage else { return }
        
        print("📸 loadCurrentBatchImage für: \(currentItem.imageData.url.lastPathComponent)")
        print("   hasCropMetadata: \(currentItem.imageData.hasCropMetadata)")
        print("   cropSettings vorhanden: \(currentItem.cropSettings != nil)")
        
        // Reset MCU Grid overlay if not JPEG
        if currentItem.imageData.format != .jpeg && activeOverlay == .mcuGrid {
            print("ℹ️ Resetting MCU Grid overlay (not a JPEG)")
            activeOverlay = .none
        }
        
        // IMPORTANT: Check saved crop metadata first, THEN BatchItem cropSettings
        if let cropMeta = currentItem.imageData.cropMetadata {
            // Load saved crop metadata from image (has priority!)
            print("📖 Loading saved crop metadata from EXIF")
            
            let imageSize = currentItem.imageData.pixelSize
            
            // Convert normalized coordinates back to pixels
            let pixelCropBox = CGRect(
                x: cropMeta.originX * imageSize.width,
                y: cropMeta.originY * imageSize.height,
                width: cropMeta.width * imageSize.width,
                height: cropMeta.height * imageSize.height
            )
            
            // Adopt crop mode
            cropMode = CropMode(rawValue: cropMeta.cropMode) ?? .standard
            
            // Parse and set target ratio - IMPORTANT: First customWidth/Height, THEN targetRatio!
            if let parsedRatio = parseAspectRatioFromString(cropMeta.targetRatio) {
                // Set flag to suppress onChange handlers
                isLoadingFromMetadata = true
                
                // For custom ratio: FIRST set the text fields
                if case .custom(let w, let h) = parsedRatio {
                    customWidth = String(w)
                    customHeight = String(h)
                    print("   → Custom ratio detected: \(w):\(h)")
                }
                
                // THEN set the targetRatio
                targetRatio = parsedRatio
                
                // IMPORTANT: Set crop box
                cropBox = pixelCropBox
                
                print("   → Crop-Box: \(pixelCropBox)")
                print("   → Mode: \(cropMode.rawValue)")
                print("   → Target Ratio: \(cropMeta.targetRatio) → \(parsedRatio.id)")
                print("   → customWidth: \(customWidth), customHeight: \(customHeight)")
                
                // Reset flag with short delay to allow all updates to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isLoadingFromMetadata = false
                    print("   ✅ Metadata loading completed")
                }
            } else {
                print("   ⚠️ Could not parse target ratio: \(cropMeta.targetRatio)")
            }
            
            // Also update the CropSettings in the BatchItem
            currentItem.cropSettings = CropSettings(
                cropBox: pixelCropBox,
                targetRatio: targetRatio,
                mode: cropMode,
                originalRatio: currentItem.imageData.aspectRatioString
            )
        } else if let settings = currentItem.cropSettings {
            // Load crop settings from BatchItem (only if no metadata present)
            print("📋 Loading crop settings from BatchItem")
            cropBox = settings.cropBox
            targetRatio = settings.targetRatio
            cropMode = settings.mode
            
            // Set custom ratio values
            if case .custom(let w, let h) = settings.targetRatio {
                customWidth = String(w)
                customHeight = String(h)
            }
        } else {
            // Calculate initial crop box
            print("🆕 No saved data - calculating initial crop box")
            updateCropBoxForNewImage()
        }
    }
    
    /// Parses AspectRatio from string (e.g. "16:9", "1:1", "3:2")
    private func parseAspectRatioFromString(_ ratioString: String) -> AspectRatio? {
        if ratioString == "16:9" {
            return .ratio16_9
        } else if ratioString == "1:1" {
            return .ratio1_1
        } else {
            // Parse any "width:height" format as custom
            let parts = ratioString.components(separatedBy: ":")
            if parts.count == 2,
               let width = Int(parts[0]),
               let height = Int(parts[1]) {
                return .custom(width: width, height: height)
            }
        }
        return nil
    }
    
    private func updateCropBoxForNewImage() {
        guard let displayImage = currentDisplayImage else { return }
        
        let ratio = effectiveTargetRatio
        let cropSize = ratio.calculateCropSize(for: displayImage.pixelSize)
        let position = ratio.calculateDefaultPosition(
            for: displayImage.pixelSize,
            cropSize: cropSize
        )
        
        cropBox = CGRect(origin: position, size: cropSize)
        
        // MCU snapping if active
        if cropMode == .mcuSensitive, let mcuSize = displayImage.mcuSize {
            cropBox = CropEngine.snapToMCUGrid(
                coordinates: cropBox,
                mcuSize: mcuSize,
                enabled: true
            )
        }
    }
    
    /// Adjusts crop box size proportionally when custom ratio changes
    /// This maintains the current position and relative size instead of maximizing
    private func adjustCropBoxForCustomRatio() {
        guard let displayImage = currentDisplayImage else { return }
        guard case .custom(let w, let h) = effectiveTargetRatio else { return }
        guard w > 0 && h > 0 else { return }
        
        // Calculate the current ratio from the actual crop box
        let currentRatio = cropBox.width / cropBox.height
        let newRatio = Double(w) / Double(h)
        
        // If the ratios are very close, the change came from drag operation updating the text fields
        // In this case, do nothing (the box is already correct)
        if abs(newRatio - currentRatio) < 0.001 {
            return
        }
        
        var newBox = cropBox
        
        // Adjust size based on which dimension should stay closer to current
        if newRatio > currentRatio {
            // New ratio is wider - keep height, adjust width
            newBox.size.width = newBox.size.height * CGFloat(newRatio)
        } else {
            // New ratio is taller - keep width, adjust height
            newBox.size.height = newBox.size.width / CGFloat(newRatio)
        }
        
        // Validate and apply
        newBox = CropEngine.validateCropBox(newBox, imageSize: displayImage.pixelSize)
        
        // If validation had to shrink the box significantly, center it
        let sizeRatio = (newBox.width * newBox.height) / (cropBox.width * cropBox.height)
        if sizeRatio < 0.5 {
            newBox = CropEngine.centerCropBox(cropBox: newBox, imageSize: displayImage.pixelSize)
        }
        
        // Set flag before updating to prevent recursion
        isUpdatingFromDrag = true
        updateCropBox(newBox)
        // Reset flag immediately after - the onChange check will still prevent recursion
        DispatchQueue.main.async {
            self.isUpdatingFromDrag = false
        }
    }
    
    private func updateCropBox(_ newBox: CGRect) {
        var updatedBox = newBox
        
        let displayImage = currentDisplayImage
        
        // MCU snapping if active
        if cropMode == .mcuSensitive, let displayImage = displayImage, let mcuSize = displayImage.mcuSize {
            updatedBox = CropEngine.snapToMCUGrid(
                coordinates: updatedBox,
                mcuSize: mcuSize,
                enabled: true
            )
        }
        
        // Validate
        if let displayImage = displayImage {
            updatedBox = CropEngine.validateCropBox(updatedBox, imageSize: displayImage.pixelSize)
        }
        
        cropBox = updatedBox
        
        // If custom mode: update customWidth and customHeight based on actual crop box size
        // Set flag to prevent onChange handlers from firing during this update
        if case .custom = targetRatio {
            isUpdatingFromDrag = true
            let ratio = calculateImageAspectRatio(size: updatedBox.size)
            customWidth = String(ratio.width)
            customHeight = String(ratio.height)
            // Reset flag after a short delay to allow all updates to complete
            DispatchQueue.main.async {
                self.isUpdatingFromDrag = false
            }
        }
        
        // Save settings in BatchManager
        if let currentItem = batchManager.currentImage {
            let settings = CropSettings(
                cropBox: updatedBox,
                targetRatio: effectiveTargetRatio,
                mode: cropMode,
                originalRatio: currentItem.imageData.aspectRatioString,
                mcuSize: currentItem.imageData.mcuSize
            )
            currentItem.cropSettings = settings
        }
    }
    
    private func centerCropBox() {
        guard let displayImage = currentDisplayImage else { return }
        cropBox = CropEngine.centerCropBox(cropBox: cropBox, imageSize: displayImage.pixelSize)
    }
    
    private func resetCropBox() {
        updateCropBoxForNewImage()
    }
    
    private func maximizeCropBox() {
        guard let displayImage = currentDisplayImage else { return }
        cropBox = CropEngine.maximizeCropBox(imageSize: displayImage.pixelSize, targetRatio: effectiveTargetRatio)
    }
    
    private func switchToCustomRatio() {
        // Calculate custom ratio from current crop box
        let ratio = calculateImageAspectRatio(size: cropBox.size)
        
        // Set flag to prevent onChange handlers from triggering during this update
        isUpdatingFromDrag = true
        
        customWidth = String(ratio.width)
        customHeight = String(ratio.height)
        targetRatio = .custom(width: ratio.width, height: ratio.height)
        
        // Reset flag after a short delay to allow all updates to complete
        DispatchQueue.main.async {
            self.isUpdatingFromDrag = false
        }
    }
    
    private func toggleCompositionOverlay() {
        print("🎯 toggleOverlay called")
        print("   activeOverlay BEFORE: \(activeOverlay)")
        
        // Cycle through overlay options
        let allCases = OverlayGuide.allCases
        if let currentIndex = allCases.firstIndex(of: activeOverlay) {
            let nextIndex = (currentIndex + 1) % allCases.count
            activeOverlay = allCases[nextIndex]
        } else {
            activeOverlay = .none
        }
        
        print("   activeOverlay AFTER: \(activeOverlay)")
    }
}

/// Drag & drop delegate for batch (multiple images)
struct BatchDropDelegate: DropDelegate {
    @ObservedObject var batchManager: BatchImageManager
    let onDrop: ([URL]) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        let itemProviders = info.itemProviders(for: [.fileURL])
        guard !itemProviders.isEmpty else { return false }
        
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for itemProvider in itemProviders {
            group.enter()
            itemProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                defer { group.leave() }
                
                if let error = error {
                    print("Error loading: \(error)")
                    return
                }
                
                if let urlData = urlData as? Data {
                    let url = NSURL(absoluteURLWithDataRepresentation: urlData, relativeTo: nil) as URL
                    urls.append(url)
                } else if let url = urlData as? URL {
                    urls.append(url)
                }
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                onDrop(urls)
            }
        }
        
        return true
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.fileURL])
    }
}

