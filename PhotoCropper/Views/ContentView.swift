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
    @State private var imageData: ImageData?
    @State private var cropBox: CGRect = .zero
    @State private var targetRatio: AspectRatio = .ratio16_9
    @State private var cropMode: CropMode = .mcuSensitive
    @State private var autoFallback: Bool = true
    @State private var showMCUGrid: Bool = false
    @State private var customWidth: String = "16"
    @State private var customHeight: String = "9"
    @State private var showExportView: Bool = false
    @State private var batchImages: [ImageData] = []
    @State private var currentBatchIndex: Int = 0
    
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
            // Canvas-Bereich (70%)
            VStack {
                // Top Navigation
                HStack {
                    Button("← Zurück") {
                        // Navigation zurück
                    }
                    .disabled(true)
                    
                    Spacer()
                    
                    Button("Speichern") {
                        showExportView = true
                    }
                    .disabled(imageData == nil)
                    
                    Button("Hilfe") {
                        // Hilfe anzeigen
                    }
                }
                .padding()
                
                // Canvas
                if let imageData = imageData {
                    CanvasView(
                        image: Binding(
                            get: { imageData.image },
                            set: { _ in }
                        ),
                        cropBox: $cropBox,
                        imageSize: imageData.pixelSize,
                        showMCUGrid: showMCUGrid,
                        mcuSize: imageData.mcuSize ?? CGSize(width: 8, height: 8),
                        onCropBoxChanged: { newBox in
                            updateCropBox(newBox)
                        },
                        onRatioChanged: {
                            // Automatisch zu Custom-Ratio wechseln
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
                                VStack {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    Text("Bild hier ablegen oder Datei öffnen")
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                    .onDrop(of: [.image, .fileURL], delegate: ImageDropDelegate(onDrop: { url in
                        loadImage(from: url)
                    }))
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
                    imageSize: imageData?.pixelSize ?? .zero,
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
                    image: imageData?.image,
                    cropBox: cropBox,
                    imageSize: imageData?.pixelSize ?? .zero,
                    targetRatio: effectiveTargetRatio
                )
                
                Divider()
                
                InfoPanel(imageData: imageData)
                
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: openFile) {
                    Label("Öffnen", systemImage: "folder")
                }
            }
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
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            loadImage(from: url)
        }
    }
    
    private func updateCropBoxForNewImage() {
        guard let imageData = imageData else { return }
        
        let ratio = effectiveTargetRatio
        let cropSize = ratio.calculateCropSize(for: imageData.pixelSize)
        let position = ratio.calculateDefaultPosition(
            for: imageData.pixelSize,
            cropSize: cropSize
        )
        
        cropBox = CGRect(origin: position, size: cropSize)
        
        // MCU-Snapping falls aktiv
        if cropMode == .mcuSensitive, let mcuSize = imageData.mcuSize {
            cropBox = CropEngine.snapToMCUGrid(
                coordinates: cropBox,
                mcuSize: mcuSize,
                enabled: true
            )
        }
    }
    
    private func updateCropBox(_ newBox: CGRect) {
        var updatedBox = newBox
        
        // MCU-Snapping falls aktiv
        if cropMode == .mcuSensitive, let imageData = imageData, let mcuSize = imageData.mcuSize {
            updatedBox = CropEngine.snapToMCUGrid(
                coordinates: updatedBox,
                mcuSize: mcuSize,
                enabled: true
            )
        }
        
        // Validieren
        if let imageData = imageData {
            updatedBox = CropEngine.validateCropBox(updatedBox, imageSize: imageData.pixelSize)
        }
        
        cropBox = updatedBox
    }
    
    private func centerCropBox() {
        guard let imageData = imageData else { return }
        cropBox = CropEngine.centerCropBox(cropBox: cropBox, imageSize: imageData.pixelSize)
    }
    
    private func resetCropBox() {
        updateCropBoxForNewImage()
    }
    
    private func maximizeCropBox() {
        guard let imageData = imageData else { return }
        cropBox = CropEngine.maximizeCropBox(imageSize: imageData.pixelSize, targetRatio: effectiveTargetRatio)
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

/// Drag & Drop Delegate für Bilder
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

