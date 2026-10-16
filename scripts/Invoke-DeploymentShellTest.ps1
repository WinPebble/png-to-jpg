param([Parameter(Mandatory)][string]$Probe,[Parameter(Mandatory)][string]$ResultPath,[switch]$ExpectAbsent,[string]$DirectDll)
$ErrorActionPreference='Stop'
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
$result=[ordered]@{ Passed=$false; Elevated=$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator); ExpectedAbsent=[bool]$ExpectAbsent }
try {
    if ($result.Elevated) { throw 'Shell test must run unelevated, like File Explorer' }
    $log=[IO.Path]::ChangeExtension($ResultPath,'log')
    Start-Transcript -Path $log -Force | Out-Null
    try {
        if ($ExpectAbsent) {
            $diagnostic=& cmd.exe /d /c ('""'+$Probe+'" --registered --contract 2>&1"')
            $code=$LASTEXITCODE
            $result.Diagnostic=@($diagnostic)
            if ($code -eq 0 -or ($diagnostic -join ' ') -notmatch 'HRESULT=0x80040154') { throw 'Expected REGDB_E_CLASSNOTREG after uninstall' }
        } elseif ($DirectDll) {
            & (Join-Path $PSScriptRoot '../tests/Shell-Test.ps1') -Probe $Probe -Dll $DirectDll | Out-Host
        } else {
            & (Join-Path $PSScriptRoot '../tests/Shell-Test.ps1') -Probe $Probe -Registered | Out-Host
        }
    } finally { Stop-Transcript | Out-Null }
    $result.Passed=$true
} catch { $result.Error=$_.Exception.Message }
$temporary=$ResultPath+'.tmp'
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $temporary
Move-Item -LiteralPath $temporary -Destination $ResultPath
