# Xcode-Projekt manuell erstellen

Da die automatische Erstellung des Xcode-Projekts Probleme hatte, hier die Schritte zum manuellen Erstellen:

## Option 1: Neues Xcode-Projekt erstellen (Empfohlen)

1. **Xcode öffnen**

2. **File → New → Project** wählen

3. **macOS → App** auswählen → Next

4. **Projekt-Details eingeben:**
   - Product Name: `PhotoCropper`
   - Team: (Ihr Team oder None)
   - Organization Identifier: `com.photocropper`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - **WICHTIG:** Speichern Sie das Projekt AUSSERHALB des aktuellen Ordners (z.B. auf Desktop)

5. **Dateien hinzufügen:**
   - Löschen Sie die automatisch erstellte `ContentView.swift` im Navigator
   - Ziehen Sie den gesamten `PhotoCropper` Ordner aus dem Finder in den Xcode Navigator
   - Wählen Sie: **Copy items if needed** ✓
   - **Create groups** ✓
   - Target: PhotoCropper ✓

6. **Entitlements konfigurieren:**
   - File → New → File → Property List
   - Name: `PhotoCropper.entitlements`
   - Fügen Sie hinzu:
     ```xml
     <key>com.apple.security.app-sandbox</key>
     <false/>
     <key>com.apple.security.files.user-selected.read-write</key>
     <true/>
     ```

7. **Build Settings anpassen:**
   - Target PhotoCropper auswählen
   - Signing & Capabilities:
     - App Sandbox: OFF (oder manuell konfigurieren)
   - General:
     - Minimum Deployments: macOS 12.0

8. **Build & Run:** ⌘R

## Option 2: Vorhandene Dateien verwenden

Alle Swift-Dateien befinden sich bereits im `PhotoCropper` Ordner:

```
PhotoCropper/
├── PhotoCropperApp.swift       (Main Entry Point)
├── PhotoCropper.entitlements
├── Models/
│   ├── AspectRatio.swift
│   ├── CropSettings.swift
│   ├── ExifData.swift
│   └── ImageData.swift
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

## Option 3: Swift Package Manager (Alternative)

Falls Sie lieber mit SPM arbeiten möchten:

1. Erstellen Sie ein `Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhotoCropper",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "PhotoCropper", targets: ["PhotoCropper"])
    ],
    targets: [
        .executableTarget(
            name: "PhotoCropper",
            path: "PhotoCropper"
        )
    ]
)
```

2. Öffnen Sie mit: `open Package.swift`

## Bekannte Probleme & Lösungen

### Problem: "Cannot find X in scope"
**Lösung:** Alle Dateien müssen zum Target hinzugefügt sein.

### Problem: "Sandbox-Fehler" beim Dateizugriff
**Lösung:** Entitlements-Datei korrekt konfigurieren (siehe oben).

### Problem: jpegtran nicht gefunden
**Lösung:** Installieren mit: `brew install jpeg-turbo`

## Nach erfolgreicher Erstellung

1. **Build** das Projekt (⌘B)
2. **Run** (⌘R)
3. Testen Sie mit einem JPEG-Bild

## Support

Falls Probleme auftreten:
- Prüfen Sie die Build-Logs in Xcode
- Stellen Sie sicher, dass alle Dateien im Target enthalten sind (File Inspector → Target Membership)
- macOS 12.0+ ist erforderlich

