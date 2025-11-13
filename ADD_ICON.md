# App Icon hinzufügen

## Schritte:

1. Das Icon-Bild (das Sie im Chat angehängt haben) als PNG speichern
2. Das Bild auf 1024×1024 skalieren (z.B. mit Vorschau.app)
3. Als `icon_1024x1024.png` speichern in:
   ```
   PhotoCropper/Assets.xcassets/AppIcon.appiconset/
   ```

## Automatisch mit sips:

```bash
cd PhotoCropper/Assets.xcassets/AppIcon.appiconset/
sips -z 1024 1024 /Pfad/zum/Original-Icon.png --out icon_1024x1024.png
```

Das AppIcon-Set ist bereits konfiguriert und wartet auf die Datei!
