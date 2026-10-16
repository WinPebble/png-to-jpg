#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$PackagePath='artifacts/store/ci-brand/WinPebble-PNG-to-JPG-2.0.0.0-Store-candidate.msix',
    [string]$ExpectedSHA256='1b72f3f81d54eee32c04c812420de937f38dcbd0fd980e8f5de988efe244f6fc',
    [string]$Probe='build/store/Release/Shell-Probe.exe'
)
$ErrorActionPreference='Stop'
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run from Administrator PowerShell. This script does not elevate itself.'
}
$root=Split-Path -Parent $PSScriptRoot
$PackagePath=(Resolve-Path -LiteralPath $PackagePath).Path
$Probe=(Resolve-Path -LiteralPath $Probe).Path
$originalHash=(Get-FileHash -LiteralPath $PackagePath).Hash.ToLowerInvariant()
if ($originalHash -cne $ExpectedSHA256) { throw 'Input does not match the reviewed WACK candidate SHA-256' }
$official=Get-Content (Join-Path $root 'packaging/StoreIdentity.json') -Raw | ConvertFrom-Json
if (Get-AppxPackage -Name $official.Name) { throw 'Official PNG to JPG is already installed; refusing to replace it' }
if (Get-AppxPackage -Name 'WinPebble.PNGToJPG.Dev') { throw 'Remove the development test package first to avoid COM registration ambiguity' }
$sdk=Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Directory |
    Where-Object { (Test-Path (Join-Path $_.FullName 'x64/makeappx.exe')) -and (Test-Path (Join-Path $_.FullName 'x64/signtool.exe')) } |
    Sort-Object Name -Descending | Select-Object -First 1
