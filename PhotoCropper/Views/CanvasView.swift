//
//  CanvasView.swift
//  PhotoCropper
//
//  AppKit-based canvas view for interactive crop box with red border
//

import SwiftUI
import AppKit

/// AppKit view for canvas with crop box
class CropCanvasView: NSView {
    var image: NSImage?
    var cropBox: CGRect = .zero
    var imageSize: CGSize = .zero
    var showMCUGrid: Bool = false
    var mcuSize: CGSize = CGSize(width: 8, height: 8)
    var compositionOverlay: CompositionOverlay? = nil
    
    var onCropBoxChanged: ((CGRect) -> Void)?
    var onRatioChanged: (() -> Void)?  // Callback when ratio is manually changed
    var targetAspectRatio: CGFloat?  // Optional: desired aspect ratio (width/height)
    
    private var isDragging = false
    private var dragHandle: DragHandle?
    private var dragStartPoint: CGPoint = .zero
    private var dragStartCropBox: CGRect = .zero
    private var lastDisplayUpdate: Date = Date()
    private let displayThrottleInterval: TimeInterval = 0.016  // ~60 FPS
    
    enum DragHandle {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
        case center
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let image = image else { return }
        
        let context = NSGraphicsContext.current?.cgContext
        context?.clear(bounds)
        
        // Scale and center image
        let imageRect = calculateImageRect()
        context?.draw(image.cgImage(forProposedRect: nil, context: nil, hints: nil)!, in: imageRect)
        
        // Overlay for cropped areas
        drawOverlay(in: imageRect, context: context!)
        
        // Calculate crop rect (needed for multiple things)
        let scaleX = imageRect.width / imageSize.width
        let scaleY = imageRect.height / imageSize.height
        let cropRect = CGRect(
            x: imageRect.origin.x + cropBox.origin.x * scaleX,
            y: imageRect.origin.y + (imageSize.height - cropBox.origin.y - cropBox.height) * scaleY,
            width: cropBox.width * scaleX,
            height: cropBox.height * scaleY
        )
        
        // MCU-Grid zeichnen (optional)
        if showMCUGrid {
            drawMCUGrid(in: imageRect, context: context!)
        }
        
        // Crop-Box zeichnen (roter Rahmen)
        drawCropBox(in: imageRect, context: context!)
        
        // Draw composition overlay (optional) - INSIDE the crop box
        if let overlay = compositionOverlay {
            drawCompositionOverlay(overlay, in: cropRect, context: context!)
        }
        
        // Draw handles AFTER everything else (so they're always visible)
        drawHandles(in: cropRect, context: context!)
        
        // Info-Text zeichnen
        drawInfoText(in: imageRect, context: context!)
    }
    
    private func calculateImageRect() -> CGRect {
        guard image != nil else { return .zero }
        
        // IMPORTANT: use imageSize (pixels), not image.size (points)!
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = bounds.width / bounds.height
        
        var imageRect: CGRect
        
        if imageAspect > viewAspect {
            // Image is wider → width determines size (fill width)
            let width = bounds.width
            let height = width / imageAspect
            imageRect = CGRect(
                x: 0,
                y: (bounds.height - height) / 2,
                width: width,
                height: height
            )
        } else {
            // Image is taller → height determines size (fill height)
            let height = bounds.height
            let width = height * imageAspect
            imageRect = CGRect(
                x: (bounds.width - width) / 2,
                y: 0,
                width: width,
                height: height
            )
        }
        
        return imageRect
    }
    
    private func drawOverlay(in imageRect: CGRect, context: CGContext) {
        // Convert crop box to view coordinates
        let scaleX = imageRect.width / imageSize.width
        let scaleY = imageRect.height / imageSize.height
        // Invert Y-axis for NSView coordinate system
        let cropRect = CGRect(
            x: imageRect.origin.x + cropBox.origin.x * scaleX,
            y: imageRect.origin.y + (imageSize.height - cropBox.origin.y - cropBox.height) * scaleY,
            width: cropBox.width * scaleX,
            height: cropBox.height * scaleY
        )
        
        // Dark gray overlay over cropped areas
        context.setFillColor(NSColor.black.withAlphaComponent(0.6).cgColor)
        
        // Oben
        context.fill(CGRect(x: imageRect.minX, y: cropRect.maxY, width: imageRect.width, height: imageRect.maxY - cropRect.maxY))
        // Unten
        context.fill(CGRect(x: imageRect.minX, y: imageRect.minY, width: imageRect.width, height: cropRect.minY - imageRect.minY))
        // Links
        context.fill(CGRect(x: imageRect.minX, y: cropRect.minY, width: cropRect.minX - imageRect.minX, height: cropRect.height))
        // Rechts
        context.fill(CGRect(x: cropRect.maxX, y: cropRect.minY, width: imageRect.maxX - cropRect.maxX, height: cropRect.height))
    }
    
