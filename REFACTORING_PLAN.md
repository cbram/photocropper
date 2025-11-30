# PhotoCropper - Refactoring Plan (Clean Code Implementation)

## Overview

This document outlines a step-by-step refactoring plan to improve code quality according to Clean Code principles while maintaining full backward compatibility and functionality. Each step is designed to be independently testable.

**Refactoring Scope**: Models, Services, and Utilities layers (Views excluded)

**Testing Strategy**: Manual testing after each step using the testing checklist

**Duration Estimate**: 17 steps total, averaging 15-30 minutes each (implementation + testing)
- Low-Risk Steps: 10-20 minutes each
- Medium-Risk Steps: 20-40 minutes each  
- Medium-High Risk Steps: 30-60 minutes each (careful testing required)

## ⚠️ High-Risk Steps Subdivision Strategy

The original high-risk Steps 7 and 8 (JPEGService and MetadataService) have been **subdivided into 7 smaller, safer steps**:

### Original Step 7 (JPEGService) → Now Steps 7, 7a, 7b
1. **Step 7**: Create ProcessExecutor foundation (no logic changes)
2. **Step 7a**: Documentation and path detection (low risk)
3. **Step 7b**: Refactor process execution using new utility (testable in isolation)

### Original Step 8 (MetadataService) → Now Steps 8, 8a, 8b, 8c
1. **Step 8**: Create metadata utilities foundation (no logic changes)
2. **Step 8a**: Extract reading logic (isolated change)
3. **Step 8b**: Extract writing logic (most critical - well tested)
4. **Step 8c**: Final cleanup and facade pattern (polish)

**Benefit**: Each substep can be tested independently, reducing risk of breaking critical functionality.

---

## Clean Code Principles Applied

