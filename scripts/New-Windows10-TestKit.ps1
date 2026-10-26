[CmdletBinding()]
param([Parameter(Mandatory)][string]$Layout,[Parameter(Mandatory)][string]$Probe)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$Layout=(Resolve-Path -LiteralPath $Layout).Path
$Probe=(Resolve-Path -LiteralPath $Probe).Path
[xml]$manifest=Get-Content -LiteralPath (Join-Path $Layout 'AppxManifest.xml')
if ($manifest.Package.Identity.Name -cne 'WinPebble.PNGToJPG.Dev' -or
    $manifest.Package.Identity.Version -cne '2.0.1.1' -or
    $manifest.Package.Identity.Publisher -cne 'CN=WinPebble PNG to JPG Development' -or
    $manifest.Package.Dependencies.TargetDeviceFamily.MinVersion -cne '10.0.19041.0') { throw 'Expected Windows 10 development layout' }
& (Join-Path $root 'tests/Verify-Binary.ps1') -ExePath (Join-Path $Layout 'WinPebble.PNGToJPG.exe')
& (Join-Path $root 'tests/Verify-Binary.ps1') -ExePath (Join-Path $Layout 'WinPebble.PNGToJPG.Shell.dll')
$out=Join-Path $root 'artifacts/windows10-test'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$kit=Join-Path $out ('WinPebble-PNG-to-JPG-2.0.1-Win10-Test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $kit | Out-Null
$payload=Join-Path $kit 'payload'
New-Item -ItemType Directory -Path $payload | Out-Null
foreach ($name in 'WinPebble.PNGToJPG.exe','WinPebble.PNGToJPG.Shell.dll','AppxManifest.xml') {
    Copy-Item -LiteralPath (Join-Path $Layout $name) -Destination $payload
}
Copy-Item -LiteralPath (Join-Path $Layout 'Assets') -Destination $payload -Recurse
Copy-Item -LiteralPath $Probe -Destination (Join-Path $kit 'Shell-Probe.exe')
Copy-Item -LiteralPath (Join-Path $root 'tests/Shell-Test.ps1') -Destination $kit
foreach ($name in 'Begin-Test.ps1','Finish-Test.ps1','README-TEST-WIN10.md') {
    Copy-Item -LiteralPath (Join-Path $root ('tests/windows10/'+$name)) -Destination $kit
}
$files=@(Get-ChildItem -LiteralPath $payload -Recurse -File)+@(Get-Item (Join-Path $kit 'Shell-Probe.exe'),(Join-Path $kit 'Shell-Test.ps1'))
$hashes=@($files | ForEach-Object { @{ Path=$_.FullName.Substring($kit.Length+1); SHA256=(Get-FileHash -LiteralPath $_.FullName).Hash } })
$hashes | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $kit 'payload-hashes.json')
$zip=$kit+'.zip'
Compress-Archive -Path (Join-Path $kit '*') -DestinationPath $zip
Get-FileHash -LiteralPath $zip | Format-List
Write-Host "Test kit: $zip"
Write-Host 'Do not upload this development kit to Partner Center. No package was installed.'
