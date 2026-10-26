param([string]$BinaryDirectory='build/Release')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$output=Join-Path $root 'artifacts/gate-c'
New-Item -ItemType Directory -Force $output | Out-Null
# A unique full layout: never overwrite a registered or previous test layout.
$stage=Join-Path $output ('layout-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $stage | Out-Null
foreach ($name in 'WinPebble.PNGToJPG.exe','WinPebble.PNGToJPG.Shell.dll') {
    Copy-Item -LiteralPath (Join-Path $BinaryDirectory $name) -Destination $stage
}
Copy-Item -LiteralPath (Join-Path $root 'packaging/Assets') -Destination $stage -Recurse
Copy-Item -LiteralPath (Join-Path $root 'packaging/AppxManifest.Dev.xml') -Destination (Join-Path $stage 'AppxManifest.xml')
$sdk=Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName 'x64/makeappx.exe') } |
    Sort-Object Name -Descending | Select-Object -First 1
if (!$sdk) { throw 'Windows SDK MakeAppx not found' }
$msix=Join-Path $output 'WinPebble-PNG-to-JPG-2.0.1-dev.1-unsigned.msix'
& (Join-Path $sdk.FullName 'x64/makeappx.exe') pack /d $stage /p $msix /o
if ($LASTEXITCODE) { throw 'MakeAppx validation/pack failed' }
@{ Layout=$stage; Package=$msix; Identity='WinPebble.PNGToJPG.Dev' } | ConvertTo-Json | Set-Content (Join-Path $output 'layout.json')
Get-FileHash $msix,(Join-Path $stage 'WinPebble.PNGToJPG.exe'),(Join-Path $stage 'WinPebble.PNGToJPG.Shell.dll') |
    ForEach-Object { $_.Hash.ToLower()+'  '+[IO.Path]::GetFileName($_.Path) } | Set-Content (Join-Path $output 'SHA256SUMS.txt')
Write-Host "Full unsigned DEV MSIX: $msix"
Write-Host "Development registration layout: $stage"
