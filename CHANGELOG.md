# Changelog

All notable changes to WinPebble PNG to JPG will be documented in this file.

The project uses semantic versioning.

## [1.0.0] - 2026-09-24

Initial public release.

### Added

- Windows File Explorer context-menu command: **Convert PNG to JPG**.
- Single-file and multi-file PNG conversion.
- JPEG output at quality 100.
- Original pixel dimensions are preserved.
- Transparent PNG areas are composited onto a white background.
- Original PNG files are preserved.
- JPG output is written beside the source PNG.
- Filename collision handling to avoid overwriting existing JPG files.
- Per-user context-menu registration without requiring Administrator privileges.
- Local processing with no telemetry or background service.

### Release asset

`WinPebble-PNG-to-JPG.zip`

SHA-256:

`5e9ba8c06d43ac2bf8a3dd5557d843246e6af7dbe4ee1c29bde3cfcf0c842d00`