    private func drawMCUGrid(in imageRect: CGRect, context: CGContext) {
        let scaleX = imageRect.width / imageSize.width
        let scaleY = imageRect.height / imageSize.height
        
        context.setStrokeColor(NSColor.lightGray.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(0.5)
        
        // Vertikale Linien
        var x: CGFloat = 0
        while x < imageSize.width {
            let viewX = imageRect.origin.x + x * scaleX
            context.move(to: CGPoint(x: viewX, y: imageRect.minY))
            context.addLine(to: CGPoint(x: viewX, y: imageRect.maxY))
            context.strokePath()
            x += mcuSize.width
        }
        
        // Horizontale Linien
        var y: CGFloat = 0
        while y < imageSize.height {
            let viewY = imageRect.origin.y + y * scaleY
            context.move(to: CGPoint(x: imageRect.minX, y: viewY))
            context.addLine(to: CGPoint(x: imageRect.maxX, y: viewY))
            context.strokePath()
            y += mcuSize.height
        }
    }
    
    private func drawCompositionOverlay(_ overlay: CompositionOverlay, in imageRect: CGRect, context: CGContext) {
        // Light gray for better visibility
        context.setStrokeColor(NSColor.lightGray.withAlphaComponent(0.7).cgColor)
        context.setLineWidth(1.5)
        
        switch overlay {
        case .ruleOfThirds:
            drawRuleOfThirds(in: imageRect, context: context)
            
        case .goldenRatio:
            drawGoldenRatio(in: imageRect, context: context)
            
        case .fibonacciTopLeft:
            drawFibonacciSpiral(in: imageRect, context: context, orientation: .topLeft)
            
        case .fibonacciTopRight:
            drawFibonacciSpiral(in: imageRect, context: context, orientation: .topRight)
            
        case .fibonacciBottomLeft:
            drawFibonacciSpiral(in: imageRect, context: context, orientation: .bottomLeft)
            
        case .fibonacciBottomRight:
            drawFibonacciSpiral(in: imageRect, context: context, orientation: .bottomRight)
        }
    }
    
    private func drawRuleOfThirds(in rect: CGRect, context: CGContext) {
        let width = rect.width
        let height = rect.height
        
        // Vertical lines at 1/3 and 2/3
        let x1 = rect.minX + width / 3
        let x2 = rect.minX + 2 * width / 3
        
        context.move(to: CGPoint(x: x1, y: rect.minY))
        context.addLine(to: CGPoint(x: x1, y: rect.maxY))
        context.strokePath()
        
        context.move(to: CGPoint(x: x2, y: rect.minY))
        context.addLine(to: CGPoint(x: x2, y: rect.maxY))
        context.strokePath()
        
        // Horizontal lines at 1/3 and 2/3
        let y1 = rect.minY + height / 3
        let y2 = rect.minY + 2 * height / 3
        
        context.move(to: CGPoint(x: rect.minX, y: y1))
        context.addLine(to: CGPoint(x: rect.maxX, y: y1))
        context.strokePath()
        
        context.move(to: CGPoint(x: rect.minX, y: y2))
        context.addLine(to: CGPoint(x: rect.maxX, y: y2))
        context.strokePath()
    }
    
    private func drawGoldenRatio(in rect: CGRect, context: CGContext) {
        let width = rect.width
        let height = rect.height
        let goldenRatio: CGFloat = 0.618
        
        // Horizontal lines at ~38.2% and ~61.8%
        let y1 = rect.minY + height * (1 - goldenRatio)
        let y2 = rect.minY + height * goldenRatio
        
        context.move(to: CGPoint(x: rect.minX, y: y1))
        context.addLine(to: CGPoint(x: rect.maxX, y: y1))
        context.strokePath()
        
        context.move(to: CGPoint(x: rect.minX, y: y2))
        context.addLine(to: CGPoint(x: rect.maxX, y: y2))
        context.strokePath()
        
        // Vertical lines at ~38.2% and ~61.8%
        let x1 = rect.minX + width * (1 - goldenRatio)
        let x2 = rect.minX + width * goldenRatio
        
        context.move(to: CGPoint(x: x1, y: rect.minY))
        context.addLine(to: CGPoint(x: x1, y: rect.maxY))
        context.strokePath()
        
        context.move(to: CGPoint(x: x2, y: rect.minY))
        context.addLine(to: CGPoint(x: x2, y: rect.maxY))
        context.strokePath()
    }
    
    enum FibonacciOrientation {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    // Hilfsfunktion: Fibonacci-Zahl berechnen
    private func fibonacci(_ n: Int) -> CGFloat {
        if n <= 1 { return 1 }
        var a: CGFloat = 1
        var b: CGFloat = 1
        for _ in 2...n {
            let z = a
            a += b
            b = z
        }
        return a
    }
    
    private func drawFibonacciSpiral(in rect: CGRect, context: CGContext, orientation: FibonacciOrientation) {
        let fibValues: [CGFloat] = [1, 1, 2, 3, 5, 8, 13, 21]
        let canonicalSize = CGSize(
            width: fibValues[fibValues.count - 1] + fibValues[fibValues.count - 2], // 34 Fibonacci-Einheiten
            height: fibValues[fibValues.count - 1] // 21 Fibonacci-Einheiten
        )
        
        let nucleusPercentX: CGFloat = 0.243
        let nucleusPercentY: CGFloat = 0.286
        let canonicalNucleus = CGPoint(
            x: canonicalSize.width * nucleusPercentX,
            y: canonicalSize.height * nucleusPercentY
        )
        
        print("🔴 === FIBONACCI SPIRAL DEBUG ===")
        print("🔴 Crop-Rect: \(rect)")
        print("🔴 Orientierung: \(orientation)")
        print("🌀 Canonical Size: \(canonicalSize)")
        print("🎯 Canonical Nucleus: \(canonicalNucleus)")
        
        let spiralPath = buildFibonacciSpiralPath(
            fibValues: fibValues,
            nucleus: canonicalNucleus,
            clockwise: true
        )
        
        let canonicalBounds = spiralPath.boundingBoxOfPath
        
        var transform = fibonacciTransform(
            for: rect,
            canonicalSize: canonicalSize,
            canonicalBounds: canonicalBounds,
            orientation: orientation
        )
        
        guard let transformedPath = spiralPath.copy(using: &transform) else {
            print("⚠️ Konnte Fibonacci-Pfad nicht transformieren.")
            return
        }
        
        let bounding = transformedPath.boundingBoxOfPath
        print("📦 Spiral BoundingBox: \(bounding)")
        
        context.setStrokeColor(NSColor.lightGray.withAlphaComponent(0.7).cgColor)
        context.setLineWidth(1.5)
        context.addPath(transformedPath)
        context.strokePath()
        
        // Debug: Nucleus-Punkt zeichnen
        let nucleusPoint = canonicalNucleus.applying(transform)
        context.setFillColor(NSColor.red.cgColor)
        let centerDot = CGRect(x: nucleusPoint.x - 4, y: nucleusPoint.y - 4, width: 8, height: 8)
        context.fillEllipse(in: centerDot)
    }

    private func buildFibonacciSpiralPath(fibValues: [CGFloat], nucleus: CGPoint, clockwise: Bool) -> CGPath {
        let path = CGMutablePath()
        var center = nucleus
        var angle: CGFloat = 0
        let turn: CGFloat = clockwise ? -(.pi / 2) : (.pi / 2)
        let moveRotation: CGFloat = clockwise ? .pi : -.pi
        let sweep: CGFloat = clockwise ? -(.pi / 2) : (.pi / 2)
        
        for index in 0..<fibValues.count {
            if index >= 1 {
                angle += turn
            }
            
            if index >= 2 {
                let offset = fibValues[index - 2]
                let moveAngle = angle + moveRotation
                center.x += offset * cos(moveAngle)
                center.y += offset * sin(moveAngle)
            }
            
            let radius = fibValues[index]
            let endAngle = angle + sweep
            path.addArc(center: center, radius: radius, startAngle: angle, endAngle: endAngle, clockwise: clockwise)
        }
        
        return path
    }
    
    private func fibonacciTransform(for rect: CGRect, canonicalSize: CGSize, canonicalBounds: CGRect, orientation: FibonacciOrientation) -> CGAffineTransform {
        let orientationTransform: CGAffineTransform
        switch orientation {
        case .bottomLeft:
            orientationTransform = .identity
        case .bottomRight:
            orientationTransform = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: canonicalSize.width, ty: 0)
        case .topLeft:
            orientationTransform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: canonicalSize.height)
        case .topRight:
            orientationTransform = CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: canonicalSize.width, ty: canonicalSize.height)
        }
        
