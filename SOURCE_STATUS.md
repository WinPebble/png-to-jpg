# Source status

## v1.0.0

The `v1.0.0` release asset was published before the GitHub repository was standardized.

Known implementation characteristics of the final release include:

- PowerShell-based conversion.
- .NET / `System.Drawing` image processing.
- Per-user Windows Registry context-menu registration.
- No Administrator permission required for normal installation.
- Multi-file selection support.
- JPEG quality 100.
- PNG transparency composited onto a white background.
- Source PNG files preserved.
- Output written beside the source file.
- Existing JPG files are not overwritten.
- File Explorer menu label: **Convert PNG to JPG**.

However, the exact original script contents of the already-published `v1.0.0`
package have not yet been verified against the release asset.

For transparency, reconstructed code is intentionally not being committed as
the historical source of `v1.0.0`.

Once the original scripts are verified, they can be added under `src/` and
this notice can be updated.
