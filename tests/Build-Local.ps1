param([string]$OutputDirectory="build/Release",[switch]$StoreCandidate)
# Run from repository root.
$ErrorActionPreference = 'Stop'
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$vs) { throw 'MSVC x64 Build Tools not found' }
$output=[IO.Path]::GetFullPath((Join-Path $PWD $OutputDirectory))
New-Item -ItemType Directory -Force $output | Out-Null
$resourceDefine=if ($StoreCandidate) { '/DWINPEBBLE_STORE_CANDIDATE' } else { '' }
$dev = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
$build = @"
@call "$dev" >nul
@if errorlevel 1 exit /b 1
@rc /nologo $resourceDefine /fo "$output\version.res" resources\version.rc
@if errorlevel 1 exit /b 1
@cl /nologo /std:c++20 /O2 /MT /W4 /WX /permissive- /EHsc /utf-8 /DUNICODE /D_UNICODE native\WinPebble.PNGToJPG.cpp /Fo:"$output\core.obj" /Fe:"$output\WinPebble.PNGToJPG.exe" /link /MANIFEST:NO /SUBSYSTEM:WINDOWS /MACHINE:X64 "$output\version.res" windowscodecs.lib ole32.lib oleaut32.lib shell32.lib shlwapi.lib user32.lib
@exit /b %errorlevel%
"@
[IO.File]::WriteAllText((Join-Path $output 'compile.cmd'), $build, [Text.Encoding]::ASCII)
& cmd.exe /d /c (Join-Path $output "compile.cmd")
if ($LASTEXITCODE) { throw 'Native build failed' }
