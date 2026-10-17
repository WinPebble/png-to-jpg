# Store listing draft — WinPebble PNG to JPG

Local preparation only. No Partner Center changes, upload or publication.

Owner asked to continue on 2026-10-17 after reviewing the proposed settings.
Prepare the listing as free, Utilities + tools, en-US, all available markets,
with this repository's Issues support URL and the app-specific privacy draft.
These are preparation settings; merge, upload, certification submission and
publication still require separate confirmation. No automatic release is set.

## English listing text

Short description:

Convert PNG images to JPG directly from Windows File Explorer.

Description:

WinPebble PNG to JPG adds a convenient command to Windows 11 File Explorer.
Select one or more PNG files, right-click, then choose Convert PNG to JPG.
JPG files are saved beside the originals.

Conversion runs locally on your PC. Original PNG files are preserved. If a JPG
with the same name already exists, the app creates a numbered filename instead
of replacing it. Transparent areas are filled with white, and image dimensions
are preserved. JPG uses lossy compression, so converted files are not identical
to the PNG originals.

Features:

- Convert one PNG or a batch of selected PNG files.
- Use the Windows 11 File Explorer context menu.
- Keep original files and avoid replacing existing JPGs.
- Work with Unicode filenames, including Vietnamese names.
- Process images locally without uploading them.

Requirements: Windows 11, x64. No Windows 10, ARM64 or Windows S mode support
claim is made by this candidate.

## Certification notes draft

The app is a packaged Win32 image utility. Its PNG-only IExplorerCommand shell
extension launches WinPebble.PNGToJPG.exe included in the same full MSIX. The
runFullTrust capability is needed to read selected local PNG files and write
sibling JPG output files. The shell passes an explicit executable path; it does
not invoke a command interpreter or download executables. Conversion runs outside
the Explorer process. Normal use does not require elevation.

To test: create a PNG in a writable folder, right-click it in File Explorer and
choose Convert PNG to JPG. Repeat with multiple selected PNGs. Original files
remain unchanged. Existing JPGs receive numbered alternatives. Launching the app
without selected files shows usage help; the main workflow is the Explorer menu.

Local WACK on the reviewed branch candidate returned overall PASS, with all
required tests PASS. The optional Blocked executables result flags CreateProcessW
for the bundled converter launch described above. See WACK_REVIEW_2026-10-16.md.

## Items still to supply or approve

- Price: **Free**, explicitly confirmed by the owner on 2026-10-16.
- Proposed support URL: https://github.com/WinPebble/png-to-jpg/issues. GitHub API
  confirmed this repository is public and Issues is enabled on 2026-10-16.
- Privacy draft: [PRIVACY.md](../PRIVACY.md), adapted to this tool's actual PNG/JPG
  behavior from PDF to Image and PDF Page Duplicator policies. Do not link another
  tool's policy as if it covers this app. Intended main-branch URL after authorized
  merge: https://github.com/WinPebble/png-to-jpg/blob/main/PRIVACY.md. That future
  URL is not yet verified as available. PDF Duplicator's local preparation record
  says its portal accepted policy text directly; recheck the PNG product's actual
  form before relying on this alternative.
- Proposed category: Utilities + tools; initial listing language: English (en-US).
  These match PDF Duplicator's documented preparation. Vietnamese can be added
  with separately reviewed translated listing text.
- Proposed availability: public, all available markets, matching PDF Duplicator's
  documented final audience/worldwide setting. This is a draft recommendation,
  not authorization to make the product public or set automatic publication.
- Age-rating questionnaire answers based on the final product.
- Product screenshots from the final approved package, showing Explorer command,
  batch output and collision behavior with the shared WinPebble branding.
- Any current Partner Center-required declarations and release timing.

These are draft texts, not a completed submission. Final screenshots and package
hashes must refer to the approved main-commit build after authorized merge.

Reference evidence was read from sibling repositories on 2026-10-16:
`pdf-to-image/PRIVACY.md`, `pdf-page-duplicator/docs/PRIVACY.md`,
`pdf-page-duplicator/docs/STORE_PRIVATE_PREPARATION.md` (en-US, Utilities + tools,
policy-text option) and `pdf-page-duplicator/docs/STORE_SUBMISSION_READY.md`
(support tracker, free/worldwide/public). These are historical local records;
their contents do not verify current live Partner Center settings or authorize
copying another project's release approvals.
