//
//  BatchImageItem.swift
//  PhotoCropper
//
//  Represents a single image in a batch processing workflow
//

import Foundation
import SwiftUI
import Combine

// MARK: - Batch Item Status

/// Status of a batch image item in the processing workflow
///
/// The status transitions follow this typical flow:
/// ```
/// pending -> editing -> ready -> exported
///                   └-> error
/// ```
enum BatchItemStatus: Equatable {
    /// Image has not been processed yet
    case pending
    
    /// Image is currently being edited
    case editing
    
    /// Image has been cropped and is ready for export
    case ready
    
    /// Image has been successfully exported
    case exported
    
    /// An error occurred during processing
    case error(String)
    
    // MARK: - Status Properties
    
    /// SF Symbol name for status icon
    var iconName: String {
        switch self {
        case .pending:
            return "circle"
        case .editing:
            return "circle.fill"
        case .ready:
            return "checkmark.circle"
        case .exported:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }
    
    /// Color associated with this status
    var color: Color {
        switch self {
        case .pending:
            return .gray
        case .editing:
            return .blue
        case .ready:
            return .orange
        case .exported:
            return .green
        case .error:
            return .red
        }
    }
    
    /// Indicates whether the item is ready for export
    var isReadyForExport: Bool {
        switch self {
        case .ready, .exported:
            return true
        default:
            return false
        }
    }
}

// MARK: - Batch Image Item

/// Represents a single image in a batch processing workflow
///
/// Each item tracks the image data, crop settings, processing status, and thumbnail.
/// The item manages its own thumbnail generation and status transitions.
///
/// Example:
/// ```swift
/// let item = BatchImageItem(imageData: imageData)
/// item.cropSettings = newSettings
/// item.status = .ready
/// ```
class BatchImageItem: Identifiable, ObservableObject {
    
    // MARK: - Properties
    
    /// Unique identifier for the item
    let id = UUID()
    
    /// The image data being processed
    @Published var imageData: ImageData
    
    /// Current crop settings for this image
    @Published var cropSettings: CropSettings?
    
    /// Current processing status
    @Published var status: BatchItemStatus = .pending
    
    /// Generated thumbnail for list display
    @Published var thumbnail: NSImage?
    
    // MARK: - Initialization
    
    /// Creates a new batch image item with default crop settings
    ///
    /// - Parameter imageData: The image data to process
    ///
    /// - Note: Default crop settings use 16:9 aspect ratio and MCU-sensitive mode.
    ///   Thumbnail generation begins automatically on a background thread.
    init(imageData: ImageData) {
        self.imageData = imageData
        
        // Set up default crop settings with 16:9 aspect ratio
        let cropSize = AspectRatio.ratio16_9.calculateCropSize(for: imageData.pixelSize)
        let position = AspectRatio.ratio16_9.calculateDefaultPosition(
            for: imageData.pixelSize,
            cropSize: cropSize
        )
        
        self.cropSettings = CropSettings(
            cropBox: CGRect(origin: position, size: cropSize),
            targetRatio: .ratio16_9,
            mode: .mcuSensitive,
            originalRatio: imageData.aspectRatioString
        )
        
        // Start thumbnail generation
        generateThumbnail()
    }
    
    // MARK: - Thumbnail Generation
    
    /// Generates a thumbnail asynchronously on a background thread
    ///
    /// The thumbnail is created at 100×100 points, maintaining aspect ratio.
    /// Uses ImageService for thumbnail generation with proper error handling.
    private func generateThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Use ImageService for thumbnail generation
            if let thumbnail = ImageService.generateThumbnail(
                from: self.imageData.image,
                maxSize: CGSize(width: 100, height: 100)
            ) {
                DispatchQueue.main.async {
                    self.thumbnail = thumbnail
                }
            } else {
                print("⚠️ Failed to generate thumbnail for \(self.imageData.url.lastPathComponent)")
            }
        }
    }
    
    // MARK: - Convenience Properties
    
    /// SF Symbol icon name based on current status
    var statusIcon: String {
        status.iconName
    }
    
    /// Color based on current status
    var statusColor: Color {
        status.color
    }
    
    /// Indicates whether this item is ready for export
    var isReadyForExport: Bool {
        status.isReadyForExport
    }
    
    /// Filename of the image
    var filename: String {
        imageData.url.lastPathComponent
    }
}

