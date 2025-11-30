//
//  BatchImageManager.swift
//  PhotoCropper
//
//  Manages multiple images for batch processing workflow
//

import Foundation
import SwiftUI
import Combine

// MARK: - Batch Image Manager

/// Manager for batch processing of multiple images
///
/// This class coordinates the batch processing workflow, managing a collection of
/// images, tracking the current selection, and providing methods for navigation
/// and status management.
///
/// Example usage:
/// ```swift
/// let manager = BatchImageManager()
/// manager.addImages(imageDatas)
/// manager.selectImage(at: 0)
/// manager.updateCurrentCropSettings(newSettings)
/// manager.markCurrentAsReadyAndNext()
/// ```
class BatchImageManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Array of all images in the batch
    @Published var images: [BatchImageItem] = []
    
    /// Index of the currently selected image
    @Published var currentIndex: Int = 0
    
    /// Indicates whether batch processing is in progress
    @Published var isProcessing: Bool = false
    
    // MARK: - Computed Properties
    
    /// The currently selected image item, if any
    var currentImage: BatchImageItem? {
        guard isValidIndex(currentIndex) else { return nil }
        return images[currentIndex]
    }
    
    /// Indicates whether any images are loaded
    var hasImages: Bool {
        !images.isEmpty
    }
    
    /// Indicates whether all images are ready for export
    ///
    /// An image is considered ready if its status is `.ready` or `.exported`.
    var allReady: Bool {
        !images.isEmpty && images.allSatisfy { $0.isReadyForExport }
    }
    
    /// Number of images ready for export
    var readyCount: Int {
        images.filter { $0.isReadyForExport }.count
    }
    
    /// Total number of images in the batch
    var totalCount: Int {
        images.count
    }
    
    /// Progress as a percentage (0.0 to 1.0)
    var progress: Double {
        guard !images.isEmpty else { return 0.0 }
        return Double(readyCount) / Double(totalCount)
    }
    
    // MARK: - Image Management
    
    /// Adds new images to the batch
    ///
    /// - Parameter imageDatas: Array of image data to add
    ///
    /// - Note: If this is the first set of images, the first image is automatically selected.
    func addImages(_ imageDatas: [ImageData]) {
        let newItems = imageDatas.map { BatchImageItem(imageData: $0) }
        let wasEmpty = images.isEmpty
        
        images.append(contentsOf: newItems)
        
        // If this was the first batch, select the first image
        if wasEmpty && !images.isEmpty {
            selectImage(at: 0)
        }
        
        print("📥 Added \(newItems.count) images to batch (total: \(images.count))")
    }
    
    /// Removes an image from the batch
    ///
    /// - Parameter index: Index of the image to remove
    ///
    /// - Note: If the removed image was selected, the selection is adjusted to
    ///   remain valid. The current index may change after removal.
    func removeImage(at index: Int) {
        guard isValidIndex(index) else {
            print("⚠️ Cannot remove image at invalid index \(index)")
            return
        }
        
        let filename = images[index].filename
        images.remove(at: index)
        
        // Adjust current index if necessary
        if currentIndex >= images.count {
            currentIndex = max(0, images.count - 1)
        }
        
        print("🗑️ Removed image: \(filename) (remaining: \(images.count))")
    }
    
    /// Removes all images from the batch
    func clear() {
        let count = images.count
        images.removeAll()
        currentIndex = 0
        
        print("🗑️ Cleared all images (removed: \(count))")
    }
    
    // MARK: - Navigation
    
    /// Selects an image at the specified index
    ///
    /// - Parameter index: Index of the image to select
    ///
    /// - Note: Updates status of the previously selected image to `.ready` if it
    ///   was `.editing`. Sets the newly selected image status to `.editing` if
    ///   it was `.pending`.
    func selectImage(at index: Int) {
        guard isValidIndex(index) else {
            print("⚠️ Cannot select image at invalid index \(index)")
            return
        }
        
        // Update status of previously selected image
        if let current = currentImage, current.status == .editing {
            current.status = .ready
        }
        
        currentIndex = index
        
        // Update status of newly selected image
        if let current = currentImage, current.status == .pending {
            current.status = .editing
        }
        
        print("👉 Selected image \(index + 1)/\(images.count): \(currentImage?.filename ?? "unknown")")
    }
    
    /// Navigates to the next image in the batch
    ///
    /// - Returns: `true` if navigation was successful, `false` if already at the last image
    @discardableResult
    func nextImage() -> Bool {
        guard currentIndex < images.count - 1 else {
            print("ℹ️ Already at last image")
            return false
        }
        
        selectImage(at: currentIndex + 1)
        return true
    }
    
    /// Navigates to the previous image in the batch
    ///
    /// - Returns: `true` if navigation was successful, `false` if already at the first image
    @discardableResult
    func previousImage() -> Bool {
        guard currentIndex > 0 else {
            print("ℹ️ Already at first image")
            return false
        }
        
        selectImage(at: currentIndex - 1)
        return true
    }
    
    /// Marks the current image as ready and navigates to the next image
    ///
    /// This is a convenience method commonly used in the workflow after finishing
    /// editing an image.
    func markCurrentAsReadyAndNext() {
        if let current = currentImage {
            current.status = .ready
            print("✅ Marked as ready: \(current.filename)")
        }
        nextImage()
    }
    
    // MARK: - Crop Settings Management
    
    /// Updates the crop settings for the currently selected image
    ///
    /// - Parameter settings: New crop settings to apply
    func updateCurrentCropSettings(_ settings: CropSettings) {
        guard let current = currentImage else {
            print("⚠️ Cannot update crop settings: no image selected")
            return
        }
        
        current.cropSettings = settings
    }
    
    // MARK: - Validation
    
    /// Checks if an index is valid for the current images array
    ///
    /// - Parameter index: Index to validate
    /// - Returns: `true` if the index is within bounds
    private func isValidIndex(_ index: Int) -> Bool {
        return index >= 0 && index < images.count
    }
}
