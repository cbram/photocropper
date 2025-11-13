//
//  FileManager+Extensions.swift
//  PhotoCropper
//
//  FileManager-Hilfsfunktionen
//

import Foundation

extension FileManager {
    /// Prüft ob eine Datei ein Bild ist
    func isImageFile(at url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "heic", "heif", "png", "tiff", "tif"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
}

