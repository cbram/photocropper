# PhotoCropper - Mac JPEG/HEIC Lossless Crop Tool

Native macOS SwiftUI-Anwendung für verlustfreies Cropping von JPEG/HEIC-Bildern mit Metadaten-Speicherung.

## Features

- ✅ Unterstützung für beliebige Bildformate (JPEG, HEIC, PNG, TIFF)
- ✅ Flexible Input-Ratios (3:2, 16:9, 1:1, 21:9, Hochkant, etc.)
- ✅ Zielformat-Auswahl: 16:9, 1:1, Benutzerdefiniert
- ✅ MCU-sensitives Cropping für JPEG (verlustfrei)
- ✅ Standard-Cropping als Fallback
- ✅ Interaktive GUI mit rotem Crop-Rahmen
- ✅ MCU-Grid-Visualisierung (optional)
- ✅ Metadaten-Speicherung (EXIF DefaultCropOrigin/Size + Custom XMP Tags)
- ✅ Automatische Dateinamen-Generierung aus EXIF-Datum
- ✅ Batch-Processing für mehrere Bilder
- ✅ HEIC zu JPEG Konvertierung (optional)

## Voraussetzungen

- macOS 12.0 oder höher
- Xcode 14.0 oder höher
- jpegtran (für MCU-sensitives Cropping): `brew install jpeg-turbo`

## Installation

1. Projekt öffnen:
```bash
open PhotoCropper.xcodeproj
```

2. In Xcode:
   - Product → Build (⌘B)
   - Product → Run (⌘R)

## Verwendung

1. **Bild öffnen**: Datei → Öffnen oder Drag & Drop
2. **Zielformat wählen**: 16:9, 1:1 oder Benutzerdefiniert
3. **Cropping-Modus**: MCU-sensitiv (Lossless) oder Standard
4. **Crop-Box anpassen**: Interaktiv per Maus ziehen
5. **Speichern**: Metadaten werden in EXIF/XMP gespeichert

## Projektstruktur

```
PhotoCropper/
├── Models/
│   ├── AspectRatio.swift
│   ├── CropSettings.swift
│   ├── ImageData.swift
│   └── ExifData.swift
├── Views/
│   ├── ContentView.swift
│   ├── CanvasView.swift
│   ├── ControlsView.swift
│   ├── PreviewView.swift
│   ├── ExportView.swift
│   ├── InfoPanel.swift
│   └── BatchProcessingView.swift
├── Services/
│   ├── ImageService.swift
│   ├── JPEGService.swift
│   ├── MetadataService.swift
│   ├── CropEngine.swift
│   └── ExifDateParser.swift
└── Utilities/
    ├── FileManager+Extensions.swift
    └── CoordinateMapper.swift
```

## Technische Details

- **SwiftUI + AppKit Hybrid**: Canvas verwendet AppKit für bessere Performance
- **jpegtran Integration**: Shell-Command für verlustfreies JPEG-Cropping
- **ImageIO Framework**: Für Metadaten-Manipulation
- **EXIF/XMP**: Metadaten werden in beiden Formaten gespeichert

## Bekannte Einschränkungen

- MCU-Größen-Erkennung ist vereinfacht (Standard: 8x8)
- Für präzise MCU-Erkennung wäre libjpeg direkt nötig
- HEIC unterstützt kein MCU-Cropping (nur Standard)

## Lizenz

MIT License

