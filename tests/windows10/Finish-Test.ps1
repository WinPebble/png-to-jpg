#requires -Version 5.1
[CmdletBinding(DefaultParameterSetName='Verify')]
param(
    [Parameter(Mandatory,ParameterSetName='Verify')][switch]$MenuVerified,
    [Parameter(Mandatory,ParameterSetName='Cleanup')][switch]$CleanupOnly
)
$ErrorActionPreference='Stop'
$statePath=Join-Path $PSScriptRoot 'session.json'
if (!(Test-Path -LiteralPath $statePath)) { throw 'No owned test session found; nothing removed.' }
$state=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
$payload=Join-Path $PSScriptRoot 'payload'
if ($state.Layout.TrimEnd('\') -ine $payload.TrimEnd('\')) { throw 'Keep the kit at its original extracted location until cleanup.' }
$failure=$null
try {
    if (!$CleanupOnly) {
        if (!$state.RegisteredProbePassed) { throw 'Registered COM probe did not pass' }
        Add-Type -AssemblyName System.Drawing
        foreach ($source in $state.Sources) {
            if ((Get-FileHash -LiteralPath $source.Path).Hash -ine $source.SHA256) { throw 'Original PNG changed' }
            $jpg=[IO.Path]::ChangeExtension($source.Path,'.jpg')
            $bitmap=New-Object Drawing.Bitmap($jpg)
            try {
                if ($bitmap.Width -ne 320 -or $bitmap.Height -ne 180) { throw 'Wrong output dimensions' }
                if ([IO.Path]::GetFileName($source.Path) -eq 'alpha.png') {
                    $pixel=$bitmap.GetPixel(2,2)
                    if ($pixel.R -lt 235 -or $pixel.G -lt 235 -or $pixel.B -lt 235) { throw 'Alpha background not white' }
                }
            } finally { $bitmap.Dispose() }
        }
        if (!(Test-Path -LiteralPath (Join-Path $state.Samples 'sample (2).jpg'))) { throw 'Numbered collision output missing' }
        if (Get-ChildItem -LiteralPath $state.Samples -Filter '*.tmp') { throw 'Temporary output left behind' }
        $state | Add-Member NoteProperty ManualMenuVerified $true -Force
        $state.Passed=$true
    }
} catch { $failure=$_.Exception.Message; $state.Passed=$false; $state | Add-Member NoteProperty Error $failure -Force }
finally {
    # Only remove the exact development registration this kit attempted to create.
    try {
        $package=Get-AppxPackage -Name 'WinPebble.PNGToJPG.Dev'
        if ($package) {
            if ($package.InstallLocation.TrimEnd('\') -ine $payload.TrimEnd('\') -or
                [string]$package.Version -cne '2.0.1.1' -or
                $package.Publisher -cne 'CN=WinPebble PNG to JPG Development') { throw 'Unexpected development registration; refusing cleanup' }
            Remove-AppxPackage -Package $package.PackageFullName
        }
        if (Get-AppxPackage -Name 'WinPebble.PNGToJPG.Dev') { throw 'Development package still registered' }
        $state.CleanupPassed=$true
    } catch { $state.Passed=$false; $failure=$_.Exception.Message; $state | Add-Member NoteProperty CleanupError $failure -Force }
    $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath
    $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'WIN10-RESULT.json')
}
Write-Host "Result: $PSScriptRoot\WIN10-RESULT.json"
Write-Host "Passed: $($state.Passed); cleanup: $($state.CleanupPassed). Samples and kit files retained."
if ($failure) { throw $failure }
