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
    @State private var showMCUGrid: Bool = false
    @State private var compositionOverlay: CompositionOverlay = .none
    @State private var showCompositionOverlay: Bool = false
    @State private var customWidth: String = "16"
    @State private var customHeight: String = "9"
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
            // Batch-Liste (immer sichtbar)
            BatchImageListView(batchManager: batchManager)
                .onDrop(of: [.fileURL], delegate: BatchDropDelegate(batchManager: batchManager, onDrop: { urls in
                    loadBatchImages(from: urls)
                }))
            
            // Canvas-Bereich
            VStack {
                // Top Navigation
                HStack {
                    Text("PhotoCropper")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
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
                        showMCUGrid: showMCUGrid && !showCompositionOverlay,
                        mcuSize: displayImageData.mcuSize ?? CGSize(width: 8, height: 8),
                        compositionOverlay: showCompositionOverlay ? compositionOverlay : .none,
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
                                    Text("Bilder hier ablegen")
                                        .foregroundColor(.secondary)
                                    Text("oder Dateien öffnen")
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
            
            // Controls-Panel (30%)
            VStack {
                ControlsView(
                    targetRatio: $targetRatio,
                    cropMode: $cropMode,
                    showMCUGrid: $showMCUGrid,
                    compositionOverlay: $compositionOverlay,
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
                
                InfoPanel(imageData: currentDisplayImage)
                
                Spacer()
            }
            .frame(width: 300)
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
        customWidth = String(ratio.width)
        customHeight = String(ratio.height)
        targetRatio = .custom(width: ratio.width, height: ratio.height)
    }
    
    private func toggleCompositionOverlay() {
        print("🎯 toggleCompositionOverlay aufgerufen")
        print("   compositionOverlay: \(compositionOverlay)")
        print("   showCompositionOverlay VORHER: \(showCompositionOverlay)")
        
        if compositionOverlay != .none {
            showCompositionOverlay.toggle()
            print("   showCompositionOverlay NACHHER: \(showCompositionOverlay)")
        } else {
            print("   ⚠️ compositionOverlay ist .none - Toggle wird ignoriert")
        }
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

