//
//  BatchProcessingView.swift
//  PhotoCropper
//
//  Batch-Processing für mehrere Bilder
//

import SwiftUI
import UniformTypeIdentifiers

struct BatchProcessingView: View {
    @Binding var isPresented: Bool
    @State private var imageURLs: [URL] = []
    @State private var processedImages: [ImageData] = []
    @State private var currentIndex: Int = 0
    @State private var targetRatio: AspectRatio = .ratio16_9
    @State private var cropMode: CropMode = .mcuSensitive
    @State private var applyToAll: Bool = false
    @State private var isProcessing: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("BATCH-PROCESSING")
                .font(.headline)
            
            if !imageURLs.isEmpty {
                HStack {
                    Text("\(currentIndex + 1) von \(imageURLs.count)")
                    ProgressView(value: Double(currentIndex), total: Double(imageURLs.count))
                        .frame(width: 200)
                }
                
                if currentIndex < processedImages.count {
                    let currentImage = processedImages[currentIndex]
                    
                    // Bild-Vorschau
                    if let image = currentImage.image {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 300)
                    }
                    
                    // Crop-Einstellungen (vereinfacht für Batch)
                    VStack {
                        Picker("Zielformat", selection: $targetRatio) {
                            Text("16:9").tag(AspectRatio.ratio16_9)
                            Text("1:1").tag(AspectRatio.ratio1_1)
                        }
                        
                        Toggle("Auf alle Bilder anwenden", isOn: $applyToAll)
                    }
                    
                    HStack {
                        Button("Überspringen") {
                            nextImage()
                        }
                        
                        Spacer()
                        
                        Button("Verarbeiten") {
                            processCurrentImage()
                        }
                        .disabled(isProcessing)
                    }
                }
            } else {
                Button("Bilder auswählen...") {
                    selectImages()
                }
            }
            
            HStack {
                Button("Abbrechen") {
                    isPresented = false
                }
                
                Spacer()
                
                Button("Alle verarbeiten") {
                    processAll()
                }
                .disabled(imageURLs.isEmpty || isProcessing)
            }
        }
        .padding()
        .frame(width: 600, height: 500)
    }
    
    private func selectImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .heic, .png, .tiff]
        panel.allowsMultipleSelection = true
        
        if panel.runModal() == .OK {
            imageURLs = panel.urls
            processedImages = ImageService.loadImages(from: imageURLs)
            currentIndex = 0
        }
    }
    
    private func processCurrentImage() {
        guard currentIndex < processedImages.count else { return }
        
        isProcessing = true
        
        let imageData = processedImages[currentIndex]
        
        // Crop-Box berechnen
        let cropSize = targetRatio.calculateCropSize(for: imageData.pixelSize)
        let position = targetRatio.calculateDefaultPosition(
            for: imageData.pixelSize,
            cropSize: cropSize
        )
        let cropBox = CGRect(origin: position, size: cropSize)
        
        // Metadaten speichern
        let result = MetadataService.saveCropMetadata(
            imageURL: imageData.url,
            cropBox: cropBox,
            imageSize: imageData.pixelSize,
            targetRatio: targetRatio,
            mode: cropMode,
            originalRatio: imageData.aspectRatioString
        )
        
        if case .failure(let error) = result {
            print("Fehler beim Verarbeiten von \(imageData.url.lastPathComponent): \(error)")
        }
        
        isProcessing = false
        nextImage()
    }
    
    private func nextImage() {
        if currentIndex < processedImages.count - 1 {
            currentIndex += 1
        } else {
            // Fertig
            isPresented = false
        }
    }
    
    private func processAll() {
        isProcessing = true
        
        for imageData in processedImages {
            let cropSize = targetRatio.calculateCropSize(for: imageData.pixelSize)
            let position = targetRatio.calculateDefaultPosition(
                for: imageData.pixelSize,
                cropSize: cropSize
            )
            let cropBox = CGRect(origin: position, size: cropSize)
            
            let _ = MetadataService.saveCropMetadata(
                imageURL: imageData.url,
                cropBox: cropBox,
                imageSize: imageData.pixelSize,
                targetRatio: targetRatio,
                mode: cropMode,
                originalRatio: imageData.aspectRatioString
            )
        }
        
        isProcessing = false
        isPresented = false
    }
}

