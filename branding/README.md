# Shared WinPebble artwork

PNG to JPG uses the same approved mark and corresponding derivative files as
PDF Page Duplicator. Run `scripts/Prepare-BrandAssets.ps1` on Windows to regenerate
the committed assets using the same System.Drawing rendering procedure.

- Package logos: 44 × 44, 150 × 150 and Store 50 × 50 pixels.
- EXE and Explorer command ICO: 16, 24, 32, 48, 64, 128 and 256 pixel frames.
- The mark's scale, transparent margins and rendered pixels match PDF Page
  Duplicator's corresponding files, verified byte-for-byte on 2026-10-16.
- Source SHA-256: `482baafeac1a7c9814c5556c8a18b6c9c3aa204531261f319b6efa2902ba63a3`.

PDF Page Duplicator's extra 71/310 pixel assets are not referenced by PNG to JPG's
manifest and are not included in its minimal package.
