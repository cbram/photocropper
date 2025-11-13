# GitHub Repository Setup

## Repository auf GitHub erstellen

1. **Gehen Sie zu GitHub:** https://github.com/new

2. **Repository-Details:**
   - Repository Name: `PhotoCropper`
   - Description: `Native macOS SwiftUI app for lossless JPEG/HEIC cropping with metadata storage`
   - Visibility: Public oder Private (Ihre Wahl)
   - **WICHTIG:** KEINE README, .gitignore oder License hinzufügen (haben wir schon!)

3. **Repository erstellen** klicken

## Mit GitHub verbinden und pushen

Nach der Erstellung zeigt GitHub Ihnen Commands. Verwenden Sie diese:

```bash
cd /Users/chbram/Documents/Arduino/PhotoCropper

# Remote hinzufügen (ersetzen Sie USERNAME mit Ihrem GitHub-Username)
git remote add origin https://github.com/USERNAME/PhotoCropper.git

# Ersten Push
git push -u origin main
```

## Alternative: SSH verwenden (empfohlen)

Falls Sie SSH-Keys konfiguriert haben:

```bash
git remote add origin git@github.com:USERNAME/PhotoCropper.git
git push -u origin main
```

## Nach dem Push

Ihr Repository enthält:
- ✅ 28 Dateien
- ✅ 3133 Zeilen Code
- ✅ Vollständige macOS SwiftUI App
- ✅ README.md mit Dokumentation
- ✅ XCODE_SETUP.md mit Setup-Anleitung
- ✅ Alle Swift-Quelldateien

## Zukünftige Updates

```bash
# Änderungen hinzufügen
git add .

# Commit erstellen
git commit -m "Beschreibung der Änderungen"

# Zu GitHub pushen
git push
```

## Repository-URL

Nach dem Push wird Ihr Projekt verfügbar sein unter:
```
https://github.com/USERNAME/PhotoCropper
```

## Empfohlene Topics für GitHub

Fügen Sie diese Topics zu Ihrem Repository hinzu (auf GitHub → Settings → Topics):
- `swift`
- `swiftui`
- `macos`
- `image-processing`
- `jpeg`
- `heic`
- `metadata`
- `exif`
- `crop`
- `photo-editing`

