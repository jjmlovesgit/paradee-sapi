param([string] $OutputDir = 'build\sapi5_bridge', [switch] $ItalianPack)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$src = Join-Path $repo 'src\sapi5_bridge'
$nativeSrc = Join-Path $repo 'src\native'
$nativeBuild = Join-Path $repo 'build\native'
$ort = Join-Path $repo '.cache\ort-native\onnxruntime-win-x64-1.31.1'
$out = if ([IO.Path]::IsPathRooted($OutputDir)) { $OutputDir } else { Join-Path $repo $OutputDir }
New-Item -ItemType Directory -Path $out -Force | Out-Null
if (-not (Test-Path (Join-Path $nativeBuild 'vocab.h'))) {
    & (Join-Path $PSScriptRoot 'build-native.ps1')
}
Copy-Item -LiteralPath (Join-Path $ort 'lib\onnxruntime.dll') -Destination $out -Force

$vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) { throw 'Visual Studio installer not found' }
$vcvars = & $vswhere -latest -products '*' -find 'VC\Auxiliary\Build\vcvars64.bat'
if (-not $vcvars) { throw 'Visual Studio x64 C++ tools not found' }

$packDefine = if ($ItalianPack) { ' /D PARADEE_ITALIAN_PACK' } else { '' }
$compile = 'call "' + $vcvars + '" >nul && cd /d "' + $out + '" && cl /nologo /std:c++17 /utf-8 /EHsc /LD /O2 /D _WINDLL /D PARADEE_NATIVE_ENGINE /D PARADEE_NATIVE_LIBRARY' + $packDefine + ' /I "' + $src + '" /I "' + $nativeSrc + '" /I "' + $nativeBuild + '" /I "' + (Join-Path $ort 'include') + '" "' + (Join-Path $src 'paradee_sapi_bridge.cpp') + '" "' + (Join-Path $nativeSrc 'paradee_native.cpp') + '" /link /DEF:"' + (Join-Path $src 'paradee_sapi_bridge.def') + '" /LIBPATH:"' + (Join-Path $ort 'lib') + '" onnxruntime.lib ole32.lib advapi32.lib oleaut32.lib'
& cmd.exe /d /s /c $compile
if ($LASTEXITCODE -ne 0) { throw "Bridge build failed: $LASTEXITCODE" }
Write-Host "Built $out\paradee_sapi_bridge.dll"
