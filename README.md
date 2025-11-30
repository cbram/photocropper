# PhotoCropper - macOS JPEG/HEIC Lossless Crop Tool

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%2012.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)

Native macOS SwiftUI application for lossless cropping of JPEG/HEIC images with metadata preservation.

## Features

- ✅ Support for various image formats (JPEG, HEIC, PNG, TIFF)
- ✅ Flexible aspect ratios (3:2, 16:9, 1:1, 21:9, portrait, etc.)
- ✅ Target format selection: 16:9, 1:1, Custom
- ✅ MCU-sensitive cropping for JPEG (lossless)
- ✅ Standard cropping as fallback
- ✅ Interactive GUI with red crop frame
- ✅ MCU grid visualization (optional)
- ✅ Metadata storage (EXIF DefaultCropOrigin/Size + Custom XMP Tags)
- ✅ **Automatic loading of saved crop coordinates** - Images with saved crop data are detected and the crop box is automatically positioned
- ✅ **Visual indicators** - Images with saved crop metadata are marked with a blue badge in the list
- ✅ Automatic filename generation from EXIF date
- ✅ Batch processing for multiple images
- ✅ HEIC to JPEG conversion (optional)
- ✅ **Responsive UI** - Optimized for various screen sizes (min. 900×600 pixels)

## Screenshots

*Coming soon - Add screenshots of your app in action*

## Prerequisites

- macOS 12.0 or higher
- Xcode 14.0 or higher
- jpegtran (for MCU-sensitive cropping): `brew install jpeg-turbo`
- exiftool (for metadata manipulation): `brew install exiftool`

## Installation

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/YOUR_USERNAME/PhotoCropper.git
cd PhotoCropper
```

2. Open the project:
```bash
open PhotoCropper.xcodeproj
```

3. In Xcode:
   - Product → Build (⌘B)
   - Product → Run (⌘R)

### Building Release Version

#### Option 1: In Xcode

1. **Open Xcode** and open the project `PhotoCropper.xcodeproj`
2. **Product → Scheme → PhotoCropper** select
3. **Product → Destination → My Mac** select
4. **Create Release build:**
   - Product → Scheme → Edit Scheme...
   - Run → Build Configuration → **Release** select
   - OK
5. **Build:** ⌘B (or Product → Build)
6. **Run:** ⌘R (or Product → Run)

#### Option 2: Via Terminal

```bash
cd PhotoCropper
xcodebuild -project PhotoCropper.xcodeproj -scheme PhotoCropper -configuration Release clean build
```

### Locating the Compiled App

The app is typically located at:

```
~/Library/Developer/Xcode/DerivedData/PhotoCropper-*/Build/Products/Release/PhotoCropper.app
```

**In Finder:**
1. Open Finder
2. ⌘⇧G (Go to Folder)
3. Enter path: `~/Library/Developer/Xcode/DerivedData`
4. Open the `PhotoCropper-*` folder
5. Navigate to: `Build/Products/Release/`
6. You'll find `PhotoCropper.app` there

**Via Terminal:**
```bash
# Find the app automatically
find ~/Library/Developer/Xcode/DerivedData -name "PhotoCropper.app" -path "*/Release/*" | head -1
```

### Preparing the App for Distribution

To have the app at a fixed location:

```bash
# Create dist folder
mkdir -p dist

