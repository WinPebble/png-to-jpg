#requires -Version 5.1
[CmdletBinding()]
param([switch]$ValidateOnly)
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$payload=Join-Path $root 'payload'
$statePath=Join-Path $root 'session.json'
$identity='WinPebble.PNGToJPG.Dev'

# Verify the complete payload before registration or execution.
$inventory=Get-Content (Join-Path $root 'payload-hashes.json') -Raw | ConvertFrom-Json
foreach ($entry in $inventory) {
    $path=[IO.Path]::GetFullPath((Join-Path $root $entry.Path))
    if (!$path.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid inventory path' }
    if ((Get-FileHash -LiteralPath $path).Hash -ine $entry.SHA256) { throw "Payload hash mismatch: $($entry.Path)" }
}
[xml]$manifest=Get-Content -LiteralPath (Join-Path $payload 'AppxManifest.xml')
if ($manifest.Package.Identity.Name -cne $identity -or
    $manifest.Package.Identity.Publisher -cne 'CN=WinPebble PNG to JPG Development' -or
    $manifest.Package.Identity.Version -cne '2.0.1.1' -or
    $manifest.Package.Dependencies.TargetDeviceFamily.MinVersion -cne '10.0.19041.0') { throw 'Unexpected development manifest' }
if ($ValidateOnly) { Write-Host 'Kit payload hashes and development manifest PASS; no registration performed.'; return }

$os=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$build=[int]$os.CurrentBuild
if (![Environment]::Is64BitOperatingSystem -or ![Environment]::Is64BitProcess -or $build -lt 19041 -or $build -ge 22000) {
    throw 'Use 64-bit Windows PowerShell on Windows 10 build 19041 or later. This kit does not change OS settings.'
}
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Use normal PowerShell, not Administrator, to match File Explorer.' }
if (Test-Path -LiteralPath $statePath) { throw 'Existing test session: clean it with Finish-Test.ps1 -CleanupOnly, then use a fresh extracted copy for another run.' }
if (Get-AppxPackage -Name 'TrungHieuNguyen-WinPebble.WinPebblePNGtoJPG') { throw 'Official Store app already installed; use a clean Windows 10 test account/machine.' }
if (Get-AppxPackage -Name $identity) { throw 'An existing development package was found; this kit will not replace it.' }
$legacy='HKCU:\Software\Classes\SystemFileAssociations\image\shell'
$legacyVerbs=@(Get-ChildItem -LiteralPath $legacy -ErrorAction SilentlyContinue | Where-Object PSChildName -like '*.zzPNGtoJPG')
if ($legacyVerbs.Count -or (Test-Path -LiteralPath 'HKCU:\Software\Classes\SystemFileAssociations\.png\shell\OpenAI.PNGtoJPG.HighQuality')) {
    throw 'Legacy v1 menu found. Uninstall v1 first, then restart Explorer. No legacy registration was changed.'
}
$mode=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -ErrorAction SilentlyContinue
if ($mode.AllowDevelopmentWithoutDevLicense -ne 1) { throw 'Enable Developer Mode in Windows Settings first, then retry. No certificate is needed.' }

Add-Type -AssemblyName System.Drawing
$samples=Join-Path $root ('samples-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $samples | Out-Null
$names=@('sample.png','alpha.png',(([string][char]0x1ea3)+'nh.png'))
$fixtures=@()
foreach ($name in $names) {
    $path=Join-Path $samples $name
    $bitmap=New-Object Drawing.Bitmap(320,180,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics=[Drawing.Graphics]::FromImage($bitmap)
        try {
            if ($name -eq 'alpha.png') { $graphics.Clear([Drawing.Color]::Transparent) }
            else { $graphics.Clear([Drawing.Color]::CornflowerBlue) }
        } finally { $graphics.Dispose() }
        $bitmap.Save($path,[Drawing.Imaging.ImageFormat]::Png)
    } finally { $bitmap.Dispose() }
    $fixtures+=@{ Path=$path; SHA256=(Get-FileHash -LiteralPath $path).Hash }
}
$state=[ordered]@{ Passed=$false; Build=$build; UBR=$os.UBR; DisplayVersion=$os.DisplayVersion; Layout=$payload;
    Samples=$samples; Sources=$fixtures; RegistrationAttempted=$true; RegisteredProbePassed=$false; CleanupPassed=$false }
$state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath
try {
    Add-AppxPackage -Register (Join-Path $payload 'AppxManifest.xml')
    $package=Get-AppxPackage -Name $identity
    if (!$package -or $package.InstallLocation.TrimEnd('\') -ine $payload.TrimEnd('\')) { throw 'Installed layout mismatch' }
    & (Join-Path $root 'Shell-Test.ps1') -Probe (Join-Path $root 'Shell-Probe.exe') -Registered
    $state.RegisteredProbePassed=$true
    $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath
} catch {
    $state.Error=$_.Exception.Message
    $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath
    Write-Host 'Test failed. Run Finish-Test.ps1 -CleanupOnly to remove only this kit registration.'
    throw
}
Write-Host "Open this folder in File Explorer: $samples"
Write-Host 'Select all three PNGs, right-click, choose Convert PNG to JPG. Repeat once on sample.png.'
Write-Host 'Check there is one command for PNGs and none for a JPG-only selection. Save a screenshot.'
Write-Host 'Then run Finish-Test.ps1 -MenuVerified. If the menu failed, run Finish-Test.ps1 -CleanupOnly.'
