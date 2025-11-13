//
//  JPEGService.swift
//  PhotoCropper
//
//  Handhabt JPEG-spezifische Operationen: MCU-Parsing, jpegtran-Wrapper
//

import Foundation
import AppKit
import CoreGraphics

/// Service für JPEG-Operationen mit MCU-Unterstützung
class JPEGService {
    
    /// Prüft ob jpegtran verfügbar ist
    static func isJPEGTranAvailable() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["jpegtran"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    /// Extrahiert MCU-Größe aus JPEG (vereinfacht: typischerweise 8x8, 8x16 oder 16x16)
    /// Für präzise MCU-Erkennung müsste man libjpeg direkt nutzen
    static func detectMCUSize(for imageURL: URL) -> CGSize? {
        // Vereinfachte Implementierung: Standard-MCU-Größen
        // In einer vollständigen Implementierung würde man libjpeg nutzen
        // um die tatsächliche MCU-Größe zu bestimmen
        
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        
        let _ = imageRef.width
        let _ = imageRef.height
        
        // Typische MCU-Größen: 8x8, 8x16, 16x8, 16x16
        // Für Chroma-Subsampling: 8x8 für Luma, 8x16 oder 16x16 für Chroma
        
        // Standard: 8x8 MCU-Blöcke (häufigste Variante)
        // Dies ist eine Vereinfachung - für präzise Erkennung bräuchte man libjpeg
        return CGSize(width: 8, height: 8)
    }
    
    /// Snappt Koordinaten auf nächste MCU-Grenze
    static func snapToMCUGrid(coordinates: CGRect, mcuSize: CGSize) -> CGRect {
        let snappedX = floor(coordinates.origin.x / mcuSize.width) * mcuSize.width
        let snappedY = floor(coordinates.origin.y / mcuSize.height) * mcuSize.height
        let snappedWidth = ceil(coordinates.width / mcuSize.width) * mcuSize.width
        let snappedHeight = ceil(coordinates.height / mcuSize.height) * mcuSize.height
        
        return CGRect(
            x: snappedX,
            y: snappedY,
            width: snappedWidth,
            height: snappedHeight
        )
    }
    
    /// Führt verlustfreies Cropping mit jpegtran durch
    static func cropLossless(imageURL: URL, cropRect: CGRect, outputURL: URL) -> Result<Void, Error> {
        guard isJPEGTranAvailable() else {
            return .failure(JPEGServiceError.jpegtranNotAvailable)
        }
        
        // jpegtran erwartet Integer-Koordinaten
        let x = Int(cropRect.origin.x)
        let y = Int(cropRect.origin.y)
        let w = Int(cropRect.width)
        let h = Int(cropRect.height)
        
        // jpegtran-Pfad finden (verschiedene Installationsorte)
        let possiblePaths = [
            "/opt/homebrew/bin/jpegtran",  // Homebrew auf Apple Silicon
            "/usr/local/bin/jpegtran",      // Homebrew auf Intel
            "/usr/bin/jpegtran",            // System-Installation
            "/opt/local/bin/jpegtran"       // MacPorts
        ]
        
        guard let jpegtranPath = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            print("❌ jpegtran nicht gefunden in:", possiblePaths)
            return .failure(JPEGServiceError.jpegtranNotAvailable)
        }
        
        print("✅ jpegtran gefunden in: \(jpegtranPath)")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: jpegtranPath)
        
        // jpegtran -crop WxH+X+Y input.jpg output.jpg
        task.arguments = [
            "-crop", "\(w)x\(h)+\(x)+\(y)",
            "-copy", "all",  // Alle Metadaten kopieren
            imageURL.path,
            "-outfile", outputURL.path
        ]
        
        print("🔧 jpegtran Befehl: \(jpegtranPath) -crop \(w)x\(h)+\(x)+\(y) -copy all \(imageURL.path) -outfile \(outputURL.path)")
        
        let errorPipe = Pipe()
        task.standardError = errorPipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                return .success(())
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return .failure(JPEGServiceError.cropFailed(errorString))
            }
        } catch {
            return .failure(error)
        }
    }
    
    /// Prüft ob eine Datei ein JPEG ist
    static func isJPEG(url: URL) -> Bool {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let uti = CGImageSourceGetType(imageSource) else {
            return false
        }
        return uti as String == "public.jpeg"
    }
}

/// JPEG-Service-Fehler
enum JPEGServiceError: LocalizedError {
    case jpegtranNotAvailable
    case cropFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .jpegtranNotAvailable:
            return "jpegtran ist nicht installiert. Bitte installieren Sie es mit: brew install jpeg-turbo"
        case .cropFailed(let message):
            return "Cropping fehlgeschlagen: \(message)"
        }
    }
}

