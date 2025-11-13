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
    @StateObject private var batchManager = BatchImageManager()
    @State private var isBatchMode: Bool = false
    
    // Single-Image Modus
    @State private var imageData: ImageData?
    @State private var cropBox: CGRect = .zero
    @State private var targetRatio: AspectRatio = .ratio16_9
    @State private var cropMode: CropMode = .mcuSensitive
    @State private var autoFallback: Bool = true
    @State private var showMCUGrid: Bool = false
    @State private var customWidth: String = "16"
    @State private var customHeight: String = "9"
    @State private var showExportView: Bool = false
    @State private var showBatchExport: Bool = false
    
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
            // Batch-Liste (falls Batch-Modus)
            if isBatchMode {
                BatchImageListView(batchManager: batchManager)
                    .onDrop(of: [.fileURL], delegate: BatchDropDelegate(batchManager: batchManager, onDrop: { urls in
                        loadBatchImages(from: urls)
                    }))
            }
            
            // Canvas-Bereich
            VStack {
                // Top Navigation
                HStack {
                    // Mode Toggle
                    Picker("Modus", selection: $isBatchMode) {
                        Text("Einzelbild").tag(false)
                        Text("Batch").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    
                    Spacer()
                    
                    if isBatchMode {
                        Button(action: {
                            batchManager.markCurrentAsReadyAndNext()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("Fertig & Weiter")
                            }
                        }
                        .disabled(batchManager.currentImage == nil)
                        
                        Button(action: {
                            showBatchExport = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down.on.square")
                                Text("Alle speichern")
                            }
                        }
                        .disabled(!batchManager.allReady)
                    } else {
                        Button("Speichern") {
                            showExportView = true
                        }
                        .disabled(imageData == nil)
                    }
                }
                .padding()
                
                // Canvas
                if let displayImageData = currentDisplayImage {
                    CanvasView(
                        image: Binding(
                            get: { displayImageData.image },
                            set: { _ in }
                        ),
                        cropBox: $cropBox,
                        imageSize: displayImageData.pixelSize,
                        showMCUGrid: showMCUGrid,
                        mcuSize: displayImageData.mcuSize ?? CGSize(width: 8, height: 8),
                        onCropBoxChanged: { newBox in
                            updateCropBox(newBox)
                        },
                        onRatioChanged: {
                            switchToCustomRatio()
                        }
                    )
                    .background(Color.black)
                } else {
                    // Drag & Drop Bereich
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                VStack(spacing: 12) {
                                    Image(systemName: isBatchMode ? "photo.stack" : "photo.on.rectangle")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    if isBatchMode {
                                        Text("Mehrere Bilder hier ablegen")
                                            .foregroundColor(.secondary)
                                        Text("oder Dateien öffnen")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    } else {
                                        Text("Bild hier ablegen oder Datei öffnen")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            )
                    }
                    .onDrop(of: [.fileURL], delegate: isBatchMode ? 
                        BatchDropDelegate(batchManager: batchManager, onDrop: { urls in
                            loadBatchImages(from: urls)
                        }) : 
                        ImageDropDelegate(onDrop: { url in
                            loadImage(from: url)
                        })
                    )
                }
            }
            
            // Controls-Panel (30%)
            VStack {
                ControlsView(
                    targetRatio: $targetRatio,
                    cropMode: $cropMode,
                    autoFallback: $autoFallback,
                    showMCUGrid: $showMCUGrid,
                    cropBox: $cropBox,
                    customWidth: $customWidth,
                    customHeight: $customHeight,
                    imageSize: currentDisplayImage?.pixelSize ?? .zero,
                    onCenter: {
                        centerCropBox()
                    },
                    onReset: {
                        resetCropBox()
                    },
                    onMaximize: {
                        maximizeCropBox()
                    }
                )
                .onChange(of: targetRatio) { oldValue, newValue in
                    // Crop-Box neu berechnen wenn Zielformat geändert wird
                    updateCropBoxForNewImage()
                }
                .onChange(of: customWidth) { oldValue, newValue in
                    // Auch bei Custom-Ratio-Änderung neu berechnen
                    if case .custom = targetRatio {
                        updateCropBoxForNewImage()
                    }
                }
                .onChange(of: customHeight) { oldValue, newValue in
                    // Auch bei Custom-Ratio-Änderung neu berechnen
                    if case .custom = targetRatio {
                        updateCropBoxForNewImage()
                    }
                }
                
                Divider()
                
                PreviewView(
                    image: currentDisplayImage?.image,
                    cropBox: cropBox,
                    imageSize: currentDisplayImage?.pixelSize ?? .zero,
                    targetRatio: effectiveTargetRatio
                )
                
                Divider()
                
                InfoPanel(imageData: currentDisplayImage)
                
                Spacer()
            }
            .frame(width: 300)
        }
        .sheet(isPresented: $showExportView) {
            if let imageData = imageData {
                ExportView(
                    isPresented: $showExportView,
                    imageData: imageData,
                    cropSettings: createCropSettings()
                )
            }
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
                    Label("Öffnen", systemImage: "folder")
                }
            }
        }
        .onChange(of: isBatchMode) { oldValue, newValue in
            // Beim Wechsel zwischen Modi synchronisieren
            syncBatchAndSingleMode()
        }
        .onChange(of: batchManager.currentIndex) { oldValue, newValue in
            // Wenn in Batch-Modus neues Bild ausgewählt wird
            if isBatchMode {
                loadCurrentBatchImage()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var currentDisplayImage: ImageData? {
        if isBatchMode {
            return batchManager.currentImage?.imageData
        } else {
            return imageData
        }
    }
    
    private func loadImage(from url: URL) {
        imageData = ImageService.loadImage(from: url)
        
        if let imageData = imageData {
            // MCU-Größe für JPEG bestimmen
            if imageData.format == .jpeg {
                imageData.mcuSize = JPEGService.detectMCUSize(for: url)
            }
            
            // Initiale Crop-Box berechnen
            updateCropBoxForNewImage()
        }
    }
    
    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .heic, .png, .tiff]
        panel.allowsMultipleSelection = isBatchMode
        
        if panel.runModal() == .OK {
            if isBatchMode {
                loadBatchImages(from: panel.urls)
            } else if let url = panel.url {
                loadImage(from: url)
            }
        }
    }
    
    private func loadBatchImages(from urls: [URL]) {
        let imageDatas = urls.compactMap { ImageService.loadImage(from: $0) }
        
        // MCU-Größe für JPEGs bestimmen
        for (index, url) in urls.enumerated() {
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
        
        // Lade Crop-Settings aus BatchItem
        if let settings = currentItem.cropSettings {
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
            updateCropBoxForNewImage()
        }
    }
    
    private func syncBatchAndSingleMode() {
        if isBatchMode {
            // Von Single zu Batch: Aktuelles Bild in Batch übernehmen
            if let imageData = imageData {
                batchManager.addImages([imageData])
                loadCurrentBatchImage()
            }
        } else {
            // Von Batch zu Single: Aktuelles Batch-Bild übernehmen
            if let currentItem = batchManager.currentImage {
                imageData = currentItem.imageData
                if let settings = currentItem.cropSettings {
                    cropBox = settings.cropBox
                    targetRatio = settings.targetRatio
                    cropMode = settings.mode
                }
            }
        }
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
        
        // In Batch-Modus: Settings im BatchManager speichern
        if isBatchMode, let currentItem = batchManager.currentImage {
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
    
    private func createCropSettings() -> CropSettings {
        guard let imageData = imageData else {
            return CropSettings(
                cropBox: .zero,
                targetRatio: effectiveTargetRatio,
                mode: cropMode,
                originalRatio: "unknown"
            )
        }
        
        return CropSettings(
            cropBox: cropBox,
            targetRatio: effectiveTargetRatio,
            mode: cropMode,
            originalRatio: imageData.aspectRatioString,
            mcuSize: imageData.mcuSize
        )
    }
    
    private func switchToCustomRatio() {
        // Berechne Custom-Ratio aus aktueller Crop-Box
        let ratio = calculateImageAspectRatio(size: cropBox.size)
        customWidth = String(ratio.width)
        customHeight = String(ratio.height)
        targetRatio = .custom(width: ratio.width, height: ratio.height)
    }
}

/// Drag & Drop Delegate für einzelne Bilder
struct ImageDropDelegate: DropDelegate {
    let onDrop: (URL) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        // Versuche URLs aus dem Drop zu extrahieren
        guard let itemProvider = info.itemProviders(for: [.fileURL]).first else {
            return false
        }
        
        itemProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("Fehler beim Laden: \(error)")
                    return
                }
                
                if let urlData = urlData as? Data {
                    // Versuche URL aus Data zu erstellen
                    let url = NSURL(absoluteURLWithDataRepresentation: urlData, relativeTo: nil) as URL
                    onDrop(url)
                } else if let url = urlData as? URL {
                    onDrop(url)
                }
            }
        }
        
        return true
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.fileURL])
    }
}

/// Drag & Drop Delegate für Batch-Modus (mehrere Bilder)
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

