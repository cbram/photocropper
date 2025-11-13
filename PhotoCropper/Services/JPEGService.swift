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
        // Prüfe bekannte Installationsorte
        let possiblePaths = [
            "/opt/homebrew/bin/jpegtran",  // Homebrew auf Apple Silicon
            "/usr/local/bin/jpegtran",      // Homebrew auf Intel
            "/usr/bin/jpegtran",            // System-Installation
            "/opt/local/bin/jpegtran"       // MacPorts
        ]
        
        let available = possiblePaths.contains { FileManager.default.fileExists(atPath: $0) }
        print("🔍 jpegtran verfügbar: \(available)")
        return available
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
        print("📍 Input:  \(imageURL.path)")
        print("📍 Output: \(outputURL.path)")
        print("📐 Crop: \(w)x\(h)+\(x)+\(y)")
        
        // NEUER ANSATZ: Rufe jpegtran DIREKT auf (nicht über Shell!)
        // Das vermeidet alle Quoting-Probleme
        
        let cropArg = "\(w)x\(h)+\(x)+\(y)"
        
        print("🔧 Direkter Aufruf: \(jpegtranPath) -crop \(cropArg) -copy all [input] -outfile [output]")
        print("⏳ Starte posix_spawn...")
        
        // posix_spawn benötigt C-Arrays - DIREKT jpegtran aufrufen
        var pid: pid_t = 0
        
        // Debug: Zeige alle Argumente
        let argStrings = [
            jpegtranPath,
            "-crop",
            cropArg,
            "-copy",
            "all",
            imageURL.path,
            "-outfile",
            outputURL.path
        ]
        
        print("📋 argv-Liste:")
        for (index, arg) in argStrings.enumerated() {
            print("  argv[\(index)] = \"\(arg)\"")
        }
        
        let argv: [UnsafeMutablePointer<CChar>?] = [
            strdup(jpegtranPath),              // argv[0] = Executable selbst
            strdup("-crop"),                   // argv[1]
            strdup(cropArg),                   // argv[2]
            strdup("-copy"),                   // argv[3]
            strdup("all"),                     // argv[4]
            strdup(imageURL.path),             // argv[5] = Input file
            strdup("-outfile"),                // argv[6]
            strdup(outputURL.path),            // argv[7] = Output file
            nil                                // argv[8] = NULL terminator
        ]
        
        let envp: [UnsafeMutablePointer<CChar>?] = [
            strdup("PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"),
            nil
        ]
        
        print("🚀 Rufe posix_spawn auf...")
        let status = posix_spawn(&pid, jpegtranPath, nil, nil, argv, envp)
        print("📊 posix_spawn status: \(status), pid: \(pid)")
        
        // Cleanup
        argv.forEach { if let ptr = $0 { free(ptr) } }
        envp.forEach { if let ptr = $0 { free(ptr) } }
        
        if status == 0 {
            print("⏱️ Warte auf Prozess-Ende (pid: \(pid))...")
            // Warte auf Prozess-Ende
            var exitStatus: Int32 = 0
            let waitResult = waitpid(pid, &exitStatus, 0)
            print("📊 waitpid result: \(waitResult), exitStatus: \(exitStatus)")
            
            let actualExit = (exitStatus >> 8) & 0xFF  // Extrahiere echten Exit-Code
            print("📊 Extrahierter Exit-Code: \(actualExit)")
            
            if actualExit == 0 {
                print("✅ jpegtran erfolgreich ausgeführt")
                
                // Prüfe ob Output-Datei existiert
                let fileExists = FileManager.default.fileExists(atPath: outputURL.path)
                print("📁 Output-Datei existiert: \(fileExists)")
                
                if fileExists {
                    let fileSize = try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64
                    print("📏 Output-Datei Größe: \(fileSize ?? 0) bytes")
                    return .success(())
                } else {
                    print("❌ Output-Datei wurde nicht erstellt")
                    return .failure(JPEGServiceError.cropFailed("Output-Datei wurde nicht erstellt"))
                }
            } else {
                print("❌ jpegtran fehlgeschlagen mit exit code: \(actualExit)")
                return .failure(JPEGServiceError.cropFailed("jpegtran exit code: \(actualExit)"))
            }
        } else {
            print("❌ posix_spawn fehlgeschlagen mit status: \(status)")
            let errorStr = String(cString: strerror(status))
            print("❌ Error: \(errorStr)")
            return .failure(JPEGServiceError.cropFailed("posix_spawn failed: \(status) - \(errorStr)"))
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

