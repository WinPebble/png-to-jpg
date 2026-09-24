param(
    [Parameter(Position=0, ValueFromRemainingArguments=$true)]
    [string[]]$Paths
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function Get-UniqueJpgPath {
    param([string]$SourcePath)

    $dir = [System.IO.Path]::GetDirectoryName($SourcePath)
    $base = [System.IO.Path]::GetFileNameWithoutExtension($SourcePath)
    $candidate = Join-Path $dir ($base + ".jpg")

    if (-not (Test-Path -LiteralPath $candidate)) {
        return $candidate
    }

    $i = 1
    do {
        $candidate = Join-Path $dir ("{0}_{1}.jpg" -f $base, $i)
        $i++
    } while (Test-Path -LiteralPath $candidate)

    return $candidate
}

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
    Where-Object { $_.MimeType -eq "image/jpeg" } |
    Select-Object -First 1

if (-not $jpegCodec) {
    throw "Windows JPEG encoder was not found."
}

$encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$qualityParam = New-Object System.Drawing.Imaging.EncoderParameter(
    [System.Drawing.Imaging.Encoder]::Quality,
    [long]100
)
$encoderParams.Param[0] = $qualityParam

foreach ($path in $Paths) {
    if ([string]::IsNullOrWhiteSpace($path)) { continue }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    if ([System.IO.Path]::GetExtension($path) -notmatch '^\.(png)$') { continue }

    $source = $null
    $bitmap = $null
    $graphics = $null

    try {
        $source = [System.Drawing.Image]::FromFile($path)

        $bitmap = New-Object System.Drawing.Bitmap(
            $source.Width,
            $source.Height,
            [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
        )

        try {
            if ($source.HorizontalResolution -gt 0 -and $source.VerticalResolution -gt 0) {
                $bitmap.SetResolution($source.HorizontalResolution, $source.VerticalResolution)
            }
        } catch {}

        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([System.Drawing.Color]::White)
        $graphics.DrawImageUnscaled($source, 0, 0)

        $output = Get-UniqueJpgPath -SourcePath $path
        $bitmap.Save($output, $jpegCodec, $encoderParams)
    }
    catch {
        # Silent when launched from Explorer.
    }
    finally {
        if ($graphics) { $graphics.Dispose() }
        if ($bitmap) { $bitmap.Dispose() }
        if ($source) { $source.Dispose() }
    }
}

$qualityParam.Dispose()
$encoderParams.Dispose()
