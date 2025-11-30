# Security Policy

## Supported Versions

We currently support the following versions with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in PhotoCropper, please follow these steps:

### How to Report

1. **DO NOT** open a public issue
2. Email the details to: [Your security contact email]
3. Include the following information:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Response Time**: We aim to respond within 48 hours
- **Updates**: We'll keep you informed about the progress
- **Credit**: We'll acknowledge your contribution in the security advisory (unless you prefer to remain anonymous)

### Security Update Process

1. We'll investigate the reported vulnerability
2. Develop and test a fix
3. Release a security patch
4. Publish a security advisory
5. Update affected users

## Security Best Practices

When using PhotoCropper:

- Always download from official sources (GitHub releases)
- Verify checksums of downloaded files
- Keep external dependencies updated (jpegtran, exiftool)
- Run the app with appropriate sandbox permissions
- Be cautious when processing images from untrusted sources

## External Dependencies

PhotoCropper uses these external tools:

- **jpegtran** (jpeg-turbo): Install via Homebrew and keep updated
- **exiftool**: Install via Homebrew and keep updated

We recommend regularly updating these dependencies:
```bash
brew update
brew upgrade jpeg-turbo exiftool
```

## Known Security Considerations

1. **External Process Execution**: PhotoCropper executes external commands (jpegtran, exiftool) via `ProcessExecutor`. These are validated and sanitized.
2. **File Access**: The app requires file system access to read and write images. It uses security-scoped resources for sandbox compatibility.
3. **Metadata Handling**: EXIF/XMP metadata is processed using exiftool. Malformed metadata could potentially cause issues.

## Disclosure Policy

- We follow responsible disclosure principles
- Security vulnerabilities will be patched before public disclosure
- We'll coordinate release timing with the reporter

## Contact

For security concerns, please contact:
- GitHub: https://github.com/cbram/photocropper/security/advisories

---

**Thank you for helping keep PhotoCropper secure!**

