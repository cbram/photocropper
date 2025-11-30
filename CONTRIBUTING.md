# Contributing to PhotoCropper

Thank you for your interest in contributing to PhotoCropper! We welcome contributions from the community.

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with:
- A clear, descriptive title
- Steps to reproduce the problem
- Expected behavior vs. actual behavior
- Your macOS version and Xcode version
- Screenshots if applicable

### Suggesting Features

Feature requests are welcome! Please:
- Check if the feature has already been requested
- Provide a clear description of the feature
- Explain why it would be useful
- Include mockups or examples if possible

### Pull Requests

1. **Fork the repository**
   ```bash
   git clone https://github.com/cbram/photocropper.git
   cd photocropper
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow the existing code style
   - Write clear, concise commit messages
   - Add comments for complex logic
   - Update documentation if needed

4. **Test your changes**
   - Build and run the app
   - Test all affected features manually
   - Verify no existing functionality is broken

5. **Commit your changes**
   ```bash
   git add .
   git commit -m "Add: Brief description of your changes"
   ```

6. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Submit a pull request**
   - Provide a clear description of the changes
   - Reference any related issues
   - Include test scenarios you've verified

## Code Style Guidelines

### Swift Coding Standards

- **Naming Conventions**
  - Types: PascalCase (`ImageService`, `CropSettings`)
  - Functions/Variables: camelCase (`calculateCropSize`, `targetRatio`)
  - Constants: camelCase with `k` prefix for global constants

- **Documentation**
  - Use triple-slash comments (`///`) for documentation
  - Document all public APIs with Swift DocC markup
  - Include parameter descriptions and return values

- **Error Handling**
  - Use `Result<Success, Failure>` for operations that can fail
  - Never use force unwrapping (`!`) in production code

### Language

**All code, comments, and documentation must be in English.**

## Testing

Please test manually after every change:
- Load and crop different image formats (JPEG, HEIC, PNG, TIFF)
- Test batch operations
- Verify metadata preservation

## Getting Help

- Check existing [Issues](https://github.com/cbram/photocropper/issues)
- Review CLAUDE.md and REFACTORING_PLAN.md

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
