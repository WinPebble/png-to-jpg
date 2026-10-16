# Gate D — Store candidate preparation

Status: candidate CI/build/package checks PASS. User WACK run completed with WARNING; DPI fix prepared and re-test pending. This gate is NOT complete and upload is NOT approved. See [WACK review](WACK_REVIEW_2026-10-16.md).

## Identity and source

The user supplied a Partner Center application overview screenshot on 2026-10-16. It shows **WinPebble PNG to JPG**, MSIX/PWA app, **In draft**. Exact values are recorded in [StoreIdentity.json](../packaging/StoreIdentity.json):

- Store ID: `9NZC26K97WTT`.
- Identity Name: `TrungHieuNguyen-WinPebble.WinPebblePNGtoJPG`.
- Publisher: `CN=6BD09250-A4F3-4F78-9DA7-2D9751735950`.
- PublisherDisplayName: `Trung Hieu Nguyen - WinPebble`.
- PFN: `TrungHieuNguyen-WinPebble.WinPebblePNGtoJPG_e12w2zdycyz0a`.

The publisher is the same developer account as PDF to Image; these values were independently supplied for PNG to JPG. The product name, package name, PFN and Store ID are separate. No public listing or certification is claimed.

## Candidate lanes

Development retains `WinPebble.PNGToJPG.Dev`, package/binary file version `2.0.0.1`, ProductVersion `2.0.0-dev.1`.

Store uses the exact official identity and numeric package/file version `2.0.0.0`, ProductVersion `2.0.0-rc.1`. This is an unreleased candidate, not a released semantic v2.0.0. CMake option `WINPEBBLE_STORE_CANDIDATE=ON` selects candidate metadata for both EXE and DLL; conversion implementation is shared. The minimal help launch exits successfully after dismissal; --quiet without inputs still returns usage error 2.

The full Store MSIX contains only the EXE, shell DLL, manifest and shared WinPebble artwork. There is no sparse/external content, certificate, script, self-signature, service or startup task. Store workflow is isolated from development and uses no signing/upload credentials.

Target: Windows 11 x64, MinVersion 10.0.22000.0, actual local validation build 26300. Windows 10 remains excluded until separate validation. `runFullTrust` is required for the packaged Win32 core to read selected local PNG files and create sibling JPG files through the Explorer command. No elevation, telemetry, network upload or background service is implemented.

## Verified locally

- x64 EXE/DLL candidate metadata; static MSVC runtime.
- Single/multi, Unicode, alpha, dimensions, collisions, errors/cleanup, original hashes, 24 MP stress and measured v1 comparison.
- Shell contract and launch tests against candidate binaries.
- MakeAppx full package schema validation; exact official identity, case, PNG-only CLSID registration and capability.
- Exact allowed payload, shared brand asset bytes, x64 PE headers, all 64 KiB block SHA-256 hashes and optional full-file hashes. No AppxSignature.p7x or certificate material.
- Temporary registration of the full official layout on Windows confirmed the exact PFN above and successful registered COM single/multi conversion. The registration was removed immediately afterward. This does not establish signed MSIX installation or Store delivery.
- No v1 source/tag/release or legacy/classic-menu preference changed in this gate.

## WACK and release blockers

The first automated WACK attempt was blocked by Windows requiring elevation. The user subsequently ran the prepared script as Administrator against the exact CI package. The completed report has overall WARNING: 22 PASS, one optional CreateProcessW FAIL and one required DPI-awareness WARNING. The DPI warning is fixed in source and compiled-manifest verification; a new WACK report on the revised CI package is required. No certificate trust was performed.

`scripts/Test-Store-WACK.ps1` is prepared for an elevated PowerShell session on the existing Developer Mode test machine. It temporarily registers an official full layout, runs WACK by package full name, preserves the report and removes that registration in finally. It refuses to replace an installed official package. It does not sign/trust certificates, change Developer Mode, or modify legacy menus. A generated report must be reviewed test-by-test before declaring PASS.

Signed MSIX install/update/uninstall validation, WACK review, any required fixes, user review and an authorized PR merge remain outstanding. Final submission artifacts must be rebuilt by successful CI from the exact approved main commit after merge. Branch CI artifacts are review candidates only. No upload, submission, certification request, merge or publishing has occurred.

## Reproduce

```powershell
./tests/Build-Local.ps1 -OutputDirectory build/store/Release -StoreCandidate
./scripts/Build-Shell-Local.ps1 -OutputDirectory build/store/Release -StoreCandidate
./scripts/Build-Store-MSIX.ps1
python tests/verify_dev_package.py artifacts/store/WinPebble-PNG-to-JPG-2.0.0.0-Store-candidate.msix --store
# From an Administrator PowerShell, after reviewing the candidate layout:
$layout=(Get-Content artifacts/store/build-provenance.json -Raw | ConvertFrom-Json).Layout
./scripts/Test-Store-WACK.ps1 -Layout $layout
# Prefer testing the exact downloaded CI package:
./scripts/Test-Store-WACK.ps1 -PackagePath 'path/to/WinPebble-PNG-to-JPG-2.0.0.0-Store-candidate.msix'
```

Official references: [Store package requirements](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/app-package-requirements), [WACK CLI](https://learn.microsoft.com/en-us/windows/uwp/debug-test-perf/windows-app-certification-kit).
