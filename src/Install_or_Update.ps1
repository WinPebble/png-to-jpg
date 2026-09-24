$ErrorActionPreference = "Stop"

$AppDir = Join-Path $env:LOCALAPPDATA "PNGtoJPG"
$SourceScript = Join-Path $PSScriptRoot "ConvertPNGtoJPG.ps1"
$SourceIcon = Join-Path $PSScriptRoot "user_icon.ico"
$TargetScript = Join-Path $AppDir "ConvertPNGtoJPG.ps1"
$TargetIcon = Join-Path $AppDir "user_icon.ico"

if (-not (Test-Path -LiteralPath $SourceScript)) {
    throw "ConvertPNGtoJPG.ps1 is missing. Extract the whole ZIP first."
}
if (-not (Test-Path -LiteralPath $SourceIcon)) {
    throw "user_icon.ico is missing. Extract the whole ZIP first."
}

New-Item -ItemType Directory -Path $AppDir -Force | Out-Null
Copy-Item -LiteralPath $SourceScript -Destination $TargetScript -Force
Copy-Item -LiteralPath $SourceIcon -Destination $TargetIcon -Force

# Remove older menu keys
$oldKeys = @(
    "Software\Classes\SystemFileAssociations\.png\shell\OpenAI.PNGtoJPG.HighQuality",
    "Software\Classes\SystemFileAssociations\image\shell\edit.zzPNGtoJPG",
    "Software\Classes\SystemFileAssociations\image\shell\Edit with Paint.zzPNGtoJPG"
)
foreach ($k in $oldKeys) {
    try { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($k, $false) } catch {}
}

$imageShellCU = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("Software\Classes\SystemFileAssociations\image\shell")
foreach ($name in @($imageShellCU.GetSubKeyNames())) {
    if ($name -like "*.zzPNGtoJPG") {
        try { $imageShellCU.DeleteSubKeyTree($name, $false) } catch {}
    }
}
$imageShellCU.Close()

# Detect Paint static verb name
$paintVerbName = $null
$hkcrShellPath = "Registry::HKEY_CLASSES_ROOT\SystemFileAssociations\image\shell"

if (Test-Path $hkcrShellPath) {
    $children = Get-ChildItem $hkcrShellPath -ErrorAction SilentlyContinue
    foreach ($child in $children) {
        $name = $child.PSChildName
        $props = Get-ItemProperty $child.PSPath -ErrorAction SilentlyContinue

        $label = ""
        if ($null -ne $props.MUIVerb) { $label += " " + [string]$props.MUIVerb }
        try {
            $defaultLabel = (Get-Item $child.PSPath).GetValue("")
            if ($null -ne $defaultLabel) { $label += " " + [string]$defaultLabel }
        } catch {}

        $cmd = ""
        $cmdPath = Join-Path $child.PSPath "command"
        if (Test-Path $cmdPath) {
            try { $cmd = [string](Get-Item $cmdPath).GetValue("") } catch {}
        }

        if (($cmd -match "(?i)mspaint") -or ($label -match "(?i)paint") -or ($name -match "(?i)^edit$")) {
            $paintVerbName = $name
            if ($cmd -match "(?i)mspaint") { break }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($paintVerbName)) {
    $paintVerbName = "edit"
}

$verbName = $paintVerbName + ".zzPNGtoJPG"
$verbPath = "Software\Classes\SystemFileAssociations\image\shell\" + $verbName
$commandPath = $verbPath + "\command"

$verbKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($verbPath)
$verbKey.SetValue("", "Convert PNG to JPG", [Microsoft.Win32.RegistryValueKind]::String)
$verbKey.SetValue("MUIVerb", "Convert PNG to JPG", [Microsoft.Win32.RegistryValueKind]::String)
$verbKey.SetValue("MultiSelectModel", "Player", [Microsoft.Win32.RegistryValueKind]::String)
$verbKey.SetValue("AppliesTo", 'System.FileExtension:=".png"', [Microsoft.Win32.RegistryValueKind]::String)
$verbKey.SetValue("Icon", $TargetIcon, [Microsoft.Win32.RegistryValueKind]::String)
$verbKey.Close()

$ps = Join-Path $PSHOME "powershell.exe"
$command = '"' + $ps + '" -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $TargetScript + '" "%1"'

$commandKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($commandPath)
$commandKey.SetValue("", $command, [Microsoft.Win32.RegistryValueKind]::String)
$commandKey.Close()

Write-Host ""
Write-Host "Updated successfully." -ForegroundColor Green
Write-Host "Menu label: Convert PNG to JPG"
Write-Host "Icon: the user-provided icon"
Write-Host ""
Write-Host "If the old label or icon still appears, restart Windows Explorer from Task Manager."
Write-Host ""
Read-Host "Press Enter to close"