# Copy the app there
cp -R ~/Library/Developer/Xcode/DerivedData/PhotoCropper-*/Build/Products/Release/PhotoCropper.app dist/
```

The app is then available at `dist/PhotoCropper.app` and can be easily shared.

## Usage

1. **Open image**: File → Open or Drag & Drop
2. **Select target format**: 16:9, 1:1, or Custom
3. **Cropping mode**: MCU-sensitive (Lossless) or Standard
4. **Adjust crop box**: Interactively drag with mouse
5. **Save**: Metadata is saved in EXIF/XMP

### Keyboard Shortcuts

- **⌘O** - Open image
- **Space** - Toggle composition overlays
- **Enter** - Mark as done and move to next image
- **⌘⇧W** - Close all images

## Project Structure

```
PhotoCropper/
├── Models/
│   ├── AspectRatio.swift          # Aspect ratio calculations
│   ├── CropSettings.swift         # Crop settings
│   ├── ImageData.swift            # Image data with metadata
│   ├── ExifData.swift             # EXIF/XMP structures
│   ├── BatchImageItem.swift       # Individual batch element
│   ├── BatchImageManager.swift    # Batch management
│   ├── CompositionOverlay.swift   # Composition guides
│   └── OverlayGuide.swift         # Unified overlay system
├── Views/
│   ├── ContentView.swift          # Main view
│   ├── CanvasView.swift           # Image canvas (AppKit)
│   ├── ControlsView.swift         # Controls
│   ├── PreviewView.swift          # Preview
│   ├── ExportView.swift           # Export dialog
│   ├── InfoPanel.swift            # Info panel
│   ├── BatchImageListView.swift   # Batch list
│   └── BatchExportView.swift      # Batch export
├── Services/
│   ├── ImageService.swift         # Image loading & format detection
│   ├── ImageCropService.swift     # Standard cropping (all formats)
│   ├── JPEGService.swift          # JPEG MCU cropping (lossless)
│   ├── MetadataService.swift      # Metadata facade
│   ├── MetadataReader.swift       # Metadata reading
│   ├── MetadataWriter.swift       # Metadata writing
│   ├── CropEngine.swift           # Crop calculations
│   └── ExifDateParser.swift       # EXIF date parsing
└── Utilities/
    ├── CoordinateMapper.swift     # Coordinate transformations
    ├── FileManager+Extensions.swift # File operations
    ├── KeyboardMonitor.swift      # Keyboard events
    ├── ProcessExecutor.swift      # External commands (posix_spawn)
    └── NSImage+Extensions.swift   # Image helpers
```

## Technical Details

- **SwiftUI + AppKit Hybrid**: Canvas uses AppKit for better performance
- **jpegtran Integration**: Shell command for lossless JPEG cropping (via ProcessExecutor)
- **exiftool Integration**: Metadata manipulation without image re-encoding
- **ImageIO Framework**: For image loading and metadata
- **Clean Code Architecture**: 
  - Separation of Concerns (Models/Services/Views/Utilities)
  - Single Responsibility Principle
  - Dependency Injection
  - Comprehensive error handling with Result types
  - Complete Swift DocC documentation
- **Metadata Strategy**:
  - Reader/Writer/Facade Pattern for metadata services
  - 3-Pass Strategy for exiftool (Delete → Write → Sync)
  - Normalized coordinates (0.0-1.0) for resolution independence

## Metadata Storage

### EXIF Tags (Standard)
- `DefaultCropOrigin`: Normalized crop origin [x, y]
- `DefaultCropSize`: Normalized crop size [width, height]

### XMP Tags (Adobe Lightroom Compatible)
- `XMP-crs:CropTop`: Normalized Y coordinate
- `XMP-crs:CropLeft`: Normalized X coordinate
- `XMP-crs:CropBottom`: Normalized Y + height
- `XMP-crs:CropRight`: Normalized X + width

### Custom Tags (PhotoCropper Specific)
Stored in `XMP-dc:Subject` as structured tags:
- `PhotoCropper:CropMode`: MCU-Sensitive or Standard
- `PhotoCropper:TargetRatio`: Target aspect ratio (e.g., "16:9")
- `PhotoCropper:OriginalRatio`: Original image ratio
- `PhotoCropper:CropOriginX`: Normalized X origin
- `PhotoCropper:CropOriginY`: Normalized Y origin
- `PhotoCropper:CropWidth`: Normalized width
- `PhotoCropper:CropHeight`: Normalized height

All coordinates are stored normalized (0.0 to 1.0) to be resolution-independent.

## Known Limitations

- MCU size detection is simplified (standard: 8x8 for JPEGs)
- For precise MCU detection, direct libjpeg would be necessary
- HEIC does not support MCU cropping (uses re-encoding)
- PNG/TIFF always use re-encoding (no lossless crop available)
- No automated tests (manual testing only)

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Documentation

- **CLAUDE.md**: Central project documentation and architecture overview
- **REFACTORING_PLAN.md**: Detailed plan of the refactoring performed (Steps 1-13)
- All services and models are documented with Swift DocC

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **jpegtran** from jpeg-turbo for lossless JPEG manipulation
- **exiftool** by Phil Harvey for comprehensive metadata handling
- Apple's ImageIO framework for robust image handling

## Support

If you encounter any issues or have questions:
- Open an [Issue](https://github.com/cbram/photocropper/issues)
- Check existing [Discussions](https://github.com/cbram/photocropper/discussions)

---

**Made with ❤️ for photographers who need precise, lossless image cropping**
