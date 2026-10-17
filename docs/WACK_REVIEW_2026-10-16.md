# WACK review — 2026-10-16

The user ran WACK as Administrator against CI package SHA-256 `55ab496a603d550db7381baec5c7fd5efa786f0757a9c53c0d017f923bca2f9f`, source `e3e7fc2b8bb8dddafce5e8b7267d2a2e4ee2f438`.

WACK version 10.0.26100.7705; Windows 11 build 26300; APP_TYPE Centennial; full run, not partial. Invocation exit code 0 means report completion, not that every test passed. Actual XML OVERALL_RESULT is **WARNING**: 24 tests, 22 PASS, one optional FAIL and one required WARNING. The tested EXE/DLL SHA-256 entries match the CI binaries. The temporary official/development registrations are absent after the script cleanup.

## Required warning: DPIAwarenessValidation

WACK reports that the EXE lacks PerMonitorV2 in its Win32 application manifest and does not call a DPI-awareness API. Fixed by embedding `resources/app.manifest` as resource #1 with PerMonitorV2, legacy true/pm fallback, and explicit non-elevated asInvoker/uiAccess=false. Both direct MSVC and CMake builds use this manifest; the linker-generated default is disabled. Binary verification extracts the real compiled manifest with SDK mt.exe and validates DPI/UAC settings, preventing recurrence.

Conversion pixel dimensions and encoding are unaffected. Local metadata/manifest checks, smoke tests, shell launch and full package verification pass after the fix. A new CI package must be re-tested with WACK; the earlier XML is not evidence that the revised package passed.

## Optional failure: Blocked executables

The only message flags `WinPebble.PNGToJPG.Shell.dll` importing `kernel32.dll!CreateProcessW`. This is the intentional thin-shell handoff to the adjacent `WinPebble.PNGToJPG.exe`, which is included in the same package. Code passes an explicit application path and selected PNG paths, uses no command interpreter, downloads no executable and performs conversion outside the shell process.

The report marks this test OPTIONAL=TRUE. Microsoft's [Desktop Bridge test guidance](https://learn.microsoft.com/en-us/windows/uwp/debug-test-perf/windows-desktop-bridge-app-tests) states that optional tests are informational and that the blocked-executable warning may be ignored when the target is part of the application. Retain this finding and its justification for reviewer/certification notes. Do not hide the import or change architecture just to evade the detector. This review does not claim Store certification or Windows S mode compatibility.

## Follow-up runs

The second user run tested post-fix CI package SHA-256
`a55d2297532f0dc8f42f77fb4bc2c960b6c94978289dc578fb7a991fac809ec8`.
It still reports 22 PASS, required DPI WARNING and optional CreateProcessW FAIL.
Inventory EXE/DLL hashes match the revised package, but the DPI message points
to the previous run's `layout-9665094f9329438bb78e15d96d27086d`, whereas the
new inventory root is `layout-ec7dcbd5d86d4159985b65efb489a89b`. This is evidence
of a retained finding, not proof that the revised manifest is absent. The script
previously omitted `appcert.exe reset`; it now follows Microsoft's documented
reset/test sequence and records the layout and reset in invocation evidence.
Do not declare DPI PASS until a fresh report confirms it. Shared logo sizes and
scale were also aligned byte-for-byte with PDF Page Duplicator in this revision;
re-test the newly built package after both changes.

The third full user run, after reset, tested source
`5fe39357385874ffb53e7fc9347b93b48f7ffead`, CI Store run
[38870036763](https://github.com/WinPebble/png-to-jpg/actions/runs/38870036763),
package SHA-256 `1b72f3f81d54eee32c04c812420de937f38dcbd0fd980e8f5de988efe244f6fc`.
Report `wack-33ce8c8f70a74317a05e3c2166af83ff.xml` has overall **PASS**, not
partial, 23/24 tests PASS and zero required non-PASS. DPIAwarenessValidation
is PASS. The only optional FAIL remains Blocked executables/CreateProcessW,
with its message now pointing to the correct current layout. Report inventory
hashes match the exact CI EXE/DLL:

- EXE: `233fec63752b71bdad7f52e00c76855e619239c3cf8897df2674d7fdf542532c`.
- DLL: `314d70ba633eb499e186fe8ef38f9c4de569c282dcd237809c718ba4f82fd9af`.

The local WACK checkpoint is passed with the documented optional finding.
Signed deployment and final main-commit release gates remain outstanding;
no merge, upload or publication is authorized. Local WACK PASS does not imply
Microsoft Store certification.
