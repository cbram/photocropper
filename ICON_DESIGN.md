# PhotoCropper App Icon - Design-Richtlinien

## Aktueller Status
✅ Das Icon verwendet jetzt das moderne macOS-Format (seit macOS 11 Big Sur)
✅ Rahmen wird nicht mehr automatisch hinzugefügt

## macOS Icon-Format (Big Sur und neuer)

### Anforderungen
- **Größe**: 1024 x 1024 Pixel
- **Format**: PNG mit Transparenz
- **Farbraum**: sRGB oder Display P3
- **Kein Rahmen**: macOS fügt automatisch die richtige Maske hinzu

### Icon-Design Best Practices

1. **Vollflächiges Design**: Das Icon sollte den gesamten 1024x1024 Bereich nutzen
2. **Abgerundete Ecken**: macOS fügt automatisch die charakteristischen abgerundeten Ecken hinzu
3. **Schatten**: Vermeiden Sie harte Schatten - macOS fügt eigene Schatten hinzu
4. **Transparenz**: Der Hintergrund sollte transparent sein oder das Icon sollte den vollen Bereich ausfüllen
5. **Padding**: Halten Sie wichtige Elemente ~10% vom Rand entfernt

### Technische Details

**Asset Catalog Konfiguration** (`Contents.json`):
```json
{
  "images" : [
    {
      "filename" : "icon_1024x1024.png",
      "idiom" : "universal",
      "platform" : "macos",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

### Wenn das Icon noch einen Rahmen zeigt

Falls das Icon nach dem Build noch einen Rahmen hat:

1. **Icon-Cache löschen**:
   ```bash
   killall Dock && killall Finder
   ```

2. **App vollständig neu bauen**:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/PhotoCropper*
   xcodebuild clean
   xcodebuild build
   ```

3. **System-Icon-Cache löschen** (als letzter Ausweg):
   ```bash
   sudo rm -rf /Library/Caches/com.apple.iconservices.store
   killall Dock && killall Finder
   ```

### Icon-Datei aktualisieren

Wenn Sie ein neues Icon erstellen möchten:

1. Erstellen Sie ein 1024x1024 PNG
2. Ersetzen Sie `/PhotoCropper/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png`
3. Bauen Sie das Projekt neu
4. Setzen Sie den Icon-Cache zurück

### Aktuelle Icon-Dateien

- `icon_1024x1024.png` - Das einzige benötigte Icon (1024x1024px)
- ~~`icon_512x512.png`~~ - Wurde entfernt (nicht mehr benötigt)

## Referenzen

- [Apple Human Interface Guidelines - App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [macOS App Icon Template](https://developer.apple.com/design/resources/)





