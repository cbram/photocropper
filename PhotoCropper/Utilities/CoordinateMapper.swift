//
//  CoordinateMapper.swift
//  PhotoCropper
//
//  Helper functions for coordinate transformations
//

import Foundation
import CoreGraphics

/// Maps coordinates between different coordinate systems
///
/// This utility provides transformations between:
/// - **View coordinates**: Points in the UI/window coordinate system
/// - **Image coordinates**: Points in the actual image pixel coordinate system
///
/// ## Use Cases
/// - Converting mouse clicks to image pixel positions
/// - Rendering image annotations in the correct view positions
/// - Scaling crop boxes between display and image resolutions
///
/// ## Coordinate Systems
/// - **View**: UI/window coordinates (may be scaled for display)
/// - **Image**: Actual pixel coordinates in the source image
///
/// ## Usage Example
/// ```swift
/// let imagePoint = CoordinateMapper.viewToImage(
///     viewPoint: mouseLocation,
///     viewSize: canvasSize,
///     imageRect: displayRect,
///     imageSize: CGSize(width: 1920, height: 1080)
/// )
/// ```
struct CoordinateMapper {
    
    // MARK: - View to Image Transformations
    
    /// Converts view coordinates to image coordinates
    ///
    /// This transformation accounts for:
    /// - Image scaling (display size vs actual size)
    /// - Image positioning within the view
    /// - Coordinate system origins
    ///
    /// - Parameters:
    ///   - viewPoint: Point in view coordinate system
    ///   - viewSize: Size of the view container
    ///   - imageRect: Rectangle where image is displayed in the view
    ///   - imageSize: Actual size of the image in pixels
    /// - Returns: Corresponding point in image coordinate system
    ///
    /// - Precondition: `imageRect` dimensions must be non-zero
    static func viewToImage(
        viewPoint: CGPoint,
        viewSize: CGSize,
        imageRect: CGRect,
        imageSize: CGSize
    ) -> CGPoint {
        precondition(imageRect.width > 0 && imageRect.height > 0,
                     "Image rect must have non-zero dimensions")
        
        // Calculate scaling factors
        let scaleX = imageSize.width / imageRect.width
        let scaleY = imageSize.height / imageRect.height
        
        // Calculate relative position within image rect
        let relativeX = viewPoint.x - imageRect.origin.x
        let relativeY = viewPoint.y - imageRect.origin.y
        
        // Scale to image coordinates
        return CGPoint(
            x: relativeX * scaleX,
            y: relativeY * scaleY
        )
    }
    
    /// Converts view rectangle to image rectangle
    ///
    /// Convenience method for converting entire rectangles at once.
    ///
    /// - Parameters:
    ///   - viewRect: Rectangle in view coordinate system
    ///   - viewSize: Size of the view container
    ///   - imageRect: Rectangle where image is displayed in the view
    ///   - imageSize: Actual size of the image in pixels
    /// - Returns: Corresponding rectangle in image coordinate system
    static func viewRectToImage(
        viewRect: CGRect,
        viewSize: CGSize,
        imageRect: CGRect,
        imageSize: CGSize
    ) -> CGRect {
        let origin = viewToImage(
            viewPoint: viewRect.origin,
            viewSize: viewSize,
            imageRect: imageRect,
            imageSize: imageSize
        )
        
        let bottomRight = viewToImage(
            viewPoint: CGPoint(x: viewRect.maxX, y: viewRect.maxY),
            viewSize: viewSize,
            imageRect: imageRect,
            imageSize: imageSize
        )
        
        return CGRect(
            x: origin.x,
            y: origin.y,
            width: bottomRight.x - origin.x,
            height: bottomRight.y - origin.y
        )
    }
    
    // MARK: - Image to View Transformations
    
    /// Converts image coordinates to view coordinates
    ///
    /// This transformation accounts for:
    /// - Image scaling (actual size vs display size)
    /// - Image positioning within the view
    /// - Coordinate system origins
    ///
    /// - Parameters:
    ///   - imagePoint: Point in image coordinate system (pixels)
    ///   - imageRect: Rectangle where image is displayed in the view
    ///   - imageSize: Actual size of the image in pixels
    /// - Returns: Corresponding point in view coordinate system
    ///
    /// - Precondition: `imageSize` dimensions must be non-zero
    static func imageToView(
        imagePoint: CGPoint,
        imageRect: CGRect,
        imageSize: CGSize
    ) -> CGPoint {
        precondition(imageSize.width > 0 && imageSize.height > 0,
                     "Image size must have non-zero dimensions")
        
        // Calculate scaling factors
        let scaleX = imageRect.width / imageSize.width
        let scaleY = imageRect.height / imageSize.height
        
        // Scale and translate to view coordinates
        return CGPoint(
            x: imageRect.origin.x + imagePoint.x * scaleX,
            y: imageRect.origin.y + imagePoint.y * scaleY
        )
    }
    
    /// Converts image rectangle to view rectangle
    ///
    /// Convenience method for converting entire rectangles at once.
    ///
    /// - Parameters:
    ///   - imageRectInPixels: Rectangle in image coordinate system (pixels)
    ///   - imageRect: Rectangle where image is displayed in the view
    ///   - imageSize: Actual size of the image in pixels
    /// - Returns: Corresponding rectangle in view coordinate system
    static func imageRectToView(
        imageRectInPixels: CGRect,
        imageRect: CGRect,
        imageSize: CGSize
    ) -> CGRect {
        let origin = imageToView(
            imagePoint: imageRectInPixels.origin,
            imageRect: imageRect,
            imageSize: imageSize
        )
        
        let bottomRight = imageToView(
            imagePoint: CGPoint(x: imageRectInPixels.maxX, y: imageRectInPixels.maxY),
            imageRect: imageRect,
            imageSize: imageSize
        )
        
        return CGRect(
            x: origin.x,
            y: origin.y,
            width: bottomRight.x - origin.x,
            height: bottomRight.y - origin.y
        )
    }
    
    // MARK: - Validation
    
    /// Checks if a point is within valid image bounds
    ///
    /// - Parameters:
    ///   - point: Point to validate
    ///   - imageSize: Image dimensions
    /// - Returns: `true` if point is within image bounds, otherwise `false`
    static func isValidImagePoint(_ point: CGPoint, imageSize: CGSize) -> Bool {
        return point.x >= 0 &&
               point.y >= 0 &&
               point.x <= imageSize.width &&
               point.y <= imageSize.height
    }
    
    /// Clamps a point to image bounds
    ///
    /// - Parameters:
    ///   - point: Point to clamp
    ///   - imageSize: Image dimensions
    /// - Returns: Clamped point within image bounds
    static func clampToImageBounds(_ point: CGPoint, imageSize: CGSize) -> CGPoint {
        return CGPoint(
            x: max(0, min(point.x, imageSize.width)),
            y: max(0, min(point.y, imageSize.height))
        )
    }
}
