//
//  BatchImageManager.swift
//  PhotoCropper
//
//  Verwaltet mehrere Bilder für Batch-Verarbeitung
//

import Foundation
import SwiftUI
import Combine

/// Repräsentiert ein Bild im Batch mit seinem Crop-Status
class BatchImageItem: Identifiable, ObservableObject {
    let id = UUID()
    @Published var imageData: ImageData
    @Published var cropSettings: CropSettings?
    @Published var status: BatchItemStatus = .pending
    @Published var thumbnail: NSImage?
    
    enum BatchItemStatus: Equatable {
        case pending        // Noch nicht bearbeitet
        case editing        // Gerade in Bearbeitung
        case ready          // Crop-Einstellungen fertig
        case exported       // Bereits exportiert
        case error(String)  // Fehler aufgetreten
    }
    
    init(imageData: ImageData) {
        self.imageData = imageData
        // Default Crop-Einstellungen
        let cropSize = AspectRatio.ratio16_9.calculateCropSize(for: imageData.pixelSize)
        let position = AspectRatio.ratio16_9.calculateDefaultPosition(for: imageData.pixelSize, cropSize: cropSize)
        
        self.cropSettings = CropSettings(
            cropBox: CGRect(origin: position, size: cropSize),
            targetRatio: .ratio16_9,
            mode: .mcuSensitive,
            originalRatio: imageData.aspectRatioString
        )
        
        // Thumbnail generieren
        generateThumbnail()
    }
    
    private func generateThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if let thumbnail = self.imageData.image?.resized(to: CGSize(width: 100, height: 100)) {
                DispatchQueue.main.async {
                    self.thumbnail = thumbnail
                }
            }
        }
    }
    
    var statusIcon: String {
        switch status {
        case .pending: return "circle"
        case .editing: return "circle.fill"
        case .ready: return "checkmark.circle"
        case .exported: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    var statusColor: Color {
        switch status {
        case .pending: return .gray
        case .editing: return .blue
        case .ready: return .orange
        case .exported: return .green
        case .error: return .red
        }
    }
}

/// Manager für Batch-Verarbeitung mehrerer Bilder
class BatchImageManager: ObservableObject {
    @Published var images: [BatchImageItem] = []
    @Published var currentIndex: Int = 0
    @Published var isProcessing: Bool = false
    
    var currentImage: BatchImageItem? {
        guard currentIndex >= 0 && currentIndex < images.count else { return nil }
        return images[currentIndex]
    }
    
    var hasImages: Bool {
        !images.isEmpty
    }
    
    var allReady: Bool {
        images.allSatisfy { item in
            if case .ready = item.status { return true }
            if case .exported = item.status { return true }
            return false
        }
    }
    
    var readyCount: Int {
        images.filter { item in
            if case .ready = item.status { return true }
            if case .exported = item.status { return true }
            return false
        }.count
    }
    
    /// Fügt neue Bilder hinzu
    func addImages(_ imageDatas: [ImageData]) {
        let newItems = imageDatas.map { BatchImageItem(imageData: $0) }
        images.append(contentsOf: newItems)
        
        // Wenn das erste Bild, setze es als aktuell
        if images.count == newItems.count {
            selectImage(at: 0)
        }
    }
    
    /// Wählt ein Bild aus der Liste
    func selectImage(at index: Int) {
        guard index >= 0 && index < images.count else { return }
        
        // Altes Bild Status aktualisieren
        if let current = currentImage, current.status == .editing {
            current.status = .ready
        }
        
        currentIndex = index
        
        // Neues Bild Status aktualisieren
        if let current = currentImage, current.status == .pending {
            current.status = .editing
        }
    }
    
    /// Geht zum nächsten Bild
    func nextImage() {
        if currentIndex < images.count - 1 {
            selectImage(at: currentIndex + 1)
        }
    }
    
    /// Geht zum vorherigen Bild
    func previousImage() {
        if currentIndex > 0 {
            selectImage(at: currentIndex - 1)
        }
    }
    
    /// Markiert aktuelles Bild als fertig und geht zum nächsten
    func markCurrentAsReadyAndNext() {
        if let current = currentImage {
            current.status = .ready
        }
        nextImage()
    }
    
    /// Aktualisiert Crop-Einstellungen für aktuelles Bild
    func updateCurrentCropSettings(_ settings: CropSettings) {
        currentImage?.cropSettings = settings
    }
    
    /// Entfernt ein Bild aus der Liste
    func removeImage(at index: Int) {
        guard index >= 0 && index < images.count else { return }
        images.remove(at: index)
        
        // Index anpassen wenn nötig
        if currentIndex >= images.count {
            currentIndex = max(0, images.count - 1)
        }
    }
    
    /// Löscht alle Bilder
    func clear() {
        images.removeAll()
        currentIndex = 0
    }
}

// MARK: - NSImage Extension für Thumbnail-Generierung
extension NSImage {
    func resized(to targetSize: CGSize) -> NSImage {
        let sourceSize = self.size
        let widthRatio = targetSize.width / sourceSize.width
        let heightRatio = targetSize.height / sourceSize.height
        let scaleFactor = min(widthRatio, heightRatio)
        
        let scaledSize = CGSize(
            width: sourceSize.width * scaleFactor,
            height: sourceSize.height * scaleFactor
        )
        
        let image = NSImage(size: scaledSize)
        image.lockFocus()
        
        NSGraphicsContext.current?.imageInterpolation = .high
        self.draw(
            in: NSRect(origin: .zero, size: scaledSize),
            from: NSRect(origin: .zero, size: sourceSize),
            operation: .copy,
            fraction: 1.0
        )
        
        image.unlockFocus()
        return image
    }
}

