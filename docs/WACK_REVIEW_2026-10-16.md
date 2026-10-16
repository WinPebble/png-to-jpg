# WACK review — 2026-10-16

The user ran WACK as Administrator against CI package SHA-256 `55ab496a603d550db7381baec5c7fd5efa786f0757a9c53c0d017f923bca2f9f`, source `e3e7fc2b8bb8dddafce5e8b7267d2a2e4ee2f438`.

WACK version 10.0.26100.7705; Windows 11 build 26300; APP_TYPE Centennial; full run, not partial. Invocation exit code 0 means report completion, not that every test passed. Actual XML OVERALL_RESULT is **WARNING**: 24 tests, 22 PASS, one optional FAIL and one required WARNING. The tested EXE/DLL SHA-256 entries match the CI binaries. The temporary official/development registrations are absent after the script cleanup.

## Required warning: DPIAwarenessValidation

WACK reports that the EXE lacks PerMonitorV2 in its Win32 application manifest and does not call a DPI-awareness API. Fixed by embedding `resources/app.manifest` as resource #1 with PerMonitorV2, legacy true/pm fallback, and explicit non-elevated asInvoker/uiAccess=false. Both direct MSVC and CMake builds use this manifest; the linker-generated default is disabled. Binary verification extracts the real compiled manifest with SDK mt.exe and validates DPI/UAC settings, preventing recurrence.

Conversion pixel dimensions and encoding are unaffected. Local metadata/manifest checks, smoke tests, shell launch and full package verification pass after the fix. A new CI package must be re-tested with WACK; the earlier XML is not evidence that the revised package passed.

## Optional failure: Blocked executables

The only message flags `WinPebble.PNGToJPG.Shell.dll` importing `kernel32.dll!CreateProcessW`. This is the intentional thin-shell handoff to the adjacent `WinPebble.PNGToJPG.exe`, which is included in the same package. Code passes an explicit application path and selected PNG paths, uses no command interpreter, downloads no executable and performs conversion outside the shell process.

The report marks this test OPTIONAL=TRUE. Microsoft's [Desktop Bridge test guidance](https://learn.microsoft.com/en-us/windows/uwp/debug-test-perf/windows-desktop-bridge-app-tests) states that optional tests are informational and that the blocked-executable warning may be ignored when the target is part of the application. Retain this finding and its justification for reviewer/certification notes. Do not hide the import or change architecture just to evade the detector. This review does not claim Store certification or Windows S mode compatibility.

## Next validation

Re-run WACK on the exact post-fix CI package, verify that DPIAwarenessValidation becomes PASS, and review every required result. The optional process-launch finding may remain and must be reported accurately. Signed deployment and final main-commit release gates remain outstanding; no merge, upload or publication is authorized.
