//
//  CanvasView.swift
//  PhotoCropper
//
//  AppKit-basierte Canvas-View für interaktive Crop-Box mit roter Umrandung
//

import SwiftUI
import AppKit

/// AppKit-View für Canvas mit Crop-Box
class CropCanvasView: NSView {
    var image: NSImage?
    var cropBox: CGRect = .zero
    var imageSize: CGSize = .zero
    var showMCUGrid: Bool = false
    var mcuSize: CGSize = CGSize(width: 8, height: 8)
    
    var onCropBoxChanged: ((CGRect) -> Void)?
    var onRatioChanged: (() -> Void)?  // Callback wenn Ratio manuell geändert wird
    
    private var isDragging = false
    private var dragHandle: DragHandle?
    private var dragStartPoint: CGPoint = .zero
    private var dragStartCropBox: CGRect = .zero
    
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
        
        // Bild skalieren und zentrieren
        let imageRect = calculateImageRect()
        context?.draw(image.cgImage(forProposedRect: nil, context: nil, hints: nil)!, in: imageRect)
        
        // Overlay für ausgeschnittene Bereiche
        drawOverlay(in: imageRect, context: context!)
        
        // MCU-Grid zeichnen (optional)
        if showMCUGrid {
            drawMCUGrid(in: imageRect, context: context!)
        }
        
        // Crop-Box zeichnen (roter Rahmen)
        drawCropBox(in: imageRect, context: context!)
        
        // Handles NACH allem anderen zeichnen (damit sie immer sichtbar sind)
        let scaleX = imageRect.width / imageSize.width
        let scaleY = imageRect.height / imageSize.height
        let cropRect = CGRect(
            x: imageRect.origin.x + cropBox.origin.x * scaleX,
            y: imageRect.origin.y + (imageSize.height - cropBox.origin.y - cropBox.height) * scaleY,
            width: cropBox.width * scaleX,
            height: cropBox.height * scaleY
        )
        print("🖼️ draw(): Rufe drawHandles auf mit cropRect: \(cropRect)")
        drawHandles(in: cropRect, context: context!)
        
