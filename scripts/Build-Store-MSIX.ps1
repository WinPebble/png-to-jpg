param([string]$BinaryDirectory='build/store/Release')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$official=Get-Content (Join-Path $root 'packaging/StoreIdentity.json') -Raw | ConvertFrom-Json
$source=Join-Path $root 'packaging/AppxManifest.Store.xml'
[xml]$manifest=Get-Content -LiteralPath $source
foreach ($field in 'Name','Publisher') {
    if ($manifest.Package.Identity.GetAttribute($field) -cne $official.$field) { throw "Official identity mismatch: $field" }
}
if ($manifest.Package.Identity.Version -cne '2.0.1.0' -or $manifest.Package.Identity.ProcessorArchitecture -cne 'x64') { throw 'Wrong Store version/architecture' }
if ($manifest.Package.Dependencies.TargetDeviceFamily.Name -cne 'Windows.Desktop' -or $manifest.Package.Dependencies.TargetDeviceFamily.MinVersion -cne '10.0.19041.0') { throw 'Expected Windows Desktop 2004+ compatibility floor' }
if ($manifest.Package.Properties.PublisherDisplayName -cne $official.PublisherDisplayName) { throw 'Official PublisherDisplayName mismatch' }
foreach ($name in 'WinPebble.PNGToJPG.exe','WinPebble.PNGToJPG.Shell.dll') {
    $binary=Join-Path $BinaryDirectory $name
    & (Join-Path $root 'tests/Verify-Binary.ps1') -ExePath $binary -StoreCandidate
    $signature=Get-AuthenticodeSignature -LiteralPath $binary
    if ($signature.SignerCertificate -and $signature.SignerCertificate.Subject -like '*Development*') { throw 'Development-signed binary in Store input' }
}
$output=Join-Path $root 'artifacts/store'
New-Item -ItemType Directory -Force $output | Out-Null
$stage=Join-Path $output ('layout-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $stage | Out-Null
foreach ($name in 'WinPebble.PNGToJPG.exe','WinPebble.PNGToJPG.Shell.dll') {
    Copy-Item -LiteralPath (Join-Path $BinaryDirectory $name) -Destination $stage
}
Copy-Item -LiteralPath (Join-Path $root 'packaging/Assets') -Destination $stage -Recurse
Copy-Item -LiteralPath $source -Destination (Join-Path $stage 'AppxManifest.xml')
if (Get-ChildItem $stage -Recurse -File | Where-Object Extension -in '.cer','.pfx','.p12','.ps1','.bat') { throw 'Unexpected development material in Store input' }
$sdk=Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName 'x64/makeappx.exe') } |
    Sort-Object Name -Descending | Select-Object -First 1
if (!$sdk) { throw 'Windows SDK MakeAppx not found' }
$msix=Join-Path $output 'WinPebble-PNG-to-JPG-2.0.1.0-Store-candidate.msix'
& (Join-Path $sdk.FullName 'x64/makeappx.exe') pack /d $stage /p $msix /o
if ($LASTEXITCODE) { throw 'Store MakeAppx validation/packing failed' }
# No SignTool, certificate generation/trust or Partner Center write in this lane.
Copy-Item -LiteralPath $source -Destination (Join-Path $output 'AppxManifest.Store.xml')
Copy-Item -LiteralPath (Join-Path $root 'packaging/StoreIdentity.json') -Destination $output
$commit=& git -C $root rev-parse HEAD
if ($LASTEXITCODE) { throw 'Cannot record source commit' }
$commit | Set-Content (Join-Path $output 'SOURCE_COMMIT.txt')
@{ Layout=$stage; Package=$msix; SourceCommit=$commit; WorkingTreeDirty=[bool](& git -C $root status --porcelain); Status='unreleased candidate; not approved for upload' } |
    ConvertTo-Json | Set-Content (Join-Path $output 'build-provenance.json')
Get-FileHash $msix,(Join-Path $stage 'WinPebble.PNGToJPG.exe'),(Join-Path $stage 'WinPebble.PNGToJPG.Shell.dll') |
    ForEach-Object { $_.Hash.ToLower()+'  '+[IO.Path]::GetFileName($_.Path) } | Set-Content (Join-Path $output 'SHA256SUMS.txt')
Write-Host "Store CANDIDATE: $msix"
Write-Host "Store ID: $($official.StoreId). Unsigned for Store; no upload, submission or release performed."
