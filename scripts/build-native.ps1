$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out = Join-Path $repo 'build\native'
$assets = Join-Path $out 'assets'
$ort = Join-Path $repo '.cache\ort-native\onnxruntime-win-x64-1.31.1'
$loader = Join-Path $repo '.venv\Lib\site-packages\espeakng_loader'
$model = Get-ChildItem (Join-Path $repo '.cache\huggingface\hub') -Recurse -Filter paradee_int8.onnx -File | Select-Object -First 1
$config = Get-ChildItem (Join-Path $repo '.cache\huggingface\hub') -Recurse -Filter config.json -File | Where-Object { $_.FullName -like '*Paradee-8M-v1.2*' } | Select-Object -First 1
if (-not (Test-Path (Join-Path $ort 'include\onnxruntime_cxx_api.h'))) { throw 'ONNX Runtime native SDK 1.31.1 is missing' }
if (-not (Test-Path (Join-Path $loader 'espeak-ng.dll'))) { throw 'eSpeak NG loader is missing' }
if (-not $model -or -not $config) { throw 'Cached Paradee v1.2 model/config not found' }
New-Item -ItemType Directory -Path $assets -Force | Out-Null

Copy-Item -LiteralPath (Join-Path $ort 'lib\onnxruntime.dll') -Destination $out -Force
Copy-Item -LiteralPath (Join-Path $loader 'espeak-ng.dll') -Destination $assets -Force
Copy-Item -LiteralPath (Join-Path $loader 'espeak-ng-data') -Destination $assets -Recurse -Force
Copy-Item -LiteralPath $model.FullName -Destination (Join-Path $assets 'paradee_int8.onnx') -Force
Copy-Item -LiteralPath $config.FullName -Destination (Join-Path $assets 'config.json') -Force
& (Join-Path $repo '.venv\Scripts\python.exe') (Join-Path $repo 'tools\generate_vocab.py') $config.FullName (Join-Path $out 'vocab.h')
if ($LASTEXITCODE -ne 0) { throw 'Vocab generation failed' }

$vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
$vcvars = & $vswhere -latest -products '*' -find 'VC\Auxiliary\Build\vcvars64.bat'
if (-not $vcvars) { throw 'Visual Studio x64 C++ tools not found' }
$src = Join-Path $repo 'src\native\paradee_native.cpp'
$include = Join-Path $ort 'include'
$lib = Join-Path $ort 'lib'
$compile = 'call "' + $vcvars + '" >nul && cd /d "' + $out + '" && cl /nologo /std:c++17 /utf-8 /EHsc /O2 /I "' + $include + '" /I "' + $out + '" "' + $src + '" /link /LIBPATH:"' + $lib + '" onnxruntime.lib'
& cmd.exe /d /s /c $compile
if ($LASTEXITCODE -ne 0) { throw "Native build failed: $LASTEXITCODE" }
Write-Host "Built $out\paradee_native.exe"