        let orientedBounds = canonicalBounds.applying(orientationTransform)
        let scaleX = rect.width / orientedBounds.width
        let scaleY = rect.height / orientedBounds.height
        let scaleTransform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        
        let translateTransform = CGAffineTransform(
            translationX: rect.minX - orientedBounds.minX * scaleX,
            y: rect.minY - orientedBounds.minY * scaleY
        )
        
        let transform = orientationTransform
            .concatenating(scaleTransform)
            .concatenating(translateTransform)
        return transform
    }
    
    private func drawCropBox(in imageRect: CGRect, context: CGContext) {
        let scaleX = imageRect.width / imageSize.width
        let scaleY = imageRect.height / imageSize.height
        
        // Invert Y-axis for NSView coordinate system
        let cropRect = CGRect(
            x: imageRect.origin.x + cropBox.origin.x * scaleX,
            y: imageRect.origin.y + (imageSize.height - cropBox.origin.y - cropBox.height) * scaleY,
            width: cropBox.width * scaleX,
            height: cropBox.height * scaleY
        )
        
        // Roter Rahmen (2-3px Dicke)
        context.setStrokeColor(NSColor.red.cgColor)
        context.setLineWidth(3.0)
        context.stroke(cropRect)
        
        // Ratio-Label auf Crop-Box
        let ratio = cropBox.width / cropBox.height
        let labelText = String(format: "\(Int(cropBox.width))×\(Int(cropBox.height)) (%.2f:1)", ratio)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.red,
            .font: NSFont.boldSystemFont(ofSize: 14),
            .backgroundColor: NSColor.white.withAlphaComponent(0.8)
        ]
        let attributedString = NSAttributedString(string: labelText, attributes: attributes)
        let labelSize = attributedString.size()
        let labelRect = CGRect(
            x: cropRect.midX - labelSize.width / 2,
            y: cropRect.minY - labelSize.height - 5,
            width: labelSize.width + 10,
            height: labelSize.height + 4
        )
        
        // White background for better readability
        context.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        context.fill(labelRect)
        
        attributedString.draw(in: CGRect(
            x: labelRect.origin.x + 5,
            y: labelRect.origin.y + 2,
            width: labelRect.width - 10,
            height: labelRect.height - 4
        ))
    }
    
    private func drawHandles(in cropRect: CGRect, context: CGContext) {
        let handleSize: CGFloat = 24  // Even larger for better grabbing
        let handleColor = NSColor.white
        let handleBorderColor = NSColor.red
        
        // Ensure crop rect is within view bounds
        let visibleRect = bounds.intersection(cropRect)
        guard !visibleRect.isEmpty else { return }
        
        // Corner points (on VISIBLE RECT, not on complete crop rect!)
        // This ensures handles are always within the view
        let corners = [
            CGPoint(x: visibleRect.minX, y: visibleRect.minY),  // Unten links
            CGPoint(x: visibleRect.maxX, y: visibleRect.minY),  // Unten rechts
            CGPoint(x: visibleRect.minX, y: visibleRect.maxY),  // Oben links
            CGPoint(x: visibleRect.maxX, y: visibleRect.maxY)   // Oben rechts
        ]
        
        // Kantenpunkte (Mitte, auf VISIBLE RECT)
        let edges = [
            CGPoint(x: visibleRect.midX, y: visibleRect.minY),  // Unten
            CGPoint(x: visibleRect.midX, y: visibleRect.maxY),  // Oben
            CGPoint(x: visibleRect.minX, y: visibleRect.midY),  // Links
            CGPoint(x: visibleRect.maxX, y: visibleRect.midY)   // Rechts
        ]
        
        // Draw corner handles (larger)
        for point in corners {
            let handleRect = CGRect(
                x: point.x - handleSize / 2,
                y: point.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            
            // Only draw if within view bounds
            if bounds.intersects(handleRect) {
                // White background
                context.setFillColor(handleColor.cgColor)
                context.fill(handleRect)
                
                // Roter Rahmen
                context.setStrokeColor(handleBorderColor.cgColor)
                context.setLineWidth(2.0)
                context.stroke(handleRect)
            }
        }
        
        // Zeichne Kanten-Handles (rechteckig, gut sichtbar)
        let edgeHandleWidth: CGFloat = 40  // Even wider for better grabbing
        let edgeHandleHeight: CGFloat = 14  // Even taller
        
        for (index, point) in edges.enumerated() {
            var handleRect: CGRect
            
            if index < 2 {
                // Oben/Unten: breiter, flacher
                handleRect = CGRect(
                    x: point.x - edgeHandleWidth / 2,
                    y: point.y - edgeHandleHeight / 2,
                    width: edgeHandleWidth,
                    height: edgeHandleHeight
                )
            } else {
                // Left/Right: narrower, taller
                handleRect = CGRect(
                    x: point.x - edgeHandleHeight / 2,
                    y: point.y - edgeHandleWidth / 2,
                    width: edgeHandleHeight,
                    height: edgeHandleWidth
                )
            }
            
            // Only draw if within view bounds
            if bounds.intersects(handleRect) {
                // White background
                context.setFillColor(handleColor.cgColor)
                context.fill(handleRect)
                
                // Roter Rahmen
                context.setStrokeColor(handleBorderColor.cgColor)
                context.setLineWidth(2.0)
                context.stroke(handleRect)
            }
        }
    }
    
    private func drawInfoText(in imageRect: CGRect, context: CGContext) {
        let infoText = "X: \(Int(cropBox.origin.x)), Y: \(Int(cropBox.origin.y)), W: \(Int(cropBox.width)), H: \(Int(cropBox.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 12),
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]
        let attributedString = NSAttributedString(string: infoText, attributes: attributes)
        let labelRect = CGRect(x: 10, y: bounds.height - 30, width: bounds.width - 20, height: 20)
        attributedString.draw(in: labelRect)
    }
    
    /// Lets the canvas take keyboard focus, so clicking the image ends text editing
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let location = convert(event.locationInWindow, from: nil)
        dragHandle = handleAtPoint(location)
        
        if dragHandle != nil {
            isDragging = true
            dragStartPoint = location
            dragStartCropBox = cropBox
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let handle = dragHandle else { return }
        
        let location = convert(event.locationInWindow, from: nil)
        let delta = CGPoint(x: location.x - dragStartPoint.x, y: location.y - dragStartPoint.y)
        
        // Image rect for coordinate conversion
        let imageRect = calculateImageRect()
        let scaleX = imageSize.width / imageRect.width
        let scaleY = imageSize.height / imageRect.height
        
        var newCropBox = dragStartCropBox
        
        switch handle {
        case .center:
            // Gesamte Box verschieben (Y-Achse invertieren)
            newCropBox.origin.x += delta.x * scaleX
            newCropBox.origin.y -= delta.y * scaleY
            
        case .topLeft:
            if let aspectRatio = targetAspectRatio {
                // With aspect ratio: width leads
                newCropBox.origin.x += delta.x * scaleX
                newCropBox.size.width -= delta.x * scaleX
                newCropBox.size.height = newCropBox.size.width / aspectRatio
                newCropBox.origin.y = dragStartCropBox.maxY - newCropBox.size.height
            } else {
                // Without aspect ratio: free adjustment
                newCropBox.origin.x += delta.x * scaleX
                newCropBox.origin.y -= delta.y * scaleY
                newCropBox.size.width -= delta.x * scaleX
                newCropBox.size.height += delta.y * scaleY
            }
            
        case .topRight:
            if let aspectRatio = targetAspectRatio {
                // With aspect ratio: width leads
                newCropBox.size.width += delta.x * scaleX
                newCropBox.size.height = newCropBox.size.width / aspectRatio
                newCropBox.origin.y = dragStartCropBox.maxY - newCropBox.size.height
            } else {
                // Without aspect ratio: free adjustment
                newCropBox.origin.y -= delta.y * scaleY
                newCropBox.size.width += delta.x * scaleX
                newCropBox.size.height += delta.y * scaleY
            }
            
        case .bottomLeft:
            if let aspectRatio = targetAspectRatio {
                // With aspect ratio: width leads
                newCropBox.origin.x += delta.x * scaleX
                newCropBox.size.width -= delta.x * scaleX
                newCropBox.size.height = newCropBox.size.width / aspectRatio
            } else {
                // Without aspect ratio: free adjustment
                newCropBox.origin.x += delta.x * scaleX
                newCropBox.size.width -= delta.x * scaleX
                newCropBox.size.height -= delta.y * scaleY
            }
            
        case .bottomRight:
            if let aspectRatio = targetAspectRatio {
                // With aspect ratio: width leads
                newCropBox.size.width += delta.x * scaleX
                newCropBox.size.height = newCropBox.size.width / aspectRatio
            } else {
                // Without aspect ratio: free adjustment
                newCropBox.size.width += delta.x * scaleX
                newCropBox.size.height -= delta.y * scaleY
            }
            
        case .top:
            // Obere Kante verschieben
            newCropBox.origin.y -= delta.y * scaleY
            newCropBox.size.height += delta.y * scaleY
            // Aspect Ratio beibehalten wenn gesetzt
            if let aspectRatio = targetAspectRatio {
                newCropBox.size.width = newCropBox.size.height * aspectRatio
            }
            
        case .bottom:
            // Untere Kante verschieben
            newCropBox.size.height -= delta.y * scaleY
            // Aspect Ratio beibehalten wenn gesetzt
            if let aspectRatio = targetAspectRatio {
                newCropBox.size.width = newCropBox.size.height * aspectRatio
            }
            
        case .left:
            // Linke Kante verschieben
            newCropBox.origin.x += delta.x * scaleX
            newCropBox.size.width -= delta.x * scaleX
            // Aspect Ratio beibehalten wenn gesetzt
            if let aspectRatio = targetAspectRatio {
                newCropBox.size.height = newCropBox.size.width / aspectRatio
            }
            
        case .right:
            // Rechte Kante verschieben
            newCropBox.size.width += delta.x * scaleX
            // Aspect Ratio beibehalten wenn gesetzt
            if let aspectRatio = targetAspectRatio {
                newCropBox.size.height = newCropBox.size.width / aspectRatio
            }
        }
        
        // Validate and constrain
        newCropBox = CropEngine.validateCropBox(newCropBox, imageSize: imageSize)
        
        // IMPORTANT: Correct aspect ratio again after validation
        // If the box hits image boundaries, we need to adjust the other dimension
        if let aspectRatio = targetAspectRatio {
            // Check which dimension is at the limit
            let widthAtLimit = newCropBox.size.width >= imageSize.width - 1
            let heightAtLimit = newCropBox.size.height >= imageSize.height - 1
            
            if widthAtLimit && !heightAtLimit {
                // Width is at limit -> adjust height
                newCropBox.size.height = min(newCropBox.size.width / aspectRatio, imageSize.height)
            } else if heightAtLimit && !widthAtLimit {
                // Height is at limit -> adjust width
                newCropBox.size.width = min(newCropBox.size.height * aspectRatio, imageSize.width)
            } else if widthAtLimit && heightAtLimit {
                // Both at limit -> aspect ratio cannot be maintained, smaller dimension wins
                let maxWidthForHeight = newCropBox.size.height * aspectRatio
                let maxHeightForWidth = newCropBox.size.width / aspectRatio
                
                if maxWidthForHeight <= imageSize.width {
                    newCropBox.size.width = maxWidthForHeight
                } else {
                    newCropBox.size.height = maxHeightForWidth
                }
            }
            
            // Finale Validierung
            newCropBox = CropEngine.validateCropBox(newCropBox, imageSize: imageSize)
        }
        
        // For edge/corner drag: send signal for custom ratio
        // BUT ONLY if no targetAspectRatio is set (otherwise we would break the lock!)
        if handle != .center && targetAspectRatio == nil {
            onRatioChanged?()
        }
        
        cropBox = newCropBox
        
        // Display ALWAYS update immediately (no throttling for visual representation)
        needsDisplay = true
        
        // Only throttle callback (for performance with slider updates etc.)
        let now = Date()
        if now.timeIntervalSince(lastDisplayUpdate) >= displayThrottleInterval {
            onCropBoxChanged?(cropBox)
            lastDisplayUpdate = now
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        isDragging = false
        dragHandle = nil
        // Final display update AND callback after drag end
        onCropBoxChanged?(cropBox)
        needsDisplay = true
    }
    
    private func handleAtPoint(_ point: CGPoint) -> DragHandle? {
        let imageRect = calculateImageRect()
        let scaleX = imageRect.width / imageSize.width
        let scaleY = imageRect.height / imageSize.height
        // Invert Y-axis for NSView coordinate system
        let cropRect = CGRect(
            x: imageRect.origin.x + cropBox.origin.x * scaleX,
            y: imageRect.origin.y + (imageSize.height - cropBox.origin.y - cropBox.height) * scaleY,
            width: cropBox.width * scaleX,
            height: cropBox.height * scaleY
        )
        
        // IMPORTANT: Use visibleRect for hit testing (as in drawing!)
        let visibleRect = bounds.intersection(cropRect)
        guard !visibleRect.isEmpty else { return nil }
        
        let handleSize: CGFloat = 24  // Larger for better detection
        let edgeSize: CGFloat = 30  // Larger area for edges
        
        // Check corners (priority over edges) - on VISIBLE RECT
        let corners = [
            CGPoint(x: visibleRect.minX, y: visibleRect.minY),  // Unten links
            CGPoint(x: visibleRect.maxX, y: visibleRect.minY),  // Unten rechts
            CGPoint(x: visibleRect.minX, y: visibleRect.maxY),  // Oben links
            CGPoint(x: visibleRect.maxX, y: visibleRect.maxY)   // Oben rechts
        ]
        
        if point.distance(to: corners[0]) < handleSize {
            return .bottomLeft
        }
        if point.distance(to: corners[1]) < handleSize {
            return .bottomRight
        }
        if point.distance(to: corners[2]) < handleSize {
            return .topLeft
        }
        if point.distance(to: corners[3]) < handleSize {
            return .topRight
        }
        
        // Check edges (with larger area) - on VISIBLE RECT
        // Obere Kante
        if abs(point.y - visibleRect.maxY) < edgeSize && 
           point.x >= visibleRect.minX && point.x <= visibleRect.maxX {
            return .top
        }
        // Untere Kante
        if abs(point.y - visibleRect.minY) < edgeSize && 
           point.x >= visibleRect.minX && point.x <= visibleRect.maxX {
            return .bottom
        }
        // Linke Kante
        if abs(point.x - visibleRect.minX) < edgeSize && 
           point.y >= visibleRect.minY && point.y <= visibleRect.maxY {
            return .left
        }
        // Rechte Kante
        if abs(point.x - visibleRect.maxX) < edgeSize && 
           point.y >= visibleRect.minY && point.y <= visibleRect.maxY {
            return .right
        }
        
        // Check center (on complete cropRect for drag functionality)
        if cropRect.contains(point) {
            return .center
        }
        
        return nil
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // Cursor updates for drag handles could be implemented here
    }
}

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = y - point.y
        return sqrt(dx * dx + dy * dy)
    }
}

