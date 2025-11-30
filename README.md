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
- ✅ **Automatisches Laden gespeicherter Crop-Koordinaten** - Bilder mit bereits gespeicherten Crop-Daten werden erkannt und die Crop-Box wird automatisch positioniert
- ✅ **Visuelle Kennzeichnung** - Bilder mit gespeicherten Crop-Metadaten werden in der Liste mit einem blauen Badge markiert
- ✅ Automatische Dateinamen-Generierung aus EXIF-Datum
- ✅ Batch-Processing für mehrere Bilder
- ✅ HEIC zu JPEG Konvertierung (optional)
- ✅ **Responsive UI** - Optimiert für verschiedene Bildschirmgrößen (min. 900×600 Pixel)

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

## App bauen und finden

### Option 1: In Xcode bauen

1. **Xcode öffnen** und das Projekt `PhotoCropper.xcodeproj` öffnen
2. **Product → Scheme → PhotoCropper** wählen
3. **Product → Destination → My Mac** wählen
4. **Release-Build erstellen:**
   - Product → Scheme → Edit Scheme...
   - Run → Build Configuration → **Release** wählen
   - OK
5. **Build:** ⌘B (oder Product → Build)
6. **Run:** ⌘R (oder Product → Run)

### Option 2: Über Terminal bauen

```bash
cd /Users/chbram/Documents/Arduino/PhotoCropper
xcodebuild -project PhotoCropper.xcodeproj -scheme PhotoCropper -configuration Release clean build
```

### Wo findest du die kompilierte App?

Die App liegt normalerweise hier:

```
~/Library/Developer/Xcode/DerivedData/PhotoCropper-*/Build/Products/Release/PhotoCropper.app
```

**Im Finder:**
1. Finder öffnen
2. ⌘⇧G (Gehe zu Ordner)
3. Pfad eingeben: `~/Library/Developer/Xcode/DerivedData`
4. Den Ordner `PhotoCropper-*` öffnen
5. Navigiere zu: `Build/Products/Release/`
6. Die `PhotoCropper.app` findest du dort

**Über Terminal:**
```bash
# Finde die App automatisch
find ~/Library/Developer/Xcode/DerivedData -name "PhotoCropper.app" -path "*/Release/*" | head -1
```

### App für die Verteilung vorbereiten

Um die App an einem festen Ort zu haben:

```bash
# Erstelle einen dist-Ordner
mkdir -p dist

# Kopiere die App dorthin
cp -R ~/Library/Developer/Xcode/DerivedData/PhotoCropper-*/Build/Products/Release/PhotoCropper.app dist/
```

Die App ist dann in `dist/PhotoCropper.app` verfügbar und kann einfach weitergegeben werden.

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

