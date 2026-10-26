# Windows 10 compatibility update — 2.0.1 (unreleased)

Requested 2026-10-26. The live Store package 2.0.0.0 has MinVersion 22000,
which blocks Windows 10 installation. Candidate 2.0.1.0 lowers it to 19041
(Windows 10 version 2004), x64. This is an installation target, not a claim
that runtime testing on Windows 10 has already passed.

## Design

- Same Store name, publisher, application ID, PFN and PNG command CLSID.
- Same native WIC core and IExplorerCommand implementation; no v1 registry
  installer, extra context-menu entry or startup process is introduced.
- Windows 10 uses its normal classic Explorer menu; Windows 11 retains the
  packaged command. Verify the actual menu on each OS; a COM probe alone does
  not prove Explorer discovery or visibility.
- Store package/file version 2.0.1.0; dev 2.0.1.1. Store revision remains 0.
- uap10 RuntimeBehavior/TrustLevel require build 19041. Do not lower the floor
  further without changing and testing the activation manifest.
- Preserve all published 2.0.0.0 artifacts and historical v1 source/tag/assets.

Microsoft references (read 2026-10-26):

- https://learn.microsoft.com/en-us/uwp/schemas/appxpackage/uapmanifestschema/element-f-application
- https://learn.microsoft.com/en-us/uwp/schemas/appxpackage/uapmanifestschema/element-desktop4-fileexplorercontextmenus
- https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/integrate-packaged-app-with-file-explorer

## Required validation before Store submission

**Owner exception, 2026-10-26:** the owner explicitly requested skipping further
testing and expediting the Store update, reporting that the tool previously
worked on Windows 10. Additional Windows 10 manual, WACK and signed-deployment
runs are waived for this update. They remain NOT RUN; the prior experience is
not recorded as a test of this exact MSIX. The checklist below is retained as
the recommended validation plan, not a new requirement to block this owner's
authorized exception. Existing automated CI checks are left intact. Merge,
Store submission and publishing still require the owner's separate confirmation.

1. Build Release core/DLL/probe, verify versions, package schema/payload and block
   hashes; run Smoke-Test, Shell-Test and gate_b.py. These run on the build host
   and must not be presented as Windows 10 results.
2. On a clean Windows 10 x64 test machine (prefer 22H2/build 19045), record the
   OS build and exact candidate SHA-256. On build 19041 also test before claiming
   that oldest supported build as verified. Use matching source/scripts/probe.
3. Run WACK as Administrator on the exact candidate:
   `scripts/Test-Store-WACK.ps1 -PackagePath <absolute-msix-path>`.
   Inspect every required test and document the known optional bundled
   CreateProcessW finding. Existing reports for 2.0.0 do not cover this update.
4. On the clean test machine run `scripts/Test-SignedDeployment.ps1 -PackagePath
   <absolute-msix-path> -ExpectedSHA256 <reviewed-lowercase-sha256> -Probe
   <absolute-probe-path>` from Administrator PowerShell. The script refuses to
   replace an installed official Store app; do not bypass that guard. It creates
   and removes temporary local signing trust; never submit LOCAL-TEST-ONLY files.
5. Confirm the real Explorer menu appears for PNG only, single/batch/Unicode
   conversion, white alpha, original retention, numbered collisions and no
   duplicate legacy entries. Save genuine screenshots and OS/build evidence.
6. Regression on Windows 11: same workflow and manual menu check. Verify a real
   Store-signed 2.0.0.0 -> 2.0.1.0 update through an authorized Store test/release
   flow; local same-payload update clones do not establish that upgrade path.
7. Review PR/CI, merge only with owner confirmation, rebuild from approved main,
   and retest that exact artifact. Separately confirm upload/submission/release.

## Store listing changes when validated

Requirements: Windows 10 version 2004 or later / Windows 11, x64. Do not claim
x86, ARM64 or S mode. Replace Windows-11-only text in description, features and
certification notes with Windows 10/11 wording. Keep support/privacy links and
free pricing. Retain Windows.Desktop device family; other families disabled.
Keep manual Publish now hold. Website update belongs to its separate project.
The prepared update copy is in [STORE_UPDATE_2.0.1.md](STORE_UPDATE_2.0.1.md).

## Local results — 2026-10-26

Build host: Windows 11 build 26300.9711 (the legacy registry ProductName still
says Windows 10 Pro; build number determines the OS generation). No Windows 10
VM was available through the local Get-VM command. Windows 10 runtime results
remain **NOT RUN**, not PASS. WACK and signed lifecycle tests for this new
candidate also remain pending.

- Store and dev MSVC Release builds (/W4 /WX /MT): PASS.
- Binary versions, embedded DPI/asInvoker manifest and x64 architecture: PASS.
- MakeAppx schema/packing and exact package identity, PNG command scoping,
  capabilities, assets and all block hashes, both Store/dev lanes: PASS.
- Store core Smoke-Test and direct-DLL Shell-Test contract/launch: PASS.
- gate_b.py full hardening/v1 comparison: PASS (local Pillow 12.3.0;
  CI still pins its existing Pillow 11.3.0). Test report:
  `.work/gate-b-f076c2394b5d44288f2040c462132f39/report.json`.
- Changed PowerShell scripts parse; git diff whitespace check: PASS.

Unsigned Store artifact: `artifacts/store/WinPebble-PNG-to-JPG-2.0.1.0-Store-candidate.msix`.
SHA-256: `f06d1f16895f7ac4aad9b6c4687ace9ab2f6018e0bff38b1e4e78ff4b8b45e5d`.
Built from working changes on `codex/windows-10-support`, based on main
3983f7274f50a30cf4ed66a6c887776c1e10fea0. This is not a CI/main release artifact.
Do not double-click the unsigned MSIX expecting it to install.

The archived main 2.0.0.0 package still hashes to
`76ddb080c30b0105b75e2318c4942e65c5730e93b626c7c48c066d593ef2c3ae`.
Native conversion/shell source and historical `src/` have no changes.
No package registration, signing trust, merge, upload or Store action was done
for this compatibility update.

## Portable Windows 10 test kit

Owner confirmed access to a Windows 10 x64 machine. Generate a kit with
`scripts/New-Windows10-TestKit.ps1 -Layout <dev-layout> -Probe <dev-probe>`.
The kit contains the full Dev layout, registered COM probe, synthetic-fixture
setup/verification and narrowly scoped package cleanup. Instructions are in
`tests/windows10/README-TEST-WIN10.md` (copied into the ZIP).

It needs pre-existing Developer Mode, normal 64-bit Windows PowerShell and a
clean test account; no SDK, Python, certificates or Visual Studio on Windows 10.
The scripts never toggle Developer Mode or remove a legacy/Store install.
Begin-Test validates payload hashes and refuses an existing official/Dev app
or known legacy v1 menu; Finish-Test verifies actual manual Explorer outputs
and removes only its exact Dev version/layout. Keep session.json and do not
move the extracted kit until cleanup completes.

Local kit checks: Windows PowerShell 5.1 ValidateOnly PASS, script syntax PASS,
Windows 11 OS guard stopped before registration PASS. Windows 10 test results
are NOT RUN and further kit testing was waived by the owner. A successful kit run covers Dev registration/menu/conversion
and package removal, not signed-MSIX installation or WACK.
