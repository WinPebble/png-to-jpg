$ErrorActionPreference='Stop'
$vswhere="${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs=& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$vs) { throw 'MSVC x64 Build Tools not found' }
New-Item -ItemType Directory -Force build/Release | Out-Null
# LINK replaces its import library via rename; remove only this generated file.
$library=Join-Path $PWD 'build/Release/WinPebble.PNGToJPG.Shell.lib'
if (Test-Path -LiteralPath $library) { Remove-Item -LiteralPath $library }
$dev=Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
$text=@"
@call "$dev" >nul
@if errorlevel 1 exit /b 1
@rc /nologo /fo build\Release\shell.res shell\version.rc
@if errorlevel 1 exit /b 1
@cl /nologo /std:c++20 /O2 /MT /W4 /WX /permissive- /EHsc /utf-8 /DUNICODE /D_UNICODE /LD shell\ExplorerCommand.cpp /Fo:build\Release\shell.obj /Fe:build\Release\WinPebble.PNGToJPG.Shell.dll /link /DEF:shell\ExplorerCommand.def build\Release\shell.res shell32.lib shlwapi.lib ole32.lib user32.lib
@if errorlevel 1 exit /b 1
@cl /nologo /std:c++20 /O2 /MT /W4 /WX /permissive- /EHsc /utf-8 /DUNICODE /D_UNICODE tests\Shell-Probe.cpp /Fo:build\Release\probe.obj /Fe:build\Release\Shell-Probe.exe /link shell32.lib shlwapi.lib ole32.lib
@exit /b %errorlevel%
"@
[IO.File]::WriteAllText((Join-Path $PWD 'build/compile-shell.cmd'),$text,[Text.Encoding]::ASCII)
& cmd.exe /d /c build\compile-shell.cmd
if ($LASTEXITCODE) { throw 'Shell build failed' }
