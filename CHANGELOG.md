# Changelog

All notable changes to PhotoCropper will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Automated unit tests
- Advanced MCU detection (direct libjpeg integration)
- Undo/Redo functionality
- Preset management for crop settings
- Keyboard shortcuts customization

## [1.0.0] - 2025-11-30

### Added
- Initial release of PhotoCropper
- Lossless JPEG cropping with MCU-sensitive mode via jpegtran
- HEIC support with automatic conversion to JPEG
- PNG and TIFF support (with re-encoding)
- Multiple aspect ratio presets (16:9, 1:1, custom)
- Interactive crop box with drag and resize
- MCU grid visualization for precise JPEG cropping
- Composition overlays (Rule of Thirds, Golden Ratio, Fibonacci Spiral)
- Comprehensive metadata preservation
  - EXIF DefaultCropOrigin/Size tags
  - XMP Adobe Lightroom compatible tags
  - Custom PhotoCropper tags for full state preservation
- Automatic loading of previously saved crop coordinates
- Visual indicators for images with saved crop metadata
- Batch processing support for multiple images
- Automatic filename generation from EXIF date
- EXIF date parsing with multiple format support
- Keyboard shortcuts (Space for overlays, Enter for next image)
- Responsive UI optimized for 900×600 minimum resolution
- Security-scoped resource access for sandbox compatibility
- Process executor utility for safe external command execution

### Architecture
- Clean Code architecture with clear separation of concerns
- Models layer for data structures
- Services layer for business logic
- Views layer with SwiftUI + AppKit hybrid
- Utilities layer for cross-cutting concerns
- Dependency injection pattern
- Result-based error handling
- Comprehensive Swift DocC documentation

### Technical Details
- SwiftUI for modern declarative UI
- AppKit integration for high-performance canvas rendering
- ImageIO framework for metadata and image loading
- External tool integration:
  - jpegtran (jpeg-turbo) for lossless JPEG operations
  - exiftool for comprehensive metadata manipulation
- Coordinate normalization (0.0-1.0) for resolution independence
- Reader/Writer/Facade pattern for metadata services
- 3-pass strategy for exiftool metadata writing

### Documentation
- Comprehensive README with installation and usage instructions
- CLAUDE.md project constitution and architecture overview
- REFACTORING_PLAN.md detailing the 13-step refactoring process
- REFACTORING_SUMMARY.md as quick reference guide
- Complete inline Swift DocC documentation
- Contributing guidelines
- MIT License

## Release Notes

### What's New in 1.0.0

PhotoCropper is a native macOS application designed for photographers and image professionals who need precise, lossless image cropping with comprehensive metadata preservation.

**Key Highlights:**
- **True Lossless JPEG Cropping**: Uses jpegtran for MCU-aligned cropping without quality loss
- **Smart Metadata Handling**: Saves crop coordinates so you can change your mind later
- **Batch Processing**: Crop multiple images with the same settings efficiently
- **Professional Composition Tools**: Rule of Thirds, Golden Ratio, and Fibonacci overlays
- **macOS Native**: Built with SwiftUI for a modern, responsive interface

**Perfect For:**
- Photographers preparing images for print or web
- Professionals needing consistent cropping across image sets
- Users who want to preview crops without permanently modifying originals
- Anyone who values image quality and metadata preservation

### Known Limitations in 1.0.0

- MCU size detection is simplified (assumes 8×8 blocks for standard JPEGs)
- HEIC images require re-encoding (no truly lossless crop)
- PNG/TIFF always require re-encoding
- No automated test suite (manual testing only)
- External dependencies (jpegtran, exiftool) must be installed separately

### Migration Notes

This is the initial release - no migration necessary.

---

**For detailed changes and technical information, see the Git commit history and REFACTORING_PLAN.md**

