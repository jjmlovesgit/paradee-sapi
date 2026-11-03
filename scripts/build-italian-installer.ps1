param([string] $Version = '0.1.0')

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'release-integrity.ps1')
$build = Join-Path $repo 'build\italian'
$native = Join-Path $build 'native'
$assets = Join-Path $native 'assets'
$bridge = Join-Path $build 'bridge'
$stage = Join-Path $build 'stage'
$baseLock = Get-Content (Join-Path $repo 'packaging\runtime-lock.json') -Raw | ConvertFrom-Json
$itLock = Get-Content (Join-Path $repo 'packaging\italian-voices-lock.json') -Raw | ConvertFrom-Json
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version must be major.minor.patch' }

& (Join-Path $PSScriptRoot 'setup-italian-assets.ps1')
if (-not (Test-Path (Join-Path $repo 'build\native\vocab.h'))) {
    & (Join-Path $PSScriptRoot 'build-native.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'English vocab generation/native setup failed' }
}

$resolved = [IO.Path]::GetFullPath($build).TrimEnd('\')
if (-not $resolved.StartsWith([IO.Path]::GetFullPath((Join-Path $repo 'build')).TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe Italian build directory: $resolved"
}
if (Test-Path -LiteralPath $build) { Remove-Item -LiteralPath $build -Recurse -Force }
New-Item -ItemType Directory -Path $assets -Force | Out-Null
$loader = Join-Path $repo '.venv\Lib\site-packages\espeakng_loader'
if (-not (Test-Path (Join-Path $loader 'espeak-ng.dll'))) { throw 'eSpeak NG build dependency is missing' }
$ort = Join-Path $repo '.cache\ort-native\onnxruntime-win-x64-1.31.1'
if (-not (Test-Path (Join-Path $ort 'lib\onnxruntime.dll'))) { throw 'ONNX Runtime SDK is missing' }
$cache = Join-Path $repo '.cache\italian-pack-assets'
Copy-Item (Join-Path $loader 'espeak-ng.dll') $assets
Copy-Item (Join-Path $loader 'espeak-ng-data') $assets -Recurse
Copy-Item (Join-Path $cache 'if_sara-model_int8.onnx') (Join-Path $assets 'if_sara-model_int8.onnx')
Copy-Item (Join-Path $cache 'im_nicola-model_int8.onnx') (Join-Path $assets 'im_nicola-model_int8.onnx')

& (Join-Path $PSScriptRoot 'build-bridge.ps1') -OutputDir $bridge -ItalianPack
if ($LASTEXITCODE -ne 0) { throw 'Italian SAPI bridge build failed' }

New-Item -ItemType Directory -Path $stage -Force | Out-Null
Copy-Item (Join-Path $bridge 'paradee_sapi_bridge.dll') $stage
Copy-Item (Join-Path $ort 'lib\onnxruntime.dll') $stage
$vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
$vsroot = & $vswhere -latest -products '*' -property installationPath
if (-not $vsroot) { throw 'Visual Studio C++ runtime is missing' }
$crtRoot = Join-Path $vsroot 'VC\Redist\MSVC'
$crtVersion = Get-ChildItem $crtRoot -Directory | Where-Object Name -match '^\d+\.\d+\.\d+$' |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (-not $crtVersion -or $crtVersion.Name -ne $baseLock.vcRuntimeVersion) { throw "Locked VC runtime $($baseLock.vcRuntimeVersion) is unavailable" }
$crt = Get-ChildItem (Join-Path $crtVersion.FullName 'x64') -Directory -Filter 'Microsoft.VC*.CRT' | Select-Object -First 1
foreach ($name in @('msvcp140.dll','msvcp140_1.dll','vcruntime140.dll','vcruntime140_1.dll')) {
    Copy-Item (Join-Path $crt.FullName $name) $stage
}
Copy-Item $assets (Join-Path $stage 'assets') -Recurse
Copy-Item (Join-Path $repo 'third_party\licenses') (Join-Path $stage 'licenses') -Recurse
Copy-Item (Join-Path $cache 'teacher-in-loop-LICENSE') (Join-Path $stage 'licenses\Teacher-in-the-Loop-Apache-2.0.txt')
Copy-Item (Join-Path $repo 'third_party\NOTICES.md') (Join-Path $stage 'THIRD_PARTY_NOTICES.md')
@'

Italian voice models: `if_sara` and `im_nicola`, trained and released by Fabio Angela in the
Teacher in the Loop project under Apache-2.0. Model revision and SHA-256 are
listed in `runtime-lock-italian.json`. The model derives from Kokoro-82M and
Paradee. Source: https://github.com/MithrilMan/teacher-in-the-loop .
'@ | Add-Content -LiteralPath (Join-Path $stage 'THIRD_PARTY_NOTICES.md') -Encoding UTF8
Copy-Item (Join-Path $repo 'docs\ITALIAN_PACK.md') (Join-Path $stage 'ITALIAN_PACK.md')

$dist = Join-Path $repo 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$output = Join-Path $dist "Paradee-SAPI-Italian-$Version-x64-Setup.exe"
$packageStage = New-PrivatePackageStage -SourcePath $stage
$toolchain = $null
try {
    Assert-ItalianPackageInputs -StagePath $packageStage.StagePath -BaseLock $baseLock -ItalianLock $itLock
    $runtimePaths = @('paradee_sapi_bridge.dll','onnxruntime.dll','msvcp140.dll','msvcp140_1.dll','vcruntime140.dll','vcruntime140_1.dll',
        'assets/espeak-ng.dll','assets/if_sara-model_int8.onnx','assets/im_nicola-model_int8.onnx')
    $hashes = [ordered]@{}
    foreach ($relative in $runtimePaths) {
        $path = Join-Path $packageStage.StagePath ($relative.Replace('/', '\'))
        $hashes[$relative] = (Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $runtime = [ordered]@{
        package = 'Paradee-SAPI Italian Voice Pack'
        packageVersion = $Version
        sourceRepository = $itLock.repository
        sourceRevision = $itLock.revision
        voices = $itLock.voices
        onnxRuntimeVersion = $baseLock.onnxRuntimeVersion
        eSpeakNgVersion = $baseLock.espeakNgVersion
        files = $hashes
    }
    $runtime | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $packageStage.StagePath 'runtime-lock-italian.json') -Encoding UTF8
    $manifestFiles = @(Get-ChildItem $packageStage.StagePath -Recurse -File | Sort-Object FullName | ForEach-Object {
        [ordered]@{ path = $_.FullName.Substring($packageStage.StagePath.Length + 1).Replace('\','/'); bytes = $_.Length; sha256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
    [ordered]@{ packageVersion = $Version; language = 'it-IT'; files = $manifestFiles } |
        ConvertTo-Json -Depth 5 | Set-Content (Join-Path $packageStage.StagePath 'payload-manifest.json') -Encoding UTF8

    $toolchain = Get-VerifiedNsisCompiler -RepositoryRoot $repo
    Assert-FileSha256 -LiteralPath $toolchain.CompilerPath -ExpectedSha256 $toolchain.CompilerSha256 -Label 'fresh NSIS compiler'
    & $toolchain.CompilerPath "/DAPP_VERSION=$Version" "/DSTAGE_DIR=$($packageStage.StagePath)" "/DOUT_FILE=$output" (Join-Path $repo 'packaging\paradee-sapi-italian.nsi')
    if ($LASTEXITCODE -ne 0) { throw "Italian NSIS build failed: $LASTEXITCODE" }
} finally {
    if ($toolchain) { Remove-VerifiedNsisToolchain -Toolchain $toolchain }
    Remove-PrivatePackageStage -PackageStage $packageStage
}
Write-Host "Built offline Italian installer: $output"
Write-Host "SHA256: $((Get-FileHash $output -Algorithm SHA256).Hash)"
