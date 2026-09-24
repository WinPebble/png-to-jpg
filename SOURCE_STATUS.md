# Source status

## v1.0.0 — Verified

The original public release asset has now been verified.

Release asset:

`WinPebble-PNG-to-JPG.zip`

Release SHA-256:

`5e9ba8c06d43ac2bf8a3dd5557d843246e6af7dbe4ee1c29bde3cfcf0c842d00`

The package supplied for source verification produced the same SHA-256 as the
asset recorded by GitHub for release `v1.0.0`.

The exact files from that package are preserved under [`src/`](src/).

## Verified implementation

The release uses:

- PowerShell-based PNG conversion.
- .NET / `System.Drawing`.
- JPEG quality 100.
- A 24-bit RGB output bitmap with a white background, so transparent PNG areas become white.
- Original image pixel width and height.
- Output in the same directory as the source PNG.
- Collision-safe filenames such as `_1`, `_2`, and so on.
- Per-user Windows Registry integration under `HKEY_CURRENT_USER`.
- Installation files stored under `%LOCALAPPDATA%\PNGtoJPG`.
- A File Explorer menu label of **Convert PNG to JPG**.
- No background service.
- No network operation in the conversion, installation, or uninstall scripts.

## Known v1.0.0 implementation note

Conversion errors launched from File Explorer are intentionally caught without
showing an error message. This behavior is preserved as part of the historical
`v1.0.0` source.

A future release should improve user-visible error handling rather than
rewriting the published historical source.
