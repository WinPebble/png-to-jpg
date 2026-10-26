# Store update 2.0.1 — prepared, not submitted

Product: WinPebble PNG to JPG, Store ID 9NZC26K97WTT.
Package: 2.0.1.0, x64, same identity/publisher/application ID as live 2.0.0.0.
Minimum Windows.Desktop build: 10.0.19041.0 (Windows 10 version 2004).
Price remains free; same markets, category, support and privacy URLs.
Keep manual publishing hold. No merge, upload, submission or publication is
implied by preparing this file.

## en-US description

WinPebble PNG to JPG adds a convenient command to File Explorer on Windows 10
and Windows 11. Select one or more PNG files, right-click, then choose Convert
PNG to JPG. JPG files are saved beside the originals.

Conversion runs locally on your PC. Original PNG files are preserved. If a JPG
with the same name already exists, the app creates a numbered filename instead
of replacing it. Transparent areas are filled with white, and image dimensions
are preserved. JPG uses lossy compression, so converted files are not identical
to the PNG originals.

Requires Windows 10 version 2004 or later, or Windows 11, on an x64 PC.

## Short description (unchanged)

Convert PNG images to JPG directly from Windows File Explorer.

## Features

- Convert one PNG or a batch of selected PNG files.
- Use the Windows 10 or Windows 11 File Explorer context menu. Keep original
  files and avoid replacing existing JPGs.
- Process images locally without uploading them. Work with Unicode filenames,
  including Vietnamese names.

## What's new

Added installation support for Windows 10 version 2004 or later (x64), while
retaining Windows 11 support.

## Notes for certification

Version 2.0.1 lowers the full MSIX minimum OS version from build 22000 to build
19041. The native converter and IExplorerCommand implementation are unchanged.
The PNG-only shell extension launches WinPebble.PNGToJPG.exe included in the
same package. runFullTrust is required to read the selected local PNGs and write
sibling JPG files. It uses an explicit executable path, not a command interpreter
or a downloaded program. Conversion runs outside Explorer and does not require
administrator elevation. No account or credentials are required.

To test, select one or several PNG files in a writable File Explorer folder,
right-click and choose Convert PNG to JPG. PNG sources remain unchanged;
existing JPGs receive numbered alternatives; transparent areas become white.
Launching without selected files shows usage help.

Windows 11 local build, conversion, direct COM and MSIX integrity checks passed.
Additional manual Windows 10, WACK and signed lifecycle runs were not performed
for this update at the owner's explicit request. Prior 2.0.0 reports must not be
presented as results for this package. The known optional CreateProcessW finding
is explained in WACK_REVIEW_2026-10-16.md; the launch code is unchanged.

## Submission steps after owner approval

1. Merge the reviewed PR, build the approved main commit via the Store workflow,
   download that exact unsigned candidate and record SHA-256/provenance.
2. Start an update to the existing Store product. Upload only the 2.0.1.0 Store
   candidate, never the Dev kit or LOCAL-TEST-ONLY packages.
3. Update en-US copy above. Retain current screenshots/branding, free pricing,
   existing age ratings if all IARC answers remain unchanged, and Desktop only.
4. Confirm Don't publish until I select Publish now. Review all portal fields
   before an explicitly authorized certification submission. Publication is a
   separate owner decision.
