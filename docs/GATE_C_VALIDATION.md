# Gate C — native Explorer command development validation

User approved Gate B quality and authorized Gate C on 2026-10-16.
Status: local Windows 11 end-to-end development registration PASS. CI build/contract/package validation is tracked by the draft PR. This is not Store certification or a public v2.0.0 release.

## Architecture

`File Explorer -> packaged COM surrogate -> WinPebble.PNGToJPG.Shell.dll -> CreateProcessW -> WinPebble.PNGToJPG.exe`

The static-runtime x64 DLL exposes IExplorerCommand and a class factory. It reads selection metadata, supplies the title/icon, and starts the adjacent core using an explicit executable path. No decoding, conversion, process waiting or network operations run in the DLL. C++ exceptions are contained at COM methods that allocate. COM references and server locks govern unloading.

- New PNG-specific CLSID: `331934D2-2EAD-4A03-8FF9-FEFF310D45BB`.
- Development identity: `WinPebble.PNGToJPG.Dev`, publisher `CN=WinPebble PNG to JPG Development`, version `2.0.0.1`, x64.
- Manifest associates only `.png`, uses a COM surrogate and `runFullTrust` for the packaged Win32 core. No sparse/external content, services or startup tasks.
- Windows 11 development target MinVersion `10.0.22000.0`; actual local UI test build is 26300. The floor does not establish testing on every Windows 11 build.
- Approved existing v1 artwork is reused for the shell icon and package images. No PDF-to-Image identity or artwork is reused.

## Verified locally

MSVC x64 /MT, C++20, /W4 /WX; shell metadata `WinPebble PNG to JPG / 2.0.0-dev.1 / 2.0.0.1`. MakeAppx schema validation and full payload packing succeed. `tests/verify_dev_package.py` verifies exact development identity, PNG-only CLSID association, capability and unsigned payload without certificate files or scripts.

`tests/Shell-Test.ps1` passes with direct DLL activation and with registered out-of-process COM activation: title, canonical ID, class factory lifetime/unload behavior, null/invalid parameters, no aggregation, single/multiple PNGs, Unicode/spaces, collision, unchanged source hashes. Non-PNG, mixed selection and directories are hidden/rejected.

Actual File Explorer UI testing via the computer-use skill on Windows 11 build 26300:

1. Modern context menu displays exactly one **Convert PNG to JPG** with the approved icon.
2. Single PNG invocation produces `alpha sample.jpg` without a success notification.
3. Selecting two PNGs in one invocation produces `alpha sample (2).jpg` and `ảnh tiếng Việt.jpg`.
4. TXT modern context menu does not show the command.
5. No converter remains running after success; source pixels, dimensions and deterministic source bytes are verified.
6. Unregister removes the dev package and COM activation. The modern PNG menu no longer shows the command. The exact registered test layout, including app files, is removed while PNG/JPG test images remain.

Detailed local evidence: [GATE_C_LOCAL_RESULTS.json](GATE_C_LOCAL_RESULTS.json). Local EXE/DLL/MSIX hashes are in `artifacts/gate-c/SHA256SUMS.txt`; CI artifacts have their own hashes and SOURCE_COMMIT.

## Migration and machine state

Existing v1 `HKCU\Software\Classes\SystemFileAssociations\image\shell\edit.zzPNGtoJPG` was detected. The user explicitly authorized its backup and temporary hiding. Only a `LegacyDisable` value was added; no historical scripts, icons, release or tag were removed. Unregistration restored the value state and retained the `.reg` backup locally.

This machine also had a classic-menu override at `HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}`. The user separately authorized backup, temporary disabling, Explorer restart, and restoration. Modern menu was tested with that override disabled; afterward the exact key was restored, Explorer restarted, and no temporary backup key remained. These machine-specific backups are ignored development artifacts and are not uploaded to CI/GitHub.

The existing Developer Mode setting was read, not changed. Testing used `Add-AppxPackage -Register` against the **full payload layout**. No signing certificate was created or trusted. The final machine state has v1 menu and classic-menu preference restored, with no PNG-to-JPG development package installed.

## Reproduce from source

```powershell
./tests/Build-Local.ps1
./scripts/Build-Shell-Local.ps1
./tests/Shell-Test.ps1
./scripts/Build-Dev-MSIX.ps1
python tests/verify_dev_package.py artifacts/gate-c/WinPebble-PNG-to-JPG-2.0.0-dev.1-unsigned.msix
# On a development machine that already has Developer Mode enabled:
./scripts/Register-Dev.ps1
./tests/Shell-Test.ps1 -Registered
# Test the real PNG right-click menu, then clean up:
./scripts/Unregister-Dev.ps1 -RemoveLayout
```

Legacy hiding and classic-menu override changes are optional separate scripts and require the operator's authorization; registration does not perform them automatically. The unsigned MSIX is a development/schema artifact, not an installable Store submission. Do not double-click it expecting a signed installation. CI validates the direct DLL and full package; it does not claim an interactive Explorer test on the hosted runner.

## Limits and next gate

- Signed MSIX deployment, update, Store WACK/certification and Store-installed uninstall remain Gate D/E work. Full-layout registration is not proof of those scenarios.
- Windows 10 remains untested and is excluded by the development manifest. Classic-menu behavior on a customized Windows 11 machine is not Windows 10 validation. Fallback packaging must be evaluated on a separate Windows 10 test machine before any support claim.
- CreateProcess supports up to 32,767 command-line characters. An oversized selection fails clearly and asks for a smaller batch; no partial launch occurs. Remote shell providers and very large selections need additional testing.
- GetState reads filesystem selection metadata; it never decodes images. Offline/unavailable network shares may still be slow in the Shell metadata provider.
- Merge and public release/submission remain unauthorized. Gate D needs the exact identity of the separate PNG-to-JPG product from Partner Center.

Official integration reference: https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/integrate-packaged-app-with-file-explorer
