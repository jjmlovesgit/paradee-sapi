$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$src = Join-Path $repo 'src\sapi5_bridge'
$out = Join-Path $repo 'build\sapi5_bridge'
New-Item -ItemType Directory -Path $out -Force | Out-Null

$vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) { throw 'Visual Studio installer not found' }
$vcvars = & $vswhere -latest -products '*' -find 'VC\Auxiliary\Build\vcvars64.bat'
if (-not $vcvars) { throw 'Visual Studio x64 C++ tools not found' }

$compile = 'call "' + $vcvars + '" >nul && cd /d "' + $out + '" && cl /nologo /EHsc /LD /O2 /D _WINDLL /I "' + $src + '" "' + (Join-Path $src 'paradee_sapi_bridge.cpp') + '" /link /DEF:"' + (Join-Path $src 'paradee_sapi_bridge.def') + '" winhttp.lib ole32.lib advapi32.lib oleaut32.lib'
& cmd.exe /d /s /c $compile
if ($LASTEXITCODE -ne 0) { throw "Bridge build failed: $LASTEXITCODE" }
Write-Host "Built $out\paradee_sapi_bridge.dll"
