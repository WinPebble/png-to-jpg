# Source for PNG to JPG v1.0.0

This directory contains the files extracted from the published
`WinPebble-PNG-to-JPG.zip` release asset for `v1.0.0`.

The release package was verified by SHA-256 before these files were added:

`5e9ba8c06d43ac2bf8a3dd5557d843246e6af7dbe4ee1c29bde3cfcf0c842d00`

The historical files are preserved without modifying their implementation.

## Files

- `ConvertPNGtoJPG.ps1` — PNG-to-JPG conversion logic.
- `Install_or_Update.ps1` — per-user installation and File Explorer context-menu registration.
- `Uninstall.ps1` — removes the context-menu registration and installed local files.
- `UPDATE_MENU.bat` — launcher for installation/update.
- `UNINSTALL.bat` — launcher for uninstallation.
- `README.txt` — README included in the original release package.
- `user_icon.ico` — context-menu icon used by the release.
- `user_icon_preview.png` — preview image included in the release package.
- `SHA256SUMS.txt` — SHA-256 hashes for the files in this directory.

## Historical note

The original package README calls this build “v8 (short label)”. That was an
internal development/build label. The public WinPebble release is versioned
as `v1.0.0`.
