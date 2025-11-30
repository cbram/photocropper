//
//  NSImage+Extensions.swift
//  PhotoCropper
//
//  Extensions for NSImage manipulation
//

import AppKit

// MARK: - Image Resizing

extension NSImage {
    
    /// Creates a resized copy of the image
    ///
    /// The image is scaled proportionally to fit within the target size while
    /// maintaining aspect ratio. High-quality interpolation is used.
    ///
    /// - Parameter targetSize: Maximum size for the resized image
    /// - Returns: A new resized NSImage
    ///
    /// - Note: The actual size may be smaller than `targetSize` if the aspect
    ///   ratio requires it. The image is never stretched or distorted.
    ///
    /// Example:
    /// ```swift
    /// let thumbnail = originalImage.resized(to: CGSize(width: 100, height: 100))
    /// ```
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
        
        // Use high-quality interpolation for better thumbnails
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