if (!$sdk) { throw 'Windows SDK MakeAppx and SignTool required' }
$makeappx=Join-Path $sdk.FullName 'x64/makeappx.exe'
$signtool=Join-Path $sdk.FullName 'x64/signtool.exe'
$out=Join-Path $root ('artifacts/store/deployment-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $out | Out-Null
$layout=Join-Path $out 'update-layout'
& $makeappx unpack /p $PackagePath /d $layout
if ($LASTEXITCODE) { throw 'Cannot unpack reviewed candidate' }
[xml]$manifest=Get-Content -LiteralPath (Join-Path $layout 'AppxManifest.xml')
foreach ($field in 'Name','Publisher') {
    if ($manifest.Package.Identity.GetAttribute($field) -cne $official.$field) { throw "Identity mismatch: $field" }
}
if ($manifest.Package.Identity.Version -cne '2.0.0.0' -or (Test-Path (Join-Path $layout 'AppxSignature.p7x'))) { throw 'Expected unsigned 2.0.0.0 candidate' }
$binaryHashes=@{}
foreach ($name in 'WinPebble.PNGToJPG.exe','WinPebble.PNGToJPG.Shell.dll') {
    $binaryHashes[$name]=(Get-FileHash -LiteralPath (Join-Path $layout $name)).Hash
}
$baseline=@(Get-AppxPackage -Name '*WinPebble*' | Select-Object Name,PackageFullName)
$result=[ordered]@{ Passed=$false; Input=$PackagePath; InputSHA256=$originalHash; Package=$official.Name; BinaryHashes=$binaryHashes; UpdateVersion='2.0.0.1'; Scope='local signed deployment, not Store delivery'; Steps=@(); CleanupErrors=@() }
$cert=$null
$ownsPackage=$false
$trustPath=$null
$ownsTrust=$false
$initial=Join-Path $out 'LOCAL-TEST-ONLY-2.0.0.0.msix'
$update=Join-Path $out 'LOCAL-TEST-ONLY-2.0.0.1.msix'
Copy-Item -LiteralPath $PackagePath -Destination $initial
function Assert-Installed([string]$Version) {
    $p=Get-AppxPackage -Name $official.Name
    if (!$p -or [string]$p.Version -cne $Version -or $p.PackageFamilyName -cne $official.PackageFamilyName -or $p.IsDevelopmentMode -or [string]$p.Status -ne 'Ok') { throw "Installed package state mismatch at $Version" }
    foreach ($name in $binaryHashes.Keys) {
        if ((Get-FileHash -LiteralPath (Join-Path $p.InstallLocation $name)).Hash -cne $binaryHashes[$name]) { throw "Installed payload changed: $name" }
    }
    & (Join-Path $root 'tests/Shell-Test.ps1') -Probe $Probe -Registered | Out-Host
    if (!$?) { throw 'Registered shell test failed' }
    return $p
}
try {
    # Non-exportable temporary leaf key. Never export a PFX or add a root CA.
    $cert=New-SelfSignedCertificate -Type Custom -Subject $official.Publisher -KeyUsage DigitalSignature -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -KeyExportPolicy NonExportable -CertStoreLocation 'Cert:\CurrentUser\My' -NotAfter (Get-Date).AddDays(2) -FriendlyName 'WinPebble PNG to JPG temporary deployment test' -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3','2.5.29.19={text}')
    $result.CertificateThumbprint=$cert.Thumbprint
    $result | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $out 'report.json')
    $public=Join-Path $out 'temporary-public.cer'
    Export-Certificate -Cert $cert -FilePath $public | Out-Null
    $trustPath='Cert:\LocalMachine\TrustedPeople\'+$cert.Thumbprint
    if (Test-Path -LiteralPath $trustPath) { throw 'New certificate unexpectedly already trusted' }
    $ownsTrust=$true
    Import-Certificate -FilePath $public -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' | Out-Null
    $manifest.Package.Identity.SetAttribute('Version','2.0.0.1')
    $manifest.Save((Join-Path $layout 'AppxManifest.xml'))
    # Repack only changes the package version; binaries retain candidate metadata.
    & $makeappx pack /d $layout /p $update
    if ($LASTEXITCODE) { throw 'Update clone packing failed' }
    foreach ($file in $initial,$update) {
        & $signtool sign /fd SHA256 /sha1 $cert.Thumbprint /s My $file
        if ($LASTEXITCODE) { throw 'Local test signing failed' }
        & $signtool verify /pa $file
        if ($LASTEXITCODE) { throw 'Signed clone verification failed' }
    }
    $result.SignedCloneHashes=@(Get-FileHash -LiteralPath $initial,$update | Select-Object Path,Hash)
    # Set ownership before deployment so a partially successful install is cleaned.
    $ownsPackage=$true
    Add-AppxPackage -Path $initial
    $p=Assert-Installed '2.0.0.0'
    $result.InitialPackageFullName=$p.PackageFullName
    $result.Steps+= 'Signed install + installed binary hashes + registered COM conversion PASS'
    $state=Join-Path $env:LOCALAPPDATA ('Packages\'+$p.PackageFamilyName+'\LocalState')
    New-Item -ItemType Directory -Force -Path $state | Out-Null
    $marker=Join-Path $state 'deployment-test.txt'
    $markerValue=[guid]::NewGuid().ToString('N')
    $markerValue | Set-Content -LiteralPath $marker
    Add-AppxPackage -Path $update
    $p=Assert-Installed '2.0.0.1'
    $result.UpdatedPackageFullName=$p.PackageFullName
    if ((Get-Content -LiteralPath $marker -Raw).Trim() -cne $markerValue) { throw 'Update did not preserve LocalState' }
    $result.Steps+= 'Signed update + unchanged binaries + registered COM conversion + LocalState retention PASS'
    Remove-AppxPackage -Package $p.PackageFullName
    if (Get-AppxPackage -Name $official.Name) { throw 'Uninstall left a package registration' }
    & $Probe --registered --contract
    if ($LASTEXITCODE -eq 0) { throw 'COM activation unexpectedly survives package uninstall' }
    $result.Steps+= 'Uninstall + package absence + COM activation removal PASS'
    foreach ($other in $baseline) {
        $current=Get-AppxPackage -Name $other.Name
        if (!$current -or $other.PackageFullName -notin @($current.PackageFullName)) { throw "Other installed package changed: $($other.Name)" }
    }
    if ((Get-FileHash -LiteralPath $PackagePath).Hash.ToLowerInvariant() -cne $originalHash) { throw 'Original unsigned CI package changed' }
    $result.Passed=$true
} catch {
    $result.Error=$_.Exception.Message
    throw
} finally {
    # Attempt each cleanup independently and retain evidence if any fails.
    if ($ownsPackage) {
        try {
            $left=Get-AppxPackage -Name $official.Name
            if ($left) {
                if ($left.Publisher -cne $official.Publisher -or [string]$left.Version -notin '2.0.0.0','2.0.0.1') { throw 'Unexpected package state; refusing cleanup' }
                Remove-AppxPackage -Package $left.PackageFullName
            }
            if (Get-AppxPackage -Name $official.Name) { throw 'Test package remains installed' }
        } catch { $result.CleanupErrors+= $_.Exception.Message }
    }
    if ($cert) {
        try { if ($ownsTrust -and (Test-Path -LiteralPath $trustPath)) { Remove-Item -LiteralPath $trustPath -Force }; if ($ownsTrust -and (Test-Path -LiteralPath $trustPath)) { throw 'Test trust certificate remains' } } catch { $result.CleanupErrors+= $_.Exception.Message }
        try { Remove-Item -LiteralPath ('Cert:\CurrentUser\My\'+$cert.Thumbprint) -DeleteKey -Force } catch { $result.CleanupErrors+= $_.Exception.Message }
    }
    if ($result.CleanupErrors.Count) { $result.Passed=$false }
    $result | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $out 'report.json')
    Write-Host "Deployment report: $out\report.json"
    Write-Host "Passed: $($result.Passed); cleanup errors: $($result.CleanupErrors.Count). Local test MSIX files must never be submitted."
}
if (!$result.Passed) { throw 'Deployment validation or cleanup failed; inspect report.json' }
