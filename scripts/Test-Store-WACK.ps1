[CmdletBinding(DefaultParameterSetName='Package')]
param(
    [Parameter(Mandatory,ParameterSetName='Layout')][string]$Layout,
    [Parameter(Mandatory,ParameterSetName='Package')][string]$PackagePath,
    [string]$ReportDirectory='artifacts/store/wack'
)
$ErrorActionPreference='Stop'
$principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'WACK requires Administrator. Run this script from an elevated PowerShell session; this script does not elevate itself.'
}
$root=Split-Path -Parent $PSScriptRoot
$official=Get-Content (Join-Path $root 'packaging/StoreIdentity.json') -Raw | ConvertFrom-Json
if ($PackagePath) {
    $PackagePath=(Resolve-Path -LiteralPath $PackagePath).Path
    $sdk=Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName 'x64/makeappx.exe') } |
        Sort-Object Name -Descending | Select-Object -First 1
    if (!$sdk) { throw 'Windows SDK MakeAppx required to inspect the exact CI package' }
    $Layout=Join-Path $root ('artifacts/store/wack/layout-'+[guid]::NewGuid().ToString('N'))
    & (Join-Path $sdk.FullName 'x64/makeappx.exe') unpack /p $PackagePath /d $Layout
    if ($LASTEXITCODE) { throw 'Candidate unpack/validation failed' }
}
[xml]$manifest=Get-Content -LiteralPath (Join-Path $Layout 'AppxManifest.xml')
if ($manifest.Package.Identity.Name -cne $official.Name -or $manifest.Package.Identity.Publisher -cne $official.Publisher -or $manifest.Package.Identity.Version -cne $official.PackageVersion) { throw 'Layout official identity mismatch' }
if (Get-AppxPackage -Name $official.Name) { throw 'An official package is already installed; use a separate clean test session rather than replacing it' }
$mode=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -ErrorAction SilentlyContinue
if ($mode.AllowDevelopmentWithoutDevLicense -ne 1) { throw 'Full-layout WACK testing requires an existing Developer Mode test machine. No Windows settings or certificates are changed by this script.' }
$wack="${env:ProgramFiles(x86)}\Windows Kits\10\App Certification Kit\appcert.exe"
if (!(Test-Path -LiteralPath $wack)) { throw 'Windows App Certification Kit not found' }
if (Get-Process appcert -ErrorAction SilentlyContinue) { throw 'Another WACK session is running' }
$reports=[IO.Path]::GetFullPath((Join-Path $root $ReportDirectory))
New-Item -ItemType Directory -Force $reports | Out-Null
$xmlReport=Join-Path $reports ('wack-'+[guid]::NewGuid().ToString('N')+'.xml')
$registered=$null
$ownsRegistration=$false
try {
    # Registered full payload avoids signing or trusting the unsigned Store candidate.
    Add-AppxPackage -Register (Join-Path $Layout 'AppxManifest.xml')
    $ownsRegistration=$true
    $registered=Get-AppxPackage -Name $official.Name
    if (!$registered -or $registered.PackageFamilyName -cne $official.PackageFamilyName) { throw 'Registered PFN mismatch' }
    & $wack test -packagefullname $registered.PackageFullName -reportoutputpath $xmlReport
    $exitCode=$LASTEXITCODE
    $hash=if ($PackagePath) { (Get-FileHash -LiteralPath $PackagePath).Hash.ToLower() } else { $null }
    @{ ExitCode=$exitCode; Report=$xmlReport; Package=$registered.PackageFullName; SourcePackageSHA256=$hash; Mode='registered full layout; no certificate' } |
        ConvertTo-Json | Set-Content (Join-Path $reports 'invocation.json')
    if ($exitCode -ne 0 -or !(Test-Path -LiteralPath $xmlReport)) { throw 'WACK did not complete successfully; inspect its log and invocation.json. This is not a PASS.' }
    Write-Host "WACK report: $xmlReport. Review every test result; report generation alone is not a PASS."
} finally {
    if ($ownsRegistration) {
        $cleanup=Get-AppxPackage -Name $official.Name
        if ($cleanup) {
            if ([IO.Path]::GetFullPath($cleanup.InstallLocation) -cne [IO.Path]::GetFullPath($Layout)) { throw 'Installed package changed externally; refusing to remove it' }
            Remove-AppxPackage -Package $cleanup.PackageFullName -ErrorAction Stop
        }
    }
}
