$ErrorActionPreference = "SilentlyContinue"

try {
    [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree("Software\Classes\SystemFileAssociations\.png\shell\OpenAI.PNGtoJPG.HighQuality", $false)
} catch {}

$rootPath = "Software\Classes\SystemFileAssociations\image\shell"
try {
    $root = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($rootPath, $true)
    if ($root) {
        foreach ($name in @($root.GetSubKeyNames())) {
            if ($name -like "*.zzPNGtoJPG") {
                try { $root.DeleteSubKeyTree($name, $false) } catch {}
            }
        }
        $root.Close()
    }
} catch {}

$AppDir = Join-Path $env:LOCALAPPDATA "PNGtoJPG"
if (Test-Path -LiteralPath $AppDir) {
    Remove-Item -LiteralPath $AppDir -Recurse -Force
}

Write-Host ""
Write-Host "PNG to JPG context-menu command removed." -ForegroundColor Green
Write-Host "Restart Windows Explorer if the item is still visible."
Write-Host ""
Read-Host "Press Enter to close"
