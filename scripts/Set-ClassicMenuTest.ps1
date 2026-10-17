param([Parameter(Mandatory)][ValidateSet('Disable','Restore')][string]$Action)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$backup=Join-Path $root 'artifacts/gate-c/classic-menu-backup'
$id='{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
$parent='Registry::HKEY_CURRENT_USER\Software\Classes\CLSID'
$original=Join-Path $parent $id
$saved=Join-Path $parent ($id+'.GateCBackup')
if ($Action -eq 'Disable') {
    if (Test-Path -LiteralPath $saved) { throw 'Classic-menu backup key already exists; restore it first' }
    if (!(Test-Path -LiteralPath $original)) { throw 'Classic-menu override is not present; nothing to change' }
    New-Item -ItemType Directory -Force $backup | Out-Null
    & reg.exe export ('HKCU\Software\Classes\CLSID\'+$id) (Join-Path $backup 'classic-menu.reg') /y
    if ($LASTEXITCODE) { throw 'Classic-menu backup failed' }
    Rename-Item -LiteralPath $original -NewName ($id+'.GateCBackup')
} else {
    if (!(Test-Path -LiteralPath $saved)) { throw 'No test backup key present; refusing to create a guessed configuration' }
    if (Test-Path -LiteralPath $original) { throw 'Original key recreated externally; review before restore' }
    Rename-Item -LiteralPath $saved -NewName $id
}
Write-Host "Classic-menu override action $Action complete. Restart Explorer separately to apply."
