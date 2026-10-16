param([switch]$RemoveLayout)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$package=Get-AppxPackage -Name 'WinPebble.PNGToJPG.Dev'
$layout=if ($package) { $package.InstallLocation } else { $null }
if ($package) { $package | Remove-AppxPackage -ErrorAction Stop }
if (Get-AppxPackage -Name 'WinPebble.PNGToJPG.Dev') { throw 'Package still registered' }
if ($RemoveLayout -and $layout) {
    $allowed=[IO.Path]::GetFullPath((Join-Path $root 'artifacts/gate-c')).TrimEnd('\')+'\'
    $resolved=[IO.Path]::GetFullPath($layout).TrimEnd('\')
    if (!$resolved.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolved) -notmatch '^layout-[a-f0-9]{32}$') { throw 'Refusing to delete layout outside the dedicated build directory' }
    [xml]$manifest=Get-Content -LiteralPath (Join-Path $resolved 'AppxManifest.xml')
    if ($manifest.Package.Identity.Name -ne 'WinPebble.PNGToJPG.Dev') { throw 'Layout identity mismatch' }
    if ((Get-Item -LiteralPath $resolved).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Layout is a reparse point' }
    if (Get-ChildItem -LiteralPath $resolved -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw 'Layout contains a reparse point' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
    if (Test-Path -LiteralPath $resolved) { throw 'Layout cleanup incomplete' }
}
& (Join-Path $PSScriptRoot 'Set-LegacyMenu.ps1') -Action Restore
Write-Host 'Development package unregistered; legacy menu restored if this test changed it.'
Write-Host 'Test images retained. Layout removed only when explicitly requested. No certificate was installed.'
