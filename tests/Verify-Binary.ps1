param([string]$ExePath = 'build/Release/WinPebble.PNGToJPG.exe',[switch]$StoreCandidate)
$ErrorActionPreference='Stop'
$v=(Get-Item -LiteralPath $ExePath).VersionInfo
$productVersion=if ($StoreCandidate) { '2.0.0-rc.1' } else { '2.0.0-dev.1' }
$fileVersion=if ($StoreCandidate) { '2.0.0.0' } else { '2.0.0.1' }
if ($v.ProductName -ne 'WinPebble PNG to JPG' -or $v.ProductVersion -ne $productVersion -or $v.FileVersion -ne $fileVersion) { throw 'Unexpected binary metadata' }
$bytes=[IO.File]::ReadAllBytes((Resolve-Path $ExePath))
$pe=[BitConverter]::ToInt32($bytes,0x3c)
if ([BitConverter]::ToUInt16($bytes,$pe+4) -ne 0x8664) { throw 'Expected x64 PE' }
$v | Select-Object ProductName,ProductVersion,FileVersion
Get-FileHash -LiteralPath $ExePath -Algorithm SHA256
