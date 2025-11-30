//
//  ContentView.swift
//  PhotoCropper
//
//  Haupt-View mit Canvas, Controls und Navigation
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var batchManager: BatchImageManager
    @StateObject private var keyboardMonitor = KeyboardMonitor()
    @FocusState private var canvasHasFocus: Bool
    
    // Crop-Settings (gelten für aktuelles Bild)
    @State private var cropBox: CGRect = .zero
    @State private var targetRatio: AspectRatio = .ratio16_9
    @State private var cropMode: CropMode = .mcuSensitive
    @State private var activeOverlay: OverlayGuide = .none
    @State private var customWidth: String = "16"
    @State private var customHeight: String = "9"
    @State private var showBatchExport: Bool = false
    
    // Flag um onChange-Handler beim Laden von Metadaten zu unterdrücken
    @State private var isLoadingFromMetadata: Bool = false
    
    // Flag um onChange-Handler während Drag-Operationen zu unterdrücken
    @State private var isUpdatingFromDrag: Bool = false
    
    // Computed property für Custom-Ratio
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
            // Batch-Liste (immer sichtbar)
            BatchImageListView(batchManager: batchManager)
                .onDrop(of: [.fileURL], delegate: BatchDropDelegate(batchManager: batchManager, onDrop: { urls in
                    loadBatchImages(from: urls)
                }))
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
            
            // Canvas-Bereich
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
                    // Drag & Drop Bereich
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
            
            // Controls-Panel - Scrollbar bei Platzmangel
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
                        }
                    )
                    .onChange(of: targetRatio) { oldValue, newValue in
                        // Wenn wir gerade Metadaten laden, nichts tun!
                        guard !isLoadingFromMetadata else {
                            print("   ⏭️ onChange(targetRatio) übersprungen - laden von Metadaten")
                            return
                        }
                        
                        // Wenn auf Custom gewechselt wird, übernehme vorheriges Ratio
                        if case .custom = newValue {
                            // Nur wenn vorher NICHT custom war
                            switch oldValue {
                            case .ratio16_9:
                                customWidth = "16"
                                customHeight = "9"
                            case .ratio1_1:
                                customWidth = "1"
                                customHeight = "1"
                            case .custom:
                                break // Bereits custom, nichts tun
                            }
                        }
                        
                        // Crop-Box neu berechnen wenn Zielformat geändert wird
                        updateCropBoxForNewImage()
                    }
                    .onChange(of: customWidth) { oldValue, newValue in
                        // Wenn wir gerade Metadaten laden oder von Drag updaten, nichts tun!
                        guard !isLoadingFromMetadata && !isUpdatingFromDrag else { return }
                        
                        // Bei Custom-Ratio-Änderung: Crop-Box-Größe proportional anpassen
                        if case .custom = targetRatio {
                            adjustCropBoxForCustomRatio()
                        }
                    }
                    .onChange(of: customHeight) { oldValue, newValue in
                        // Wenn wir gerade Metadaten laden oder von Drag updaten, nichts tun!
                        guard !isLoadingFromMetadata && !isUpdatingFromDrag else { return }
                        
                        // Bei Custom-Ratio-Änderung: Crop-Box-Größe proportional anpassen
                        if case .custom = targetRatio {
                            adjustCropBoxForCustomRatio()
                        }
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
            // Wenn neues Bild ausgewählt wird
            loadCurrentBatchImage()
        }
        .onAppear {
            print("📱 ContentView appeared - Starte Keyboard Monitor")
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
            print("📱 ContentView disappeared - Stoppe Keyboard Monitor")
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
        panel.allowsMultipleSelection = true  // Immer Multi-Selection
        
        if panel.runModal() == .OK {
            // Filtere Video-Dateien aus
            let imageURLs = panel.urls.filter { url in
                guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
                    return true
                }
                // Nur Bilder, keine Videos
                return type.conforms(to: .image) && !type.conforms(to: .movie) && !type.conforms(to: .video)
            }
            loadBatchImages(from: imageURLs)
        }
    }
    
    private func loadBatchImages(from urls: [URL]) {
        // Filtere Video-Dateien aus
        let imageURLs = urls.filter { url in
            guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
                return true
            }
            // Nur Bilder, keine Videos
            return type.conforms(to: .image) && !type.conforms(to: .movie) && !type.conforms(to: .video)
        }
        
        let imageDatas = imageURLs.compactMap { ImageService.loadImage(from: $0) }
        
        // MCU-Größe für JPEGs bestimmen
        for (index, url) in imageURLs.enumerated() {
            if imageDatas[index].format == .jpeg {
                imageDatas[index].mcuSize = JPEGService.detectMCUSize(for: url)
            }
        }
        
        batchManager.addImages(imageDatas)
        
        // Lade erstes Bild
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
        
        // WICHTIG: Prüfe zuerst gespeicherte Crop-Metadaten, DANN BatchItem cropSettings
        if let cropMeta = currentItem.imageData.cropMetadata {
            // Gespeicherte Crop-Metadaten aus Bild laden (hat Priorität!)
            print("📖 Lade gespeicherte Crop-Metadaten aus EXIF")
            
            let imageSize = currentItem.imageData.pixelSize
            
            // Konvertiere normalisierte Koordinaten zurück zu Pixeln
            let pixelCropBox = CGRect(
                x: cropMeta.originX * imageSize.width,
                y: cropMeta.originY * imageSize.height,
                width: cropMeta.width * imageSize.width,
                height: cropMeta.height * imageSize.height
            )
            
            // Crop-Modus übernehmen
            cropMode = CropMode(rawValue: cropMeta.cropMode) ?? .standard
            
            // Target Ratio parsen und setzen - WICHTIG: Erst customWidth/Height, DANN targetRatio!
            if let parsedRatio = parseAspectRatioFromString(cropMeta.targetRatio) {
                // Flag setzen um onChange-Handler zu unterdrücken
                isLoadingFromMetadata = true
                
                // Bei Custom Ratio: ZUERST die Textfelder setzen
                if case .custom(let w, let h) = parsedRatio {
                    customWidth = String(w)
                    customHeight = String(h)
                    print("   → Custom Ratio erkannt: \(w):\(h)")
                }
                
                // DANN erst das targetRatio setzen
                targetRatio = parsedRatio
                
                // WICHTIG: Crop-Box setzen
                cropBox = pixelCropBox
                
                print("   → Crop-Box: \(pixelCropBox)")
                print("   → Mode: \(cropMode.rawValue)")
                print("   → Target Ratio: \(cropMeta.targetRatio) → \(parsedRatio.id)")
                print("   → customWidth: \(customWidth), customHeight: \(customHeight)")
                
                // Flag mit kurzer Verzögerung zurücksetzen, damit alle Updates durchlaufen
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isLoadingFromMetadata = false
                    print("   ✅ Metadaten-Laden abgeschlossen")
                }
            } else {
                print("   ⚠️ Konnte Target Ratio nicht parsen: \(cropMeta.targetRatio)")
            }
            
            // Auch die CropSettings im BatchItem aktualisieren
            currentItem.cropSettings = CropSettings(
                cropBox: pixelCropBox,
                targetRatio: targetRatio,
                mode: cropMode,
                originalRatio: currentItem.imageData.aspectRatioString
            )
        } else if let settings = currentItem.cropSettings {
            // Lade Crop-Settings aus BatchItem (nur wenn keine Metadaten vorhanden)
            print("📋 Lade Crop-Settings aus BatchItem")
            cropBox = settings.cropBox
            targetRatio = settings.targetRatio
            cropMode = settings.mode
            
            // Custom-Ratio Werte setzen
            if case .custom(let w, let h) = settings.targetRatio {
                customWidth = String(w)
                customHeight = String(h)
            }
        } else {
            // Initiale Crop-Box berechnen
            print("🆕 Keine gespeicherten Daten - berechne initiale Crop-Box")
            updateCropBoxForNewImage()
        }
    }
    
    /// Parst AspectRatio aus String (z.B. "16:9", "1:1", "3:2")
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
        
        // MCU-Snapping falls aktiv
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
        
        let newRatio = Double(w) / Double(h)
        let currentRatio = cropBox.width / cropBox.height
        
        var newBox = cropBox
        
        // Adjust size based on which dimension should stay closer to current
        if abs(newRatio - currentRatio) < 0.01 {
            // Ratio barely changed, keep box as is
            return
        }
        
        // Keep the smaller dimension and calculate the other
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
        
        updateCropBox(newBox)
    }
    
    private func updateCropBox(_ newBox: CGRect) {
        var updatedBox = newBox
        
        let displayImage = currentDisplayImage
        
        // MCU-Snapping falls aktiv
        if cropMode == .mcuSensitive, let displayImage = displayImage, let mcuSize = displayImage.mcuSize {
            updatedBox = CropEngine.snapToMCUGrid(
                coordinates: updatedBox,
                mcuSize: mcuSize,
                enabled: true
            )
        }
        
        // Validieren
        if let displayImage = displayImage {
            updatedBox = CropEngine.validateCropBox(updatedBox, imageSize: displayImage.pixelSize)
        }
        
        cropBox = updatedBox
        
        // Wenn Custom-Modus: customWidth und customHeight aktualisieren basierend auf tatsächlicher CropBox-Größe
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
        
        // Settings im BatchManager speichern
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
        // Berechne Custom-Ratio aus aktueller Crop-Box
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

/// Drag & Drop Delegate für Batch (mehrere Bilder)
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
                    print("Fehler beim Laden: \(error)")
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

