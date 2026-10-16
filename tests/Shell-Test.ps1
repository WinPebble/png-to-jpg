param([string]$Probe='build/Release/Shell-Probe.exe',[string]$Dll='build/Release/WinPebble.PNGToJPG.Shell.dll',[switch]$Registered)
$ErrorActionPreference='Stop'
$root=Join-Path $PSScriptRoot ('../.work/shell-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $root | Out-Null
$root=(Resolve-Path $root).Path
Add-Type -AssemblyName System.Drawing
foreach ($name in 'single.png','ảnh tiếng Việt.png','space name.png') {
    $bitmap=New-Object System.Drawing.Bitmap(80,60)
    try { $bitmap.Save((Join-Path $root $name),[Drawing.Imaging.ImageFormat]::Png) } finally { $bitmap.Dispose() }
}
$png=Join-Path $root 'single.png'
$unicode=Join-Path $root 'ảnh tiếng Việt.png'
$space=Join-Path $root 'space name.png'
$jpg=Join-Path $root 'wrong.jpg'
Copy-Item -LiteralPath $png -Destination $jpg
$before=@{}
foreach ($file in Get-ChildItem $root -Filter '*.png') { $before[$file.FullName]=(Get-FileHash $file.FullName).Hash }
$target=if ($Registered) { '--registered' } else { (Resolve-Path $Dll).Path }
function Probe([string]$Mode,[string[]]$Paths) {
    & $script:Probe $target $Mode @Paths
    if ($LASTEXITCODE) { throw "Shell probe failed: $Mode" }
}
Probe --contract @()
Probe --hidden @($jpg)
Probe --hidden @($png,$jpg)
Probe --hidden @($root)
Probe --invoke @($png)
Probe --invoke @($unicode,$space)
$deadline=(Get-Date).AddSeconds(15)
do {
    Start-Sleep -Milliseconds 100
    $complete=(Test-Path (Join-Path $root 'single.jpg')) -and (Test-Path (Join-Path $root 'ảnh tiếng Việt.jpg')) -and (Test-Path (Join-Path $root 'space name.jpg'))
} until ($complete -or (Get-Date) -gt $deadline)
if (!$complete) { throw 'Launched core did not finish all outputs' }
Probe --invoke @($png)
$deadline=(Get-Date).AddSeconds(15)
while (!(Test-Path (Join-Path $root 'single (2).jpg')) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 100 }
if (!(Test-Path (Join-Path $root 'single (2).jpg'))) { throw 'Shell collision conversion failed' }
foreach ($path in $before.Keys) { if ((Get-FileHash -LiteralPath $path).Hash -ne $before[$path]) { throw 'Source changed via shell' } }
if (Get-ChildItem $root -Filter '*.tmp') { throw 'Temporary files left via shell' }
@{ Passed=$true; Registered=[bool]$Registered; Fixtures=$root; SourceHashes=$before } | ConvertTo-Json | Set-Content (Join-Path $root 'shell-report.json')
Write-Host "Shell contract + launch tests PASS: $root"