/// SwiftUI wrapper for CropCanvasView
struct CanvasView: NSViewRepresentable {
    @Binding var image: NSImage?
    @Binding var cropBox: CGRect
    var imageSize: CGSize
    var showMCUGrid: Bool
    var mcuSize: CGSize
    var compositionOverlay: CompositionOverlay?
    var targetAspectRatio: CGFloat?  // For aspect ratio lock during dragging
    var onCropBoxChanged: ((CGRect) -> Void)?
    var onRatioChanged: (() -> Void)?
    
    func makeNSView(context: Context) -> CropCanvasView {
        let view = CropCanvasView()
        view.onCropBoxChanged = onCropBoxChanged
        view.onRatioChanged = onRatioChanged
        return view
    }
    
    func updateNSView(_ nsView: CropCanvasView, context: Context) {
        nsView.image = image
        nsView.cropBox = cropBox
        nsView.imageSize = imageSize
        nsView.showMCUGrid = showMCUGrid
        nsView.mcuSize = mcuSize
        nsView.compositionOverlay = compositionOverlay
        nsView.targetAspectRatio = targetAspectRatio
        nsView.onCropBoxChanged = onCropBoxChanged
        nsView.onRatioChanged = onRatioChanged
        nsView.needsDisplay = true
    }
}