1. ✅ **Single Responsibility Principle (SRP)**: Each class/function has one clear purpose
2. ✅ **Dependency Injection**: Reduce tight coupling, improve testability
3. ✅ **Consistent Error Handling**: Use Result types uniformly
4. ✅ **Code Deduplication**: DRY (Don't Repeat Yourself)
5. ✅ **Meaningful Naming**: Self-documenting code
6. ✅ **English Documentation**: All comments in English using Apple's standard

---

## Steps Overview (17 Total)

| Step | Component | Risk Level | Time Est. | Focus |
|------|-----------|------------|-----------|-------|
| 1 | AspectRatio | Low | 15-20 min | Documentation, validation |
| 2 | CropSettings | Low | 15-20 min | Documentation, immutability |
| 3 | ImageData | Medium | 30-40 min | SRP, error handling |
| 4 | ExifData | Low | 10-15 min | Documentation, validation |
| 5 | BatchImageManager | Medium | 30-40 min | File splitting, SRP |
| 6 | ImageService | Medium | 20-30 min | Consistency, thumbnails |
| 7 | ProcessExecutor (new) | Low | 20-25 min | **Foundation utility** |
| 7a | JPEGService Part 1 | Low | 15-20 min | Documentation, paths |
| 7b | JPEGService Part 2 | Med-High | 40-60 min | **Process execution** ⚠️ |
| 8 | Metadata Utils (new) | Low | 20-25 min | **Foundation utilities** |
| 8a | MetadataService Part 1 | Medium | 25-35 min | Reading logic |
| 8b | MetadataService Part 2 | Med-High | 45-60 min | **Writing logic** ⚠️ |
| 8c | MetadataService Part 3 | Med-High | 30-40 min | **Facade cleanup** ⚠️ |
| 9 | CropEngine | Medium | 20-30 min | Validation, docs |
| 10 | ExifDateParser | Low | 15-20 min | Error handling |
| 11 | Utilities Layer | Medium | 25-35 min | Consolidation |
| 12 | CompositionOverlay | Low | 10-15 min | Documentation only |
| 13 | Final Polish | Low | 30-45 min | Review, consistency |

**Total Estimated Time**: 6-10 hours

---

## Testing Checklist (Run After Each Step)

Before marking a step as complete, verify:

- [ ] App builds successfully
- [ ] Load single JPEG image
- [ ] Load single HEIC image
- [ ] Adjust crop box manually
- [ ] Change aspect ratio (16:9, 1:1, custom)
- [ ] Toggle MCU grid (for JPEG)
- [ ] Save metadata to image
- [ ] Reload image and verify crop coordinates restored
- [ ] Batch mode: Load multiple images
- [ ] Batch mode: Export all images
- [ ] Verify no console errors or warnings

---

## Step 1: Refactor `AspectRatio.swift` - Clean Up and Document

### Current Issues
- German comments mixed with English
- Public helper function `calculateImageAspectRatio` at file level (should be in utility or extension)
- Missing comprehensive documentation
- `allCases` implementation is confusing (returns custom ratio as example)

### Changes

1. **Translate all comments to English**
2. **Add comprehensive Swift DocC documentation**
3. **Fix `allCases` implementation** - should only return predefined ratios
4. **Move `calculateImageAspectRatio` and `greatestCommonDivisor` into appropriate structure**
5. **Add parameter validation** for custom ratios (width/height > 0)
6. **Extract magic number** (0.001 tolerance) to named constant

### Files Modified
- `PhotoCropper/Models/AspectRatio.swift`

### Testing Focus
- Aspect ratio calculations work correctly
- Custom ratios display properly
- Crop box sizing remains accurate

---

## Step 2: Refactor `CropSettings.swift` - Improve Structure

### Current Issues
- Simple struct, but missing documentation
- `normalizedCoordinates` method could be static utility
- No validation of crop box values
- German comments

### Changes

1. **Translate comments to English**
2. **Add Swift DocC documentation**
3. **Add validation** in initializer (crop box must be within image bounds)
4. **Consider making CropSettings immutable** with `let` instead of `var`
5. **Add convenience initializers** for common use cases
6. **Improve timestamp handling** (make cropDateTime optional with default)

### Files Modified
- `PhotoCropper/Models/CropSettings.swift`

### Testing Focus
- Crop settings are saved correctly
- Normalized coordinates calculation is accurate
- Settings persist across image switches

---

## Step 3: Refactor `ImageData.swift` - Single Responsibility & Error Handling

### Current Issues
- Class does too many things (loading, parsing, format detection, metadata)
- No proper error handling (silent failures)
- German comments and print statements
- EXIF date parsing duplicated (should use `ExifDateParser`)
- Tight coupling to `MetadataService`
- Force unwraps in some code paths

### Changes

1. **Translate all comments and print statements to English**
2. **Add comprehensive Swift DocC documentation**
3. **Extract image loading logic** to `ImageService`
4. **Use dependency injection** for MetadataService
5. **Add proper error handling** with Result types
6. **Use `ExifDateParser`** instead of duplicating date parsing logic
7. **Consider splitting into smaller types**:
   - `ImageMetadata` (EXIF, format, dates)
   - `ImageData` (core image representation)
8. **Remove print statements** or replace with proper logging

### Files Modified
- `PhotoCropper/Models/ImageData.swift`
- `PhotoCropper/Services/ImageService.swift` (additions)
- `PhotoCropper/Services/ExifDateParser.swift` (additions)

### Testing Focus
- Images load correctly (all formats)
- Metadata extraction works
- Crop metadata is detected when present
- No crashes on invalid images

---

## Step 4: Refactor `ExifData.swift` - Structure and Documentation

### Current Issues
- Minimal structure, but missing documentation
- Magic strings for tag names
- No validation for metadata values

### Changes

1. **Add Swift DocC documentation** for all types
2. **Add validation** in `CropMetadata` initializer
   - Origin and size must be in range 0.0-1.0
   - Date must be valid
3. **Group related constants** using nested structs
4. **Add convenience methods** for common operations
5. **Translate any German comments**

### Files Modified
- `PhotoCropper/Models/ExifData.swift`

### Testing Focus
- Metadata validation works
- Invalid values are rejected
- Constants are accessible

---

## Step 5: Refactor `BatchImageManager.swift` - Improve Architecture

### Current Issues
- `BatchImageItem` and `BatchImageManager` in same file (should be separate)
- Thumbnail generation logic embedded in model
- No error handling for thumbnail generation
- German comments in enum
- Status management could be more robust

### Changes

1. **Split into two files**:
   - `BatchImageItem.swift`
   - `BatchImageManager.swift`
2. **Translate all comments to English**
3. **Add Swift DocC documentation**
4. **Extract thumbnail generation** to `ImageService`
5. **Improve status management** with clear state transitions
6. **Add validation** (prevent invalid index access)
7. **Move `NSImage.resized` extension** to separate file in Utilities
8. **Add error handling** for thumbnail generation

### Files Modified
- `PhotoCropper/Models/BatchImageItem.swift` (new)
- `PhotoCropper/Models/BatchImageManager.swift` (modified)
- `PhotoCropper/Utilities/NSImage+Extensions.swift` (new)

### Testing Focus
- Batch image loading works
- Thumbnails generate correctly
- Image selection and navigation works
- Status updates display properly
- Export batch functionality works

---

## Step 6: Refactor `ImageService.swift` - Enhance Functionality

### Current Issues
- Very minimal service
- Inconsistent error handling (some methods return optional, some Result)
- German error messages
- Missing documentation
- `loadImage` method is thin wrapper (consider removing)

### Changes

1. **Translate error messages to English**
2. **Add comprehensive Swift DocC documentation**
3. **Standardize return types** - all methods return `Result<T, Error>`
4. **Add thumbnail generation method** (moved from BatchImageItem)
5. **Add image validation method**
6. **Improve HEIC conversion** with better error handling and progress
7. **Extract magic values** to constants

### Files Modified
- `PhotoCropper/Services/ImageService.swift`

### Testing Focus
- Image loading works for all formats
- HEIC to JPEG conversion works
- Error messages are clear
- Thumbnail generation works

---

## Step 7: Create `ProcessExecutor.swift` - Foundation for External Tools

### Current Issues
- Both `JPEGService` and `MetadataService` manually manage posix_spawn
- Code duplication in argv/envp building
- Manual memory management (strdup/free) repeated
- No abstraction for process execution

### Changes

1. **Create new utility class** `ProcessExecutor`
2. **Encapsulate posix_spawn logic** with safe memory management
3. **Add Swift DocC documentation**
4. **Provide clean API** for executing external commands
5. **Add error handling** with meaningful error messages
6. **Add output capture** functionality

### Files Modified
- `PhotoCropper/Utilities/ProcessExecutor.swift` (new)

### Testing Focus
- No functional changes yet (foundation only)
- App still builds successfully
- Existing functionality unaffected

---

## Step 7a: Refactor `JPEGService.swift` - Part 1 (Path Detection & Documentation)

### Current Issues
- German comments and print statements
- Multiple possible jpegtran paths duplicated
- Missing comprehensive documentation

### Changes

1. **Translate all comments and print statements to English**
2. **Add comprehensive Swift DocC documentation**
3. **Extract jpegtran path detection** to separate method `findJPEGTranPath()`
4. **Add constants** for jpegtran installation paths
5. **Add constants** for standard MCU sizes
6. **Reduce print statement verbosity**

### Files Modified
- `PhotoCropper/Services/JPEGService.swift`

### Testing Focus
- jpegtran detection still works
- MCU size detection unchanged
- MCU snapping works correctly
- All JPEG operations still function

---

## Step 7b: Refactor `JPEGService.swift` - Part 2 (Process Execution)

### Current Issues
- Very long `cropLossless` method (>100 lines) - violates SRP
- Manual memory management (strdup/free)
- No abstraction for process execution

### Changes

1. **Use `ProcessExecutor`** utility for process execution
2. **Split `cropLossless`** into smaller methods:
   - `buildCropArguments()` - constructs argv array
   - `executeCropCommand()` - runs jpegtran via ProcessExecutor
   - `validateCropOutput()` - verifies output file
3. **Remove manual argv/envp memory management**
4. **Improve error messages** with context

### Files Modified
- `PhotoCropper/Services/JPEGService.swift`

### Testing Focus
- **CRITICAL**: MCU-sensitive cropping works (JPEG only)
- Standard cropping works as fallback
- Error messages are meaningful
- Output files are valid JPEGs
- File size is reasonable (not re-encoded)

---

## Step 8: Create Metadata Utilities - Foundation

### Current Issues
- MetadataService does too many things
- Decimal formatting logic is scattered
- exiftool path detection is duplicated

### Changes

1. **Create `MetadataFormatter.swift`**:
   - Extract decimal rounding logic
   - Extract decimal formatting logic
   - Add constants for precision
   - Add documentation

2. **Create `ExiftoolPathResolver.swift`**:
   - Extract exiftool path detection
   - Add constants for installation paths
   - Add documentation

### Files Modified
- `PhotoCropper/Utilities/MetadataFormatter.swift` (new)
- `PhotoCropper/Utilities/ExiftoolPathResolver.swift` (new)

### Testing Focus
- No functional changes (foundation only)
- App still builds successfully
- Existing functionality unaffected

---

## Step 8a: Refactor `MetadataService.swift` - Part 1 (Reading)

### Current Issues
- Mixed reading and writing responsibilities
- German comments in reading methods
- Duplicate tag filtering logic

### Changes

1. **Create `MetadataReader.swift`**:
   - Extract all reading logic from MetadataService
   - `readCropMetadata()`
   - `readPhotoCropperTagsWithExiftool()`
   - Use ExiftoolPathResolver
   - Add documentation

2. **Extract tag filtering**:
   - `readNonPhotoCropperSubjectTags()`
   - `readNonPhotoCropperIPTCKeywords()`

3. **Translate all comments to English**

### Files Modified
- `PhotoCropper/Services/MetadataReader.swift` (new)
- `PhotoCropper/Services/MetadataService.swift` (keep for now, will refactor)

### Testing Focus
- Metadata reading works
- Crop coordinates are detected when present
- Blue badge appears for images with crop metadata
- Crop coordinates load correctly

---

## Step 8b: Refactor `MetadataService.swift` - Part 2 (Writing with Exiftool)

### Current Issues
- `saveCropMetadataWithExiftool` is 220+ lines
- Three-pass strategy is not well abstracted
- Manual posix_spawn memory management
- Very verbose logging

### Changes

1. **Create `MetadataWriter.swift`**:
   - Extract exiftool writing logic
   - Use ProcessExecutor for execution
   - Use MetadataFormatter for coordinates
   - Add documentation

2. **Split three-pass strategy** into methods:
   - `deleteExistingCropTags()` - Pass 1
   - `writeNewCropTags()` - Pass 2
   - `synchronizeXMPtoIPTC()` - Pass 3

3. **Create helper methods**:
   - `buildDeleteArguments()`
   - `buildWriteArguments()`
   - `buildSyncArguments()`

4. **Translate all comments to English**
5. **Reduce logging verbosity**

### Files Modified
- `PhotoCropper/Services/MetadataWriter.swift` (new)
- `PhotoCropper/Services/MetadataService.swift` (modified)

### Testing Focus
- **CRITICAL**: Metadata saving works (with exiftool)
- Crop coordinates are saved correctly
- IPTC and XMP sync works
- Subject tags are preserved
- No image re-encoding occurs
- Reload image and verify coordinates match

---

## Step 8c: Refactor `MetadataService.swift` - Part 3 (Final Cleanup)

### Current Issues
- MetadataService still has ImageIO fallback code
- Not fully refactored yet
- German comments remain

### Changes

1. **Simplify MetadataService** to facade pattern:
   - Delegates to MetadataReader for reading
   - Delegates to MetadataWriter for writing
   - Keeps ImageIO fallback logic (simplified)
   - Add documentation

2. **Extract ImageIO writing** to separate method

3. **Add constants**: namespace URIs, tag names

4. **Translate remaining German comments**

5. **Update all callers** if API changed

### Files Modified
- `PhotoCropper/Services/MetadataService.swift` (final version)

### Testing Focus
- All metadata operations work end-to-end
- Exiftool path works
- ImageIO fallback works (if exiftool not found)
- Crop coordinates roundtrip correctly
- No regressions in batch export

---

## Step 9: Refactor `CropEngine.swift` - Enhance Robustness

### Current Issues
- German comments
- Missing comprehensive documentation
- Some methods could have better validation
- Magic numbers (minimum size = 1)
- No null/bounds checking in some methods

### Changes

1. **Translate comments to English**
2. **Add Swift DocC documentation**
3. **Add comprehensive validation** to all methods
4. **Extract constants** (minimum crop size, tolerance values)
5. **Add precondition checks** with meaningful messages
6. **Improve error messages** for invalid input
7. **Consider adding unit test helpers** (pure functions)

### Files Modified
- `PhotoCropper/Services/CropEngine.swift`

### Testing Focus
- Crop box calculations are accurate
- MCU snapping works correctly
- Coordinate normalization/denormalization works
- Edge cases handled (very small images, extreme ratios)

---

## Step 10: Refactor `ExifDateParser.swift` - Minor Improvements

### Current Issues
- German comments
- Basic functionality but could be more robust
- Date format strings are magic strings
- No error handling for invalid dates

### Changes

1. **Translate comments to English**
2. **Add Swift DocC documentation**
3. **Extract date format strings** to constants
4. **Add error handling** for date parsing failures
5. **Add support for multiple date formats** (more robust fallback)
6. **Add validation** for generated filenames (filesystem-safe)

### Files Modified
- `PhotoCropper/Services/ExifDateParser.swift`

### Testing Focus
- Filename generation works
- Dates are parsed correctly
- Fallback to file modification date works
- Special characters are handled

---

## Step 11: Refactor Utilities Layer - Consolidation

### Current Issues
- `CoordinateMapper` is minimal but undocumented
- `FileManager+Extensions` is very basic
- `KeyboardMonitor` has German comments and verbose logging
- No NSImage extension file (needed after BatchImageManager refactor)

### Changes

1. **CoordinateMapper.swift**:
   - Add Swift DocC documentation
   - Add validation for coordinate transformations
   - Add convenience methods for common transformations

2. **FileManager+Extensions.swift**:
   - Add documentation
   - Expand with commonly needed operations
   - Add error handling

3. **KeyboardMonitor.swift**:
   - Translate to English
   - Reduce print verbosity
   - Add documentation
   - Improve error handling

4. **NSImage+Extensions.swift** (new):
   - Move `resized` method from BatchImageManager
   - Add documentation
   - Add validation
   - Add error handling

### Files Modified
- `PhotoCropper/Utilities/CoordinateMapper.swift`
- `PhotoCropper/Utilities/FileManager+Extensions.swift`
- `PhotoCropper/Utilities/KeyboardMonitor.swift`
- `PhotoCropper/Utilities/NSImage+Extensions.swift` (new)

### Testing Focus
- Coordinate mapping works correctly
- File operations work
- Keyboard shortcuts work (Space, Enter)
- Thumbnail generation works

---

## Step 12: Refactor `CompositionOverlay.swift` - Documentation Only

### Current Issues
- German display names
- Missing documentation

### Changes

1. **Translate display names to English** (or make localizable)
2. **Add Swift DocC documentation**
3. **Consider adding overlay calculation methods** (if needed)

### Files Modified
- `PhotoCropper/Models/CompositionOverlay.swift`

### Testing Focus
- Composition overlays display correctly
- Names show properly in UI
- Toggle functionality works

---

## Step 13: Final Polish - Code Review and Consistency

### Changes

1. **Review all files** for consistency
2. **Ensure all comments are in English**
3. **Verify all public APIs have documentation**
4. **Check for remaining code duplication**
5. **Verify error handling is consistent**
6. **Run through full testing checklist**
7. **Update CLAUDE.md** with any architectural changes
8. **Update README.md** if needed

### Files Modified
- All previously refactored files (review only)
- `CLAUDE.md` (update)
- `README.md` (update if needed)

### Testing Focus
- **Complete full application test**
- All features work end-to-end
- No regressions introduced
- Code is cleaner and more maintainable

---

## Priority Order Justification

The steps are ordered to:
1. **Start with foundational models** (Steps 1-4: AspectRatio, CropSettings, ImageData, ExifData)
2. **Refactor batch management** (Step 5: separate concerns)
3. **Improve basic services** (Step 6: ImageService)
4. **Create process execution foundation** (Step 7: ProcessExecutor)
5. **Refactor JPEG service incrementally** (Steps 7a-7b: documentation first, then logic)
6. **Create metadata utilities foundation** (Step 8: utilities)
7. **Refactor metadata service incrementally** (Steps 8a-8c: reading, writing, cleanup)
8. **Polish remaining services** (Steps 9-10: CropEngine, ExifDateParser)
9. **Clean up utilities** (Step 11: supporting infrastructure)
10. **Final polish** (Steps 12-13: CompositionOverlay, consistency)

**Key Strategy**: High-risk steps are split into smaller, safer increments with foundation utilities created first.

---

## Risk Mitigation

### Low-Risk Steps (Safe - Mostly Documentation)
- **Steps 1, 2, 4, 12**: Models documentation and minor changes
- **Step 7**: Foundation utility (no logic changes)
- **Step 7a**: Documentation and path detection only
- **Step 8**: Foundation utilities (no logic changes)
- **Step 10**: Minor improvements to date parser

### Medium-Risk Steps (Moderate - Structural Changes)
- **Steps 3, 5, 6**: Model refactoring and service improvements
- **Step 8a**: Extract reading logic (isolated change)
- **Step 9**: CropEngine validation and documentation
- **Step 11**: Utilities consolidation

### Medium-High Risk Steps (Careful Testing Required)
- **Step 7b**: JPEGService process execution refactor
- **Step 8b**: MetadataService writing refactor
- **Step 8c**: MetadataService final cleanup

### Mitigation Strategy
1. **Foundation First**: Create utilities (Steps 7, 8) before using them
2. **Incremental Changes**: Split complex services into multiple steps
3. **Test After Each Step**: Full testing checklist required
4. **Git Strategy**:
   - Keep commits small and focused (one per step)
   - Create feature branch: `refactor/clean-code`
   - Tag after successful step completion
   - Always have working main branch to fall back to
5. **Rollback Plan**: Each step is independently revertible

---

## Success Criteria

Refactoring is successful when:

✅ All code compiles without warnings
✅ All manual tests pass
✅ No regressions in functionality
✅ Code is more readable and maintainable
✅ All comments are in English
✅ All public APIs are documented
✅ Error handling is consistent
✅ Code duplication is minimized
✅ Single Responsibility Principle is applied
✅ Dependencies are properly managed

---

## Post-Refactoring Benefits

After completion, the codebase will have:

1. ✅ **Better Maintainability**: Easier to understand and modify
2. ✅ **Improved Testability**: Clearer separation of concerns
3. ✅ **Consistent Style**: Uniform documentation and error handling
4. ✅ **English Documentation**: Accessible to wider developer community
5. ✅ **Reduced Complexity**: Smaller, focused methods and classes
6. ✅ **Better Error Messages**: Clearer debugging and user feedback

---

## Notes

- View layer (SwiftUI files) is **intentionally excluded** from refactoring
- View comments will be updated to English during refactoring steps
- External dependencies (jpegtran, exiftool) remain unchanged
- Metadata format maintains backward compatibility
- Manual testing is required after each step

---

**Last Updated**: 2025-11-30
**Estimated Total Time**: 6-10 hours (implementation + testing)
**Total Steps**: 17 (broken down from original 13 for reduced risk)

