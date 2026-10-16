# Gate B — compiled core development validation

Status: technical validation PASS locally and in CI; user approved visual quality on 2026-10-16 and authorized Gate C. This is not a v2.0.0 release or a Store package.

## CI evidence

- Source commit `e7007fb4e1bc4e38fbd0ff64658f88b5f608430f`.
- Push build: https://github.com/WinPebble/png-to-jpg/actions/runs/38848900855 — PASS.
- PR build: https://github.com/WinPebble/png-to-jpg/actions/runs/38848906774 — PASS.
- Artifact: `WinPebble-PNG-to-JPG-v2-GateB-win-x64`, containing EXE, SHA256SUMS, SOURCE_COMMIT and measured report.json.
- CI EXE SHA-256 `2eb9c796bd0d5c8a7b253754271986acec8d5718036db1061b19ed79cab3f626`.
- Downloaded push artifact was hash-verified and passed metadata + smoke checks on the local Windows 11 machine.
- Earlier d059b0d builds failed because starter macros were defined twice under /WX; fixed at the source, with green independent CMake builds above.

## Local evidence

- Windows 11 x64 build 26300; MSVC 19.44; static /MT runtime; SDK 26100; /W4 /WX.
- ProductName `WinPebble PNG to JPG`, ProductVersion `2.0.0-dev.1`, FileVersion `2.0.0.1`; PE machine 0x8664.
- SHA-256 of local EXE: see `GATE_B_LOCAL_RESULTS.json` and local artifacts/SHA256SUMS.txt. CI EXE may have a different hash; use CI artifact hash for its provenance.
- Smoke test and tests/gate_b.py pass. Detailed measured size/time/memory and RMSE in `GATE_B_LOCAL_RESULTS.json`.
- 13 v1 comparisons: equal output byte counts and decoded RGB RMSE 0. Includes sRGB ICC, gAMA, 16-bit gray/RGB/gray-alpha/RGBA and a detail pattern.
- Small fixture peak working sets approximately 10.8–12.1 MiB in v2 versus 79–81 MiB including PowerShell in v1. Times include startup and are single observations, not statistical performance guarantees.
- 24 MP stress: 0.121 seconds, peak working set 13,344,768 bytes. Our row buffers are bounded; this is not a global WIC memory bound for every image type.

## Coverage

Single and multiple inputs; transparent and partially transparent pixels; indexed palette transparency; gray; 16-bit; dimensions and DPI; Unicode, spaces, nested and >260-character paths; read-only input; source SHA-256 unchanged; eight concurrent invocations after existing (2) produce (3)..(10); existing JPG bytes unchanged; JPEG quality verified from DQT tables.

Corrupt data, JPEG mislabeled as PNG, truncated PNG chunks, missing file, non-PNG extension, mixed success/failure batch, no arguments; permission denied in a dedicated test directory (ACL restored in finally); final rename failure due to filename component limit after collision; no leftover temporary files.

## Known scope and remaining approval

- User approved quality on 2026-10-16. Synthetic pixel equality was supporting evidence; the approval came directly from the user.
- Windows 10 and earlier Windows 11 builds are untested. This core gate does not establish modern Explorer menu, install/uninstall or MSIX support.
- Pipeline intentionally follows v1 raw RGB behavior: no ICC conversion/preservation or gamma correction. sRGB ICC/gAMA fixtures pass parity; arbitrary wide-gamut profiles and camera/photo corpus still need visual review.
- Chunk CRC validation is not a complete independent PNG/DEFLATE conformance validator. WIC may recover malformed compressed data whose chunks/CRCs are valid. Abrupt process termination or external interference can defeat best-effort cleanup; ordinary tested error paths clean up.
- Disk-full and forced process termination are not covered. No dev certificate, installer, service, shell registration or Store identity was created.

## Reproduce

Run from repository root:

```powershell
./tests/Build-Local.ps1
./tests/Verify-Binary.ps1
./tests/Smoke-Test.ps1 -ExePath "$PWD/build/Release/WinPebble.PNGToJPG.exe"
python -m pip install Pillow==11.3.0
python tests/gate_b.py --exe build/Release/WinPebble.PNGToJPG.exe
```

Pillow and Python are test-only dependencies. End users need only the EXE and Windows built-in DLLs. The baseline test uses process-scoped PowerShell execution policy for the inspected historical script and changes no machine policy. Test evidence and images are kept in a unique .work directory; it never deletes a pre-existing test directory.

## Next gate

Gate C is authorized and tracked in GATE_C_VALIDATION.md. Gate D requires exact PNG-to-JPG Partner Center identity. Merge, Store submission and publication each remain subject to explicit user confirmation.
