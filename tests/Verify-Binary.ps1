param([string]$ExePath = 'build/Release/WinPebble.PNGToJPG.exe',[switch]$StoreCandidate)
$ErrorActionPreference='Stop'
$v=(Get-Item -LiteralPath $ExePath).VersionInfo
$productVersion=if ($StoreCandidate) { '2.0.0-rc.1' } else { '2.0.0-dev.1' }
$fileVersion=if ($StoreCandidate) { '2.0.0.0' } else { '2.0.0.1' }
if ($v.ProductName -ne 'WinPebble PNG to JPG' -or $v.ProductVersion -ne $productVersion -or $v.FileVersion -ne $fileVersion) { throw 'Unexpected binary metadata' }
$bytes=[IO.File]::ReadAllBytes((Resolve-Path $ExePath))
$pe=[BitConverter]::ToInt32($bytes,0x3c)
if ([BitConverter]::ToUInt16($bytes,$pe+4) -ne 0x8664) { throw 'Expected x64 PE' }
if ([IO.Path]::GetExtension($ExePath) -eq '.exe') {
    $sdk=Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName 'x64/mt.exe') } |
        Sort-Object Name -Descending | Select-Object -First 1
    if (!$sdk) { throw 'Windows SDK mt.exe required to verify the embedded manifest' }
    $evidence=Join-Path $PSScriptRoot '../.work'
    New-Item -ItemType Directory -Force $evidence | Out-Null
    $extracted=Join-Path $evidence ('manifest-'+[guid]::NewGuid().ToString('N')+'.xml')
    & (Join-Path $sdk.FullName 'x64/mt.exe') -nologo ("-inputresource:"+(Resolve-Path $ExePath).Path+';#1') ("-out:"+$extracted)
    if ($LASTEXITCODE) { throw 'Cannot extract the embedded EXE manifest' }
    [xml]$win32Manifest=Get-Content -LiteralPath $extracted
    $dpi=$win32Manifest.SelectSingleNode("//*[local-name()='dpiAwareness']")
    $level=$win32Manifest.SelectSingleNode("//*[local-name()='requestedExecutionLevel']")
    if (!$dpi -or $dpi.InnerText -cne 'PerMonitorV2' -or !$level -or $level.level -cne 'asInvoker' -or $level.uiAccess -cne 'false') {
        throw 'EXE must embed PerMonitorV2 and non-elevated asInvoker'
    }
}
$v | Select-Object ProductName,ProductVersion,FileVersion
Get-FileHash -LiteralPath $ExePath -Algorithm SHA256