        // Info-Text zeichnen
        drawInfoText(in: imageRect, context: context!)
    }
    
    private func calculateImageRect() -> CGRect {
        guard let image = image else { return .zero }
        
        let imageAspect = image.size.width / image.size.height
        let viewAspect = bounds.width / bounds.height
        
        var imageRect: CGRect
        
        if imageAspect > viewAspect {
            // Bild ist breiter → Höhe bestimmt Größe
            let height = bounds.height
            let width = height * imageAspect
            imageRect = CGRect(
                x: (bounds.width - width) / 2,
                y: 0,
                width: width,
                height: height
            )
        } else {
            // Bild ist höher → Breite bestimmt Größe
            let width = bounds.width
            let height = width / imageAspect
            imageRect = CGRect(
                x: 0,
                y: (bounds.height - height) / 2,
                width: width,
                height: height
            )
        }
        
        return imageRect
    }
    
    private func drawOverlay(in imageRect: CGRect, context: CGContext) {
        // Crop-Box in View-Koordinaten umrechnen
        let scaleX = imageRect.width / imageSize.width
        let scaleY = imageRect.height / imageSize.height
        // Y-Achse invertieren für NSView-Koordinatensystem
        let cropRect = CGRect(
            x: imageRect.origin.x + cropBox.origin.x * scaleX,
            y: imageRect.origin.y + (imageSize.height - cropBox.origin.y - cropBox.height) * scaleY,
            width: cropBox.width * scaleX,
            height: cropBox.height * scaleY
        )
        
        // Dunkelgraues Overlay über ausgeschnittene Bereiche
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
    
    private func drawCropBox(in imageRect: CGRect, context: CGContext) {
        let scaleX = imageRect.width / imageSize.width
        let scaleY = imageRect.height / imageSize.height
        // Y-Achse invertieren für NSView-Koordinatensystem
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
        
        // Weißer Hintergrund für bessere Lesbarkeit
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
        let handleSize: CGFloat = 18  // Noch größer für bessere Sichtbarkeit
        let handleColor = NSColor.white
        let handleBorderColor = NSColor.red
        
        print("🎯 === DRAW HANDLES DEBUG ===")
        print("   View Bounds: \(bounds)")
        print("   Crop Rect:   \(cropRect)")
        
        // Sicherstellen dass Crop-Rect innerhalb der View-Bounds ist
        let visibleRect = bounds.intersection(cropRect)
        print("   Visible Intersection: \(visibleRect)")
        guard !visibleRect.isEmpty else {
            print("   ⚠️ ABBRUCH: Crop-Rect nicht innerhalb Bounds!")
            return
        }
        
        // Eckpunkte (auf VISIBLE RECT, nicht auf vollständiger Crop-Rect!)
        // Dies stellt sicher, dass Handles immer innerhalb der View sind
        let corners = [
            CGPoint(x: visibleRect.minX, y: visibleRect.minY),  // Unten links
            CGPoint(x: visibleRect.maxX, y: visibleRect.minY),  // Unten rechts
            CGPoint(x: visibleRect.minX, y: visibleRect.maxY),  // Oben links
            CGPoint(x: visibleRect.maxX, y: visibleRect.maxY)   // Oben rechts
        ]
        print("   Ecken (auf visibleRect): \(corners)")
        
        // Kantenpunkte (Mitte, auf VISIBLE RECT)
        let edges = [
            CGPoint(x: visibleRect.midX, y: visibleRect.minY),  // Unten
            CGPoint(x: visibleRect.midX, y: visibleRect.maxY),  // Oben
            CGPoint(x: visibleRect.minX, y: visibleRect.midY),  // Links
            CGPoint(x: visibleRect.maxX, y: visibleRect.midY)   // Rechts
        ]
        
        // Zeichne Ecken-Handles (größer)
        var cornersDrawn = 0
        for (index, point) in corners.enumerated() {
            let handleRect = CGRect(
                x: point.x - handleSize / 2,
                y: point.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            
            let intersects = bounds.intersects(handleRect)
            print("   Ecke \(index): \(point) → Rect: \(handleRect), intersects: \(intersects)")
            
            // Nur zeichnen wenn innerhalb der View-Bounds
            if intersects {
                // Weißer Hintergrund
                context.setFillColor(handleColor.cgColor)
                context.fill(handleRect)
                
                // Roter Rahmen
                context.setStrokeColor(handleBorderColor.cgColor)
                context.setLineWidth(2.0)
                context.stroke(handleRect)
                cornersDrawn += 1
            }
        }
        print("   ✅ Ecken gezeichnet: \(cornersDrawn)/4")
        
        // Zeichne Kanten-Handles (rechteckig, gut sichtbar)
        let edgeHandleWidth: CGFloat = 30  // Breiter
        let edgeHandleHeight: CGFloat = 10  // Höher
        
        var edgesDrawn = 0
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
                // Links/Rechts: schmaler, höher
                handleRect = CGRect(
                    x: point.x - edgeHandleHeight / 2,
                    y: point.y - edgeHandleWidth / 2,
                    width: edgeHandleHeight,
                    height: edgeHandleWidth
                )
            }
            
            let intersects = bounds.intersects(handleRect)
            let edgeName = ["Unten", "Oben", "Links", "Rechts"][index]
            print("   Kante \(edgeName): \(point) → Rect: \(handleRect), intersects: \(intersects)")
            
            // Nur zeichnen wenn innerhalb der View-Bounds
            if intersects {
                // Weißer Hintergrund
                context.setFillColor(handleColor.cgColor)
                context.fill(handleRect)
                
                // Roter Rahmen
                context.setStrokeColor(handleBorderColor.cgColor)
                context.setLineWidth(2.0)
                context.stroke(handleRect)
                edgesDrawn += 1
            }
        }
        print("   ✅ Kanten gezeichnet: \(edgesDrawn)/4")
        print("🎯 === DRAW HANDLES ENDE ===\n")
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
    
    override func mouseDown(with event: NSEvent) {
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
        
        // Bild-Rect für Koordinaten-Umrechnung
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
            newCropBox.origin.x += delta.x * scaleX
            newCropBox.origin.y -= delta.y * scaleY
            newCropBox.size.width -= delta.x * scaleX
            newCropBox.size.height += delta.y * scaleY
            
        case .topRight:
            newCropBox.origin.y -= delta.y * scaleY
            newCropBox.size.width += delta.x * scaleX
            newCropBox.size.height += delta.y * scaleY
            
        case .bottomLeft:
            newCropBox.origin.x += delta.x * scaleX
            newCropBox.size.width -= delta.x * scaleX
            newCropBox.size.height -= delta.y * scaleY
            
        case .bottomRight:
            newCropBox.size.width += delta.x * scaleX
            newCropBox.size.height -= delta.y * scaleY
            
        case .top:
            // Obere Kante verschieben
            newCropBox.origin.y -= delta.y * scaleY
            newCropBox.size.height += delta.y * scaleY
            
        case .bottom:
            // Untere Kante verschieben
            newCropBox.size.height -= delta.y * scaleY
            
        case .left:
            // Linke Kante verschieben
            newCropBox.origin.x += delta.x * scaleX
            newCropBox.size.width -= delta.x * scaleX
            
        case .right:
            // Rechte Kante verschieben
            newCropBox.size.width += delta.x * scaleX
        }
        
        // Validieren und begrenzen
        newCropBox = CropEngine.validateCropBox(newCropBox, imageSize: imageSize)
        
        // Bei Kanten/Ecken-Drag: Signal für Custom-Ratio senden
        if handle != .center {
            onRatioChanged?()
        }
        
        cropBox = newCropBox
        onCropBoxChanged?(cropBox)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        isDragging = false
        dragHandle = nil
    }
    
    private func handleAtPoint(_ point: CGPoint) -> DragHandle? {
        let imageRect = calculateImageRect()
        let scaleX = imageRect.width / imageSize.width
        let scaleY = imageRect.height / imageSize.height
        // Y-Achse invertieren für NSView-Koordinatensystem
        let cropRect = CGRect(
            x: imageRect.origin.x + cropBox.origin.x * scaleX,
            y: imageRect.origin.y + (imageSize.height - cropBox.origin.y - cropBox.height) * scaleY,
            width: cropBox.width * scaleX,
            height: cropBox.height * scaleY
        )
        
        // WICHTIG: Verwende visibleRect für Hit-Testing (wie beim Zeichnen!)
        let visibleRect = bounds.intersection(cropRect)
        guard !visibleRect.isEmpty else { return nil }
        
        let handleSize: CGFloat = 18  // Größer für bessere Erkennung
        let edgeSize: CGFloat = 20  // Größerer Bereich für Kanten
        
        // Ecken prüfen (Priorität vor Kanten) - auf VISIBLE RECT
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
        
        // Kanten prüfen (mit größerem Bereich) - auf VISIBLE RECT
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
        
        // Mitte prüfen (auf vollständiger cropRect für Drag-Funktionalität)
        if cropRect.contains(point) {
            return .center
        }
        
        return nil
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // Cursor-Updates für Drag-Handles könnten hier implementiert werden
    }
}

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = y - point.y
        return sqrt(dx * dx + dy * dy)
    }
}

/// SwiftUI-Wrapper für CropCanvasView
struct CanvasView: NSViewRepresentable {
    @Binding var image: NSImage?
    @Binding var cropBox: CGRect
    var imageSize: CGSize
    var showMCUGrid: Bool
    var mcuSize: CGSize
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
        nsView.onCropBoxChanged = onCropBoxChanged
        nsView.onRatioChanged = onRatioChanged
        nsView.needsDisplay = true
    }
}

