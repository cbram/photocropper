# PhotoCropper - Project Constitution & Central Documentation

## Project Overview

**PhotoCropper** is a native macOS application built with SwiftUI for lossless cropping of JPEG/HEIC images with comprehensive metadata preservation. The application supports MCU-sensitive (Minimum Coded Unit) cropping for true lossless JPEG operations and stores crop coordinates in EXIF/XMP metadata for non-destructive workflows.

### Key Features

- Multi-format support (JPEG, HEIC, PNG, TIFF)
- Flexible aspect ratios (16:9, 1:1, custom ratios, portrait/landscape)
- MCU-sensitive lossless JPEG cropping via `jpegtran`
- Interactive GUI with visual crop frame and MCU grid overlay
- Composition overlays (Rule of Thirds, Golden Ratio, Fibonacci)
- Metadata persistence (EXIF DefaultCropOrigin/Size + Custom XMP Tags)
- Automatic loading of saved crop coordinates
- Batch processing for multiple images
- HEIC to JPEG conversion support
- Automatic filename generation from EXIF date

---

## Architecture

### Layer Structure

```
PhotoCropper/
├── Models/              # Data structures and business entities
├── Services/            # Business logic and external integrations
├── Views/               # SwiftUI user interface
└── Utilities/           # Helper functions and extensions
```

### Design Principles

1. **Separation of Concerns**: Clear boundaries between UI, business logic, and data
2. **Single Responsibility**: Each class/struct has one well-defined purpose
3. **Dependency Management**: Services are loosely coupled and testable
4. **Immutability Preference**: Use immutable data structures where possible
5. **Error Handling**: Comprehensive error handling with Swift's Result type
6. **Metadata Integrity**: Never modify image data when only saving metadata

---

## Core Components

### Models Layer

| Component | Purpose | Dependencies |
|-----------|---------|--------------|
| `AspectRatio` | Aspect ratio calculations and crop sizing | CoreGraphics |
| `CropSettings` | Container for all crop-related settings | AspectRatio |
| `ImageData` | Represents loaded image with metadata | ImageIO, MetadataService |
| `ExifData` | EXIF/XMP metadata structures | None |
| `BatchImageManager` | Manages multiple images for batch processing | ImageData, CropSettings |
| `CompositionOverlay` | Composition guide definitions | None |

### Services Layer

| Component | Purpose | External Dependencies |
|-----------|---------|----------------------|
| `ImageService` | Image loading and format detection | ImageIO |
| `JPEGService` | JPEG-specific operations, MCU handling | jpegtran (Homebrew) |
| `MetadataService` | EXIF/XMP read/write operations | exiftool (Homebrew) |
| `CropEngine` | Crop calculations and coordinate transformations | None |
| `ExifDateParser` | EXIF date parsing and filename generation | None |

### Utilities Layer

| Component | Purpose |
|-----------|---------|
| `CoordinateMapper` | Coordinate system transformations |
| `FileManager+Extensions` | File system helpers |
| `KeyboardMonitor` | Global keyboard event monitoring |

---

## Technical Stack

### Frameworks
- **SwiftUI**: Primary UI framework
- **AppKit**: Canvas rendering for performance
- **ImageIO**: Image loading and metadata manipulation
- **CoreGraphics**: Image processing and coordinate calculations

### External Tools
- **jpegtran** (jpeg-turbo): Lossless JPEG cropping
- **exiftool**: Metadata manipulation without image re-encoding

### Minimum Requirements
- macOS 12.0+
- Xcode 14.0+
- Homebrew packages: `jpeg-turbo`, `exiftool` (optional but recommended)

---

## Code Standards

### Swift Coding Style

1. **Naming Conventions**
   - Types: PascalCase (`ImageService`, `CropSettings`)
   - Functions/Variables: camelCase (`calculateCropSize`, `targetRatio`)
   - Constants: camelCase with `k` prefix for global constants
   - Enums: PascalCase cases (`case mcuSensitive`)

2. **Documentation**
   - Use Apple's standard `///` triple-slash comments
   - Document public APIs with Swift DocC markup
   - Include parameter descriptions and return values
   - Add code examples for complex functionality

3. **Error Handling**
   - Use `Result<Success, Failure>` for operations that can fail
   - Define specific error enums per service
   - Implement `LocalizedError` for user-facing errors
   - Never use force unwrapping (`!`) in production code

4. **Access Control**
   - Default to `private` or `fileprivate`
   - Use `internal` (default) for cross-file access within module
   - Only expose `public` what's necessary
   - Mark extension methods as needed

5. **Type Safety**
   - Leverage Swift's type system
   - Avoid stringly-typed code
   - Use enums instead of magic strings/numbers
   - Prefer value types (struct) over reference types (class) where appropriate

### File Organization

- One primary type per file
- File name matches the primary type name
- Group related extensions in the same file
- Use `// MARK: -` comments to organize code sections

