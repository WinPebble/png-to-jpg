param(
    [Parameter(Mandatory = $true)]
    [string]$ExePath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ExePath)) {
    throw "Executable not found: $ExePath"
}

Add-Type -AssemblyName System.Drawing

$root = Join-Path (Join-Path $PSScriptRoot '../.work') ("WinPebble-PNGToJPG-Gate1-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $root | Out-Null

function Save-OpaquePng([string]$Path, [int]$Width, [int]$Height) {
    $bmp = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $g.Clear([System.Drawing.Color]::FromArgb(255, 30, 120, 220))
        }
        finally {
            $g.Dispose()
        }
        $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bmp.Dispose()
    }
}

function Save-AlphaPng([string]$Path, [int]$Width, [int]$Height) {
    $bmp = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $g.Clear([System.Drawing.Color]::Transparent)
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(160, 220, 40, 40))
            try {
                $g.FillRectangle($brush, 20, 20, $Width - 40, $Height - 40)
            }
            finally {
                $brush.Dispose()
            }
        }
        finally {
            $g.Dispose()
        }
        $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bmp.Dispose()
    }
}

function Invoke-Converter([string[]]$Paths, [int]$ExpectedExitCode) {
    $argsList = @("--quiet")
    foreach ($p in $Paths) {
        $argsList += ('"' + $p + '"')
    }

    $proc = Start-Process -FilePath $ExePath -ArgumentList $argsList -Wait -PassThru -WindowStyle Hidden -RedirectStandardError (Join-Path $root "stderr.txt")
    if ($proc.ExitCode -ne $ExpectedExitCode) {
        throw "Unexpected exit code. Expected $ExpectedExitCode, got $($proc.ExitCode). $(Get-Content (Join-Path $root 'stderr.txt') -Raw)"
    }
}

function Assert-ImageSize([string]$Path, [int]$Width, [int]$Height) {
    if (-not (Test-Path $Path)) {
        throw "Expected output missing: $Path"
    }

    $img = [System.Drawing.Image]::FromFile($Path)
    try {
        if ($img.Width -ne $Width -or $img.Height -ne $Height) {
            throw "Dimension mismatch for $Path. Got $($img.Width)x$($img.Height), expected ${Width}x${Height}."
        }
    }
    finally {
        $img.Dispose()
    }
}

try {
    $opaque = Join-Path $root "opaque.png"
    $alpha = Join-Path $root "alpha.png"
    $unicodeDir = Join-Path $root "Thư mục thử nghiệm"
    New-Item -ItemType Directory -Path $unicodeDir | Out-Null
    $unicode = Join-Path $unicodeDir "ảnh tiếng Việt.png"

    Save-OpaquePng $opaque 320 180
    Save-AlphaPng $alpha 200 140
    Save-OpaquePng $unicode 77 55

    $sourceHashesBefore = @{
        $opaque = (Get-FileHash $opaque -Algorithm SHA256).Hash
        $alpha = (Get-FileHash $alpha -Algorithm SHA256).Hash
        $unicode = (Get-FileHash $unicode -Algorithm SHA256).Hash
    }

    Write-Host "TEST: multi-file conversion + Unicode"
    Invoke-Converter @($opaque, $alpha, $unicode) 0

    $opaqueJpg = Join-Path $root "opaque.jpg"
    $alphaJpg = Join-Path $root "alpha.jpg"
    $unicodeJpg = Join-Path $unicodeDir "ảnh tiếng Việt.jpg"

    Assert-ImageSize $opaqueJpg 320 180
    Assert-ImageSize $alphaJpg 200 140
    Assert-ImageSize $unicodeJpg 77 55

    Write-Host "TEST: source files unchanged"
    foreach ($p in @($opaque, $alpha, $unicode)) {
        $after = (Get-FileHash $p -Algorithm SHA256).Hash
        if ($after -ne $sourceHashesBefore[$p]) {
            throw "Source PNG changed unexpectedly: $p"
        }
    }

    Write-Host "TEST: alpha flattened to white"
    $alphaOut = New-Object System.Drawing.Bitmap($alphaJpg)
    try {
        $corner = $alphaOut.GetPixel(2, 2)
        if ($corner.R -lt 235 -or $corner.G -lt 235 -or $corner.B -lt 235) {
            throw "Transparent area was not flattened close to white. Pixel: R=$($corner.R), G=$($corner.G), B=$($corner.B)"
        }
    }
    finally {
        $alphaOut.Dispose()
    }

    Write-Host "TEST: collision naming"
    Invoke-Converter @($opaque) 0
    $collision = Join-Path $root "opaque (2).jpg"
    Assert-ImageSize $collision 320 180

    Write-Host "TEST: corrupt PNG fails cleanly"
    $corrupt = Join-Path $root "corrupt.png"
    Set-Content -Path $corrupt -Value "not a png" -Encoding UTF8
    Invoke-Converter @($corrupt) 1

    if (Test-Path (Join-Path $root "corrupt.jpg")) {
        throw "Corrupt input left an unexpected final JPG."
    }

    $tempArtifacts = Get-ChildItem -Path $root -Recurse -File |
        Where-Object { $_.Name -like "*.winpebble.*.tmp" }

    if ($tempArtifacts) {
        throw "Temporary artifacts were left behind:`n$($tempArtifacts.FullName -join "`n")"
    }

    Write-Host ""
    Write-Host "Gate B smoke tests PASSED."
}
finally {
    Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
}


