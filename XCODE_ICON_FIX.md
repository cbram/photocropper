# Xcode "Unassigned" Icon Problem - Lösung

## Problem
In Xcode werden die Icons im AppIcon.appiconset als "Unassigned" angezeigt.

## Ursache
Xcode hat die Änderungen im Asset Catalog noch nicht neu geladen oder verwendet einen veralteten Cache.

## Lösung - Schritt für Schritt

### 1. Xcode neu starten
1. **Xcode komplett beenden** (⌘Q)
2. **Xcode neu starten**
3. **Projekt öffnen**
4. Im Project Navigator: **Assets.xcassets → AppIcon** öffnen
5. Sie sollten jetzt ein einziges **1024x1024** Icon-Feld sehen mit dem zugewiesenen Icon

### 2. Falls immer noch "Unassigned"

Wenn das Icon immer noch als "Unassigned" erscheint:

```bash
# 1. Xcode schließen
# 2. Terminal öffnen und Caches löschen:
cd /Users/chbram/Documents/Arduino/PhotoCropper
rm -rf ~/Library/Developer/Xcode/DerivedData/PhotoCropper*

# 3. Projekt neu bauen:
xcodebuild -project PhotoCropper.xcodeproj clean
xcodebuild -project PhotoCropper.xcodeproj -scheme PhotoCropper build

# 4. Xcode neu starten und Projekt öffnen
```

### 3. Icon-Cache-Problem beheben

Falls das Icon in der fertigen App immer noch einen Rahmen hat:

```bash
# Icon-Cache von macOS löschen:
killall Dock && killall Finder

# Oder System-Icon-Cache komplett löschen (als letzter Ausweg):
sudo rm -rf /Library/Caches/com.apple.iconservices.store
killall Dock && killall Finder
```

## Aktuelle Konfiguration (korrekt)

**Dateistruktur**:
```
PhotoCropper/Assets.xcassets/AppIcon.appiconset/
├── Contents.json           ← Korrekt konfiguriert
└── icon_1024x1024.png     ← Einzige benötigte Datei
```

**Contents.json** (korrekt):
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
  },
  "properties" : {
    "template-rendering-intent" : "original"
  }
}
```

## Was wurde geändert

✅ **Entfernt**: `icon_512x512.png` (nicht mehr benötigt)
✅ **Aktualisiert**: `Contents.json` auf modernes Format
✅ **Cache gelöscht**: Alle Xcode DerivedData-Caches entfernt

## Erwartetes Ergebnis in Xcode

Wenn Sie in Xcode auf **Assets.xcassets → AppIcon** klicken, sollten Sie sehen:

```
AppIcon
┌─────────────────────────┐
│  Mac                    │
│  ┌─────────────────┐    │
│  │                 │    │
│  │  [Icon Bild]    │    │  1024 x 1024
│  │                 │    │  Single Size
│  └─────────────────┘    │
└─────────────────────────┘
```

**Kein "Unassigned" mehr!**

## Wenn Sie ein neues Icon erstellen möchten

1. Erstellen Sie ein **1024x1024 PNG**
2. Ersetzen Sie die Datei:
   ```bash
   # Kopieren Sie Ihr neues Icon:
   cp /pfad/zu/ihrem/neuen_icon.png \
      PhotoCropper/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png
   ```
3. In Xcode: **Product → Clean Build Folder** (⌘⇧K)
4. **Product → Build** (⌘B)
5. Icon-Cache löschen: `killall Dock && killall Finder`

## Weitere Informationen

Siehe auch:
- `ICON_DESIGN_DE.md` - Ausführliche Anleitung zum Icon-Design
- [Apple HIG - App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)