### Comment Style

```swift
/// Brief one-line description of the function/type
///
/// More detailed explanation if needed, can span multiple lines
/// and explain the purpose, behavior, and usage.
///
/// - Parameters:
///   - paramName: Description of the parameter
///   - anotherParam: Description of another parameter
/// - Returns: Description of the return value
/// - Throws: Description of potential errors
func exampleFunction(paramName: String, anotherParam: Int) -> Bool {
    // Implementation comments use double-slash for inline explanations
    let result = performCalculation()
    return result
}
```

---

## Development Workflow

### Building the App

**Via Xcode:**
1. Open `PhotoCropper.xcodeproj`
2. Select Product → Scheme → PhotoCropper
3. Select Product → Destination → My Mac
4. Build: ⌘B
5. Run: ⌘R

**Via Terminal:**
```bash
xcodebuild -project PhotoCropper.xcodeproj \
  -scheme PhotoCropper \
  -configuration Release \
  clean build
```

### Testing Strategy

**Manual Testing Checklist:**
1. ✅ Load single image (JPEG, HEIC, PNG)
2. ✅ Load multiple images (batch mode)
3. ✅ Adjust crop box (drag, resize)
4. ✅ Switch aspect ratios (16:9, 1:1, custom)
5. ✅ Toggle MCU grid (JPEG only)
6. ✅ Toggle composition overlays
7. ✅ Save metadata to file
8. ✅ Reload file and verify crop coordinates are restored
9. ✅ Export cropped images
10. ✅ Verify EXIF data preservation

**Critical Test Cases:**
- MCU-sensitive cropping produces valid JPEG
- Metadata writing doesn't modify image data
- Crop coordinates are correctly normalized (0.0-1.0)
- Previously cropped images reload with correct coordinates
- Batch export processes all images correctly

---

## Metadata Storage Strategy

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

### Coordinate Normalization

All crop coordinates are stored normalized (0.0 to 1.0) to be resolution-independent:

```
normalized_x = pixel_x / image_width
normalized_y = pixel_y / image_height
```

Precision: 5 decimal places maximum

---

## Common Pitfalls & Solutions

### Issue: jpegtran not found
**Solution**: Install via Homebrew: `brew install jpeg-turbo`

### Issue: exiftool not found
**Solution**: Install via Homebrew: `brew install exiftool`  
**Fallback**: App uses ImageIO (may re-encode image)

### Issue: MCU cropping fails
**Root Cause**: Coordinates not aligned to MCU boundaries (8x8 pixels)  
**Solution**: Enable MCU grid and snap coordinates

### Issue: Metadata not preserved after crop
**Root Cause**: ImageIO re-encodes image  
**Solution**: Ensure exiftool is installed for lossless metadata writing

### Issue: Custom ratio resets when loading metadata
**Root Cause**: onChange handlers fire during metadata loading  
**Solution**: Use `isLoadingFromMetadata` flag to suppress handlers

---

## Project History

### Evolution
- Started as simple JPEG cropper
- Added HEIC support
- Implemented metadata preservation
- Added batch processing
- Introduced composition overlays
- Enhanced with automatic metadata loading

### Current Version
- Fully functional batch processor
- Complete metadata round-trip support
- MCU-sensitive lossless JPEG cropping
- Responsive UI for various screen sizes

---

## Refactoring Guidelines

### When Refactoring

1. **Preserve Functionality**: Never break existing features
2. **Test After Each Step**: Manual testing checklist required
3. **Maintain Backward Compatibility**: Metadata format must remain compatible
4. **Document Changes**: Update this file and code comments
5. **Small Iterations**: Refactor in small, testable increments

### Refactoring Priorities

1. ✅ Code clarity and readability
2. ✅ Single Responsibility Principle
3. ✅ Dependency Injection for testability
4. ✅ Error handling consistency
5. ✅ Eliminate code duplication
6. ✅ Improve naming conventions
7. ✅ English-only comments and documentation

### Non-Refactorable Components

- **View layer**: SwiftUI views remain as-is
- **External dependencies**: jpegtran and exiftool integration stays unchanged
- **Metadata format**: EXIF/XMP structure must remain compatible

---

## Future Considerations

### Potential Enhancements
- Unit test suite (not currently implemented)
- Advanced MCU detection (requires direct libjpeg integration)
- Cloud storage integration
- Preset management for crop settings
- Undo/Redo functionality
- Keyboard shortcuts customization

### Known Limitations
- MCU size detection is simplified (assumes 8x8)
- HEIC doesn't support MCU-based lossless cropping
- No automated tests (manual testing only)

---

## License

MIT License

---

## Maintainer Notes

This document serves as the central source of truth for the PhotoCropper project. Update it when:
- Architecture changes significantly
- New features are added
- Coding standards evolve
- External dependencies change
- Major refactoring is completed

**Last Updated**: 2025-11-30

