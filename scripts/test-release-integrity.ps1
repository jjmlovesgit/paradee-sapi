$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'release-integrity.ps1')

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('paradee-integrity-test-' + [guid]::NewGuid().ToString('N'))
$resolvedTemp = [IO.Path]::GetFullPath($tempRoot).TrimEnd('\')
$systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
if (-not $resolvedTemp.StartsWith($systemTemp + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe integrity-test path: $resolvedTemp"
}

New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    $control = Join-Path $tempRoot 'control.bin'
    Copy-Item -LiteralPath (Join-Path $repo 'README.md') -Destination $control
    $expected = (Get-FileHash -Algorithm SHA256 -LiteralPath $control).Hash
    Assert-FileSha256 -LiteralPath $control -ExpectedSha256 $expected -Label 'control file'

    [IO.File]::AppendAllText($control, 'tampered')
    $rejected = $false
    try {
        Assert-FileSha256 -LiteralPath $control -ExpectedSha256 $expected -Label 'tampered control file'
    } catch {
        $rejected = $_.Exception.Message -like 'SHA-256 mismatch*'
    }
    if (-not $rejected) { throw 'Tampered file was not rejected' }

    $nsisCache = Join-Path $tempRoot 'nsis'
    New-Item -ItemType Directory -Path $nsisCache | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo '.cache\nsis\nsis-3.12.zip') -Destination (Join-Path $nsisCache 'nsis-3.12.zip')
    $poisonedInclude = Join-Path $nsisCache 'nsis-3.12\Include\MUI2.nsh'
    New-Item -ItemType Directory -Path (Split-Path $poisonedInclude) -Force | Out-Null
    Set-Content -LiteralPath $poisonedInclude -Value 'poisoned cached include'
    $toolchain = Get-VerifiedNsisCompiler -RepositoryRoot $repo -CacheRoot $nsisCache
    $freshInclude = Join-Path $toolchain.RootPath 'nsis-3.12\Include\MUI2.nsh'
    if ((Get-Content -LiteralPath $freshInclude -Raw) -eq 'poisoned cached include') {
        throw 'Cached NSIS include entered the fresh verified toolchain'
    }
    $stream = [IO.File]::Open($toolchain.CompilerPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $first = $stream.ReadByte()
        $stream.Position = 0
        $stream.WriteByte($first -bxor 0xff)
    } finally {
        $stream.Dispose()
    }
    $compilerRejected = $false
    try {
        Assert-FileSha256 -LiteralPath $toolchain.CompilerPath -ExpectedSha256 $toolchain.CompilerSha256 -Label 'tampered fresh NSIS compiler'
    } catch {
        $compilerRejected = $_.Exception.Message -like 'SHA-256 mismatch*'
    }
    if (-not $compilerRejected) { throw 'Tampered NSIS compiler was not rejected' }
    Remove-VerifiedNsisToolchain -Toolchain $toolchain

    $italianStage = Join-Path $tempRoot 'italian-stage'
    $baseLock = Get-Content -LiteralPath (Join-Path $repo 'packaging\runtime-lock.json') -Raw | ConvertFrom-Json
    $italianLock = Get-Content -LiteralPath (Join-Path $repo 'packaging\italian-voices-lock.json') -Raw | ConvertFrom-Json
    $relativeFiles = @(
        'onnxruntime.dll','msvcp140.dll','msvcp140_1.dll','vcruntime140.dll','vcruntime140_1.dll',
        'assets/espeak-ng.dll','assets/if_sara-model_int8.onnx','assets/im_nicola-model_int8.onnx'
    )
    foreach ($relative in $relativeFiles) {
        $source = Join-Path $repo ('build\italian\stage\' + $relative.Replace('/', '\'))
        $target = Join-Path $italianStage ($relative.Replace('/', '\'))
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $target
    }
    Assert-ItalianPackageInputs -StagePath $italianStage -BaseLock $baseLock -ItalianLock $italianLock
    [IO.File]::AppendAllText((Join-Path $italianStage 'onnxruntime.dll'), 'tampered')
    $runtimeRejected = $false
    try {
        Assert-ItalianPackageInputs -StagePath $italianStage -BaseLock $baseLock -ItalianLock $italianLock
    } catch {
        $runtimeRejected = $_.Exception.Message -like 'SHA-256 mismatch*'
    }
    if (-not $runtimeRejected) { throw 'Tampered Italian runtime DLL was not rejected' }

    Write-Host 'Release integrity controls accepted trusted bytes and rejected tampered tools and package inputs.'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
