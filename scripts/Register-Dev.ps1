param([string]$Layout)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if (!$Layout) { $Layout=(Get-Content (Join-Path $root 'artifacts/gate-c/layout.json') -Raw | ConvertFrom-Json).Layout }
$manifest=Join-Path $Layout 'AppxManifest.xml'
[xml]$xml=Get-Content -LiteralPath $manifest
if ($xml.Package.Identity.Name -ne 'WinPebble.PNGToJPG.Dev' -or $xml.Package.Identity.Publisher -ne 'CN=WinPebble PNG to JPG Development') {
    throw 'Not the PNG-to-JPG DEVELOPMENT identity'
}
$mode=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -ErrorAction SilentlyContinue
if ($mode.AllowDevelopmentWithoutDevLicense -ne 1) { throw 'Developer Mode must already be enabled for layout registration. This script does not change Windows settings.' }
if (Get-AppxPackage -Name 'WinPebble.PNGToJPG.Dev') { throw 'Existing PNG-to-JPG development package found. Unregister it before a new test.' }
# Full payload layout, not a sparse package. Does not trust a certificate or
# change existing v1 registration; that separate migration needs authorization.
Add-AppxPackage -Register $manifest -ErrorAction Stop
$package=Get-AppxPackage -Name 'WinPebble.PNGToJPG.Dev'
if (!$package) { throw 'Development registration was not found after Add-AppxPackage' }
@{ PackageFullName=$package.PackageFullName; InstallLocation=$package.InstallLocation; Layout=$Layout } |
    ConvertTo-Json | Set-Content (Join-Path $root 'artifacts/gate-c/registration.json')
$package | Select-Object Name,PackageFullName,InstallLocation
