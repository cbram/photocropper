#!/bin/bash
# Backup des Original-Icons
cp PhotoCropper/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png PhotoCropper/Assets.xcassets/AppIcon.appiconset/icon_1024x1024_backup.png

# Erstelle ein neues Icon, das den vollen Bereich nutzt
# Entferne den Rand und erweitere auf 1024x1024
sips -z 1024 1024 PhotoCropper/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png

echo "✅ Icon angepasst!"
echo "Original gesichert als: icon_1024x1024_backup.png"
