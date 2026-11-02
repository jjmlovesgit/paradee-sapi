param([string] $Version = '0.1.0')

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$buildRoot = Join-Path $repo 'build\package'
$stage = Join-Path $buildRoot 'stage'
$bridgeOut = Join-Path $buildRoot 'bridge'
$native = Join-Path $repo 'build\native'
$lock = Get-Content -LiteralPath (Join-Path $repo 'packaging\runtime-lock.json') -Raw | ConvertFrom-Json

if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version must be major.minor.patch' }
if (-not (Test-Path -LiteralPath (Join-Path $native 'assets\paradee_int8.onnx'))) {
    & (Join-Path $PSScriptRoot 'build-native.ps1')
} else {
    & (Join-Path $PSScriptRoot 'build-native.ps1') -ReuseAssets
}
& (Join-Path $PSScriptRoot 'build-bridge.ps1') -OutputDir $bridgeOut

# Recreate only this known package stage; leave all other build files alone.
$resolvedBuildRoot = [IO.Path]::GetFullPath($buildRoot).TrimEnd('\')
$resolvedStage = [IO.Path]::GetFullPath($stage).TrimEnd('\')
if (-not $resolvedStage.StartsWith($resolvedBuildRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe stage path: $resolvedStage"
}
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $bridgeOut 'paradee_sapi_bridge.dll') -Destination $stage
Copy-Item -LiteralPath (Join-Path $native 'onnxruntime.dll') -Destination $stage
$vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) { throw 'Visual Studio installer is missing' }
$vsroot = & $vswhere -latest -products '*' -property installationPath
if (-not $vsroot) { throw 'Visual Studio C++ build tools are missing' }
$redistRoot = Join-Path $vsroot 'VC\Redist\MSVC'
$redistVersion = Get-ChildItem -LiteralPath $redistRoot -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (-not $redistVersion -or $redistVersion.Name -ne $lock.vcRuntimeVersion) {
    throw "Locked VC runtime $($lock.vcRuntimeVersion) is unavailable"
}
$crtDir = Get-ChildItem -LiteralPath (Join-Path $redistVersion.FullName 'x64') -Directory -Filter 'Microsoft.VC*.CRT' |
    Select-Object -First 1
if (-not $crtDir) { throw 'x64 VC runtime files are missing' }
foreach ($name in @('msvcp140.dll','msvcp140_1.dll','vcruntime140.dll','vcruntime140_1.dll')) {
    Copy-Item -LiteralPath (Join-Path $crtDir.FullName $name) -Destination $stage
}
Copy-Item -LiteralPath (Join-Path $native 'assets') -Destination (Join-Path $stage 'assets') -Recurse
Copy-Item -LiteralPath (Join-Path $repo 'third_party\licenses') -Destination (Join-Path $stage 'licenses') -Recurse
Copy-Item -LiteralPath (Join-Path $repo 'third_party\NOTICES.md') -Destination (Join-Path $stage 'THIRD_PARTY_NOTICES.md')
Copy-Item -LiteralPath (Join-Path $repo 'packaging\runtime-lock.json') -Destination $stage
Copy-Item -LiteralPath (Join-Path $repo 'docs\INSTALL.md') -Destination $stage

foreach ($entry in $lock.sha256.PSObject.Properties) {
    $path = Join-Path $stage ($entry.Name.Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing locked runtime file: $($entry.Name)" }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
    if ($actual -ne $entry.Value) { throw "Runtime hash mismatch: $($entry.Name)" }
}
if (-not (Test-Path -LiteralPath (Join-Path $stage 'assets\espeak-ng-data\en_dict'))) {
    throw 'eSpeak NG English dictionary is missing from the staged package'
}

$manifestFiles = @(
    Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName | ForEach-Object {
        [ordered]@{
            path = $_.FullName.Substring($stage.Length + 1).Replace('\', '/')
            bytes = $_.Length
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
        }
    }
)
[ordered]@{ packageVersion = $Version; files = $manifestFiles } |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $stage 'payload-manifest.json') -Encoding UTF8

$nsisRoot = Join-Path $repo '.cache\nsis'
$nsisZip = Join-Path $nsisRoot 'nsis-3.12.zip'
$compiler = Join-Path $nsisRoot 'nsis-3.12\Bin\makensis.exe'
if (-not (Test-Path -LiteralPath $compiler)) {
    New-Item -ItemType Directory -Path $nsisRoot -Force | Out-Null
    if (-not (Test-Path -LiteralPath $nsisZip)) {
        Invoke-WebRequest -Uri 'https://mse.uk.distfiles.macports.org/nsis/nsis-3.12.zip' -OutFile $nsisZip
    }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $nsisZip).Hash.ToLowerInvariant()
    if ($hash -ne '56581f90db321581c5381193d796fffcf2d24b2f8fed2160a6c6a3baa67f2c4f') {
        throw 'NSIS 3.12 archive hash mismatch'
    }
    Expand-Archive -LiteralPath $nsisZip -DestinationPath $nsisRoot -Force
}
if (-not (Test-Path -LiteralPath $compiler)) { throw "NSIS compiler missing: $compiler" }
$dist = Join-Path $repo 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$output = Join-Path $dist "Paradee-SAPI-$Version-x64-Setup.exe"
& $compiler "/DAPP_VERSION=$Version" "/DSTAGE_DIR=$stage" "/DOUT_FILE=$output" (Join-Path $repo 'packaging\paradee-sapi.nsi')
if ($LASTEXITCODE -ne 0) { throw "NSIS build failed: $LASTEXITCODE" }
Write-Host "Built offline installer: $output"
Write-Host "SHA256: $((Get-FileHash -Algorithm SHA256 -LiteralPath $output).Hash)"
