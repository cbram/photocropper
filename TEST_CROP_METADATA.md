# Test-Anleitung: Crop-Metadaten Feature

## Was wurde implementiert?

1. **Automatisches Laden von Crop-Koordinaten**: Beim Öffnen eines Bildes mit gespeicherten PhotoCropper-Metadaten wird die Crop-Box automatisch an die richtige Position gesetzt
2. **Visuelle Kennzeichnung**: Bilder mit Crop-Metadaten zeigen ein blaues Crop-Symbol auf dem Thumbnail
3. **Info-Anzeige**: Im Info-Panel wird angezeigt, ob Crop-Daten vorhanden sind

## So testen Sie das Feature:

### Test 1: Bild mit Crop-Daten speichern

1. **App starten** und ein Bild laden
2. Crop-Box positionieren (z.B. nicht zentriert, sondern links oben)
3. **"Alle speichern"** klicken
4. **"Crop-Daten in EXIF speichern"** aktivieren
5. Bild speichern

### Test 2: Bild mit Crop-Daten laden

1. **App neu starten** (oder alle Bilder schließen)
2. Das gerade gespeicherte Bild **erneut laden**
3. **Erwartetes Verhalten**:
   - Im Thumbnail-Liste sollte ein **blaues Crop-Symbol** oben rechts erscheinen
   - Text "Gespeichert" sollte unter dem Dateinamen stehen
   - Die **Crop-Box sollte an der gespeicherten Position** erscheinen (nicht zentriert!)
   - Im **Info-Panel** sollte "Crop-Daten vorhanden" stehen

### Debug-Ausgaben in der Konsole

Öffnen Sie die Konsole in Xcode (⌘⇧C) oder Console.app und filtern Sie nach "PhotoCropper".

Sie sollten folgende Ausgaben sehen:

```
✅ Bild hat bereits Crop-Metadaten: IhrBild.jpg
📖 PhotoCropper Crop-Metadaten gefunden:
   Origin: (0.xxx, 0.xxx)
   Size: (0.xxx, 0.xxx)
   Mode: MCU-Sensitive
   Target Ratio: 16:9

📸 loadCurrentBatchImage für: IhrBild.jpg
   hasCropMetadata: true
   cropSettings vorhanden: true
📖 Lade gespeicherte Crop-Metadaten aus EXIF
   → Crop-Box: (x, y, width, height)
   → Mode: MCU-Sensitive
   → Target Ratio: 16:9 → 16:9
```

## Häufige Probleme:

### Problem 1: Keine Crop-Daten gefunden
**Ursache**: exiftool ist nicht installiert
**Lösung**: 
```bash
brew install exiftool
```

### Problem 2: Badge nicht sichtbar
**Ursache**: `hasCropMetadata` ist false
**Prüfen Sie**: 
- Wurde das Bild mit aktivierter "Crop-Daten in EXIF speichern" Option gespeichert?
- Konsolen-Ausgabe nach "✅ Bild hat bereits Crop-Metadaten"

### Problem 3: Crop-Box wird nicht korrekt geladen
**Ursache**: Koordinaten-Konvertierung oder Parsing-Fehler
**Prüfen Sie**:
- Konsolen-Ausgabe: "📖 Lade gespeicherte Crop-Metadaten aus EXIF"
- Werden Origin und Size korrekt angezeigt?

## Metadaten mit exiftool prüfen:

```bash
# PhotoCropper-Tags anzeigen
exiftool -XMP-dc:Subject IhrBild.jpg | grep PhotoCropper

# Sollte ausgeben:
# PhotoCropper:CropMode=MCU-Sensitive
# PhotoCropper:TargetRatio=16:9
# PhotoCropper:OriginalRatio=3:2
# PhotoCropper:CropOriginX=0.123
# PhotoCropper:CropOriginY=0.456
# PhotoCropper:CropWidth=0.789
# PhotoCropper:CropHeight=0.444
```





