param([Parameter(Mandatory)][ValidateSet('Disable','Restore')][string]$Action)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$backup=Join-Path $root 'artifacts/gate-c/legacy-backup'
$statePath=Join-Path $backup 'state.json'
$keyPath='Software\Classes\SystemFileAssociations\image\shell\edit.zzPNGtoJPG'
$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
if ($Action -eq 'Disable') {
    if (Test-Path -LiteralPath $statePath) {
        $previous=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        if (!$previous.Restored) { throw 'Backup already exists. Restore the previous test first.' }
        Move-Item -LiteralPath $statePath -Destination (Join-Path $backup ('restored-'+[guid]::NewGuid().ToString('N')+'.json'))
    }
    $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($keyPath,$true)
    if (!$key) { Write-Host 'No matching v1 registration; no change.'; return }
    try {
        # Refuse to operate on an unrelated command with a coincidentally matching key.
        if ($key.GetValue('MUIVerb') -ne 'Convert PNG to JPG') { throw 'Unexpected legacy label' }
        $command=$key.OpenSubKey('command')
        try {
            if (!$command -or $command.GetValue('') -notlike '*PNGtoJPG\ConvertPNGtoJPG.ps1*') { throw 'Unexpected legacy command' }
        } finally { if ($command) { $command.Dispose() } }
        New-Item -ItemType Directory -Force $backup | Out-Null
        $registryBackup=Join-Path $backup ('edit.zzPNGtoJPG-'+[guid]::NewGuid().ToString('N')+'.reg')
        & reg.exe export ('HKCU\'+$keyPath) $registryBackup /y
        if ($LASTEXITCODE) { throw 'Registry backup failed; no value changed' }
        $alreadyDisabled=$key.GetValueNames() -contains 'LegacyDisable'
        @{ Key=$keyPath; UserSID=$sid; RegistryBackup=$registryBackup; Changed=(-not $alreadyDisabled); Restored=$false } | ConvertTo-Json | Set-Content $statePath
        if (!$alreadyDisabled) { $key.SetValue('LegacyDisable','',[Microsoft.Win32.RegistryValueKind]::String) }
    } finally { $key.Dispose() }
    Write-Host 'Exact v1 verb backed up and temporarily hidden. No script, icon or user image removed.'
} else {
    if (!(Test-Path -LiteralPath $statePath)) { Write-Host 'No migration state to restore.'; return }
    $state=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    if ($state.Key -ne $keyPath -or $state.UserSID -ne $sid) { throw 'Migration state identity mismatch' }
    if ($state.Restored) { Write-Host 'Legacy menu already restored.'; return }
    if ($state.Changed) {
        $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($keyPath,$true)
        if (!$key) { throw 'Legacy key was changed externally; review saved .reg backup manually' }
        try {
            if ($key.GetValueNames() -contains 'LegacyDisable') {
                if ($key.GetValueKind('LegacyDisable') -ne [Microsoft.Win32.RegistryValueKind]::String -or $key.GetValue('LegacyDisable') -ne '') {
                    throw 'LegacyDisable changed externally; refusing to overwrite it'
                }
                $key.DeleteValue('LegacyDisable',$false)
            }
        } finally { $key.Dispose() }
    }
    $state.Restored=$true
    $state | ConvertTo-Json | Set-Content $statePath
    Write-Host 'Restored only the LegacyDisable value added by this test. Backup retained.'
}
