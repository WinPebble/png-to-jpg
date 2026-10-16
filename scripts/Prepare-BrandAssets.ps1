#requires -Version 5.1
# Deterministic brand derivatives from approved WinPebble pebble mark. Build time only.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
$source=Join-Path $root 'branding\WinPebble-Pebble-Mark-512.png'
$assets=Join-Path $root 'packaging\Assets'
$resources=Join-Path $root 'branding'
$ico=Join-Path $resources 'WinPebble.ico'
$expected='482baafeac1a7c9814c5556c8a18b6c9c3aa204531261f319b6efa2902ba63a3'
if(-not (Test-Path -LiteralPath $source)){throw 'Official WinPebble mark missing.'}
if((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expected){
  throw 'Official mark SHA-256 mismatch. Revert the source or obtain brand approval.'
}
foreach($folder in @($assets,$resources)){New-Item -ItemType Directory -Force -Path $folder|Out-Null}
Add-Type -AssemblyName System.Drawing

function Get-PngBytes([System.Drawing.Image]$image,[int]$size) {
  $bitmap=[System.Drawing.Bitmap]::new($size,$size,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {
    $graphics=[System.Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.Clear([System.Drawing.Color]::Transparent)
      $graphics.CompositingQuality=[System.Drawing.Drawing2D.CompositingQuality]::HighQuality
      $graphics.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $graphics.DrawImage($image,[System.Drawing.Rectangle]::new(0,0,$size,$size))
    } finally {$graphics.Dispose()}
    $stream=[System.IO.MemoryStream]::new()
    try {$bitmap.Save($stream,[System.Drawing.Imaging.ImageFormat]::Png);return ,([byte[]]$stream.ToArray())}
    finally {$stream.Dispose()}
  } finally {$bitmap.Dispose()}
}

$src=[System.Drawing.Bitmap]::FromFile($source)
try {
  if($src.Width -ne 512 -or $src.Height -ne 512){throw 'Incorrect icon master size.'}
  foreach($item in @(
    @{name='Square44x44Logo.png';size=44},
    @{name='Square150x150Logo.png';size=150},
    @{name='StoreLogo.png';size=50}
  )){
    [byte[]]$bytes=Get-PngBytes $src ([int]$item.size)
    [System.IO.File]::WriteAllBytes((Join-Path $assets $item.name),$bytes)
  }
  # ICO = ICONDIR + 7 ICONDIRENTRY records + native PNG frames, Windows 11 compatible.
  $frames=[System.Collections.Generic.List[object]]::new()
  foreach($size in @(16,24,32,48,64,128,256)){
    [byte[]]$bytes=Get-PngBytes $src $size
    $frames.Add([pscustomobject]@{Size=$size;Data=$bytes})
  }
  $stream=[System.IO.File]::Open($ico,[System.IO.FileMode]::Create,[System.IO.FileAccess]::Write)
  $writer=[System.IO.BinaryWriter]::new($stream)
  try {
    $writer.Write([ushort]0);$writer.Write([ushort]1);$writer.Write([ushort]$frames.Count)
    $offset=6+16*$frames.Count
    foreach($frame in $frames){
      $writer.Write([byte]($frame.Size % 256));$writer.Write([byte]($frame.Size % 256))
      $writer.Write([byte]0);$writer.Write([byte]0)
      $writer.Write([ushort]1);$writer.Write([ushort]32)
      $writer.Write([uint32]$frame.Data.Length);$writer.Write([uint32]$offset)
      $offset+=$frame.Data.Length
    }
    foreach($frame in $frames){$writer.Write([byte[]]$frame.Data)}
  }finally{$writer.Dispose();$stream.Dispose()}
}finally{$src.Dispose()}
if((Get-Item $ico).Length -lt 1000){throw 'Generated application icon is suspiciously small.'}
Write-Host 'PASS: branded MSIX tiles and multi-resolution EXE icon from official mark.' -ForegroundColor Green

Copy-Item -LiteralPath $ico -Destination (Join-Path $assets 'Command.ico') -Force

