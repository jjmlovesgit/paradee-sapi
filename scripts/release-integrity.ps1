function Assert-FileSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $LiteralPath,
        [Parameter(Mandatory)] [string] $ExpectedSha256,
        [string] $Label = $LiteralPath
    )

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        throw "Missing locked file: $Label"
    }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $LiteralPath).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedSha256.ToLowerInvariant()) {
        throw "SHA-256 mismatch for $Label"
    }
}

function New-ProtectedTempDirectory {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Prefix)

    $root = Join-Path ([IO.Path]::GetTempPath()) ($Prefix + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $root | Out-Null
    $userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    & icacls.exe $root '/inheritance:r' '/grant:r' "*$($userSid):(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Remove-Item -LiteralPath $root -Recurse -Force
        throw "Could not protect temporary directory: $root"
    }
    return (Resolve-Path -LiteralPath $root).Path
}

function Assert-ItalianPackageInputs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $StagePath,
        [Parameter(Mandatory)] $BaseLock,
        [Parameter(Mandatory)] $ItalianLock
    )

    $trustedHashes = [ordered]@{
        'onnxruntime.dll' = $BaseLock.sha256.'onnxruntime.dll'
        'msvcp140.dll' = $BaseLock.sha256.'msvcp140.dll'
        'msvcp140_1.dll' = $BaseLock.sha256.'msvcp140_1.dll'
        'vcruntime140.dll' = $BaseLock.sha256.'vcruntime140.dll'
        'vcruntime140_1.dll' = $BaseLock.sha256.'vcruntime140_1.dll'
        'assets/espeak-ng.dll' = $BaseLock.sha256.'assets/espeak-ng.dll'
        'assets/if_sara-model_int8.onnx' = $ItalianLock.model.sha256
        'assets/im_nicola-model_int8.onnx' = $ItalianLock.nicola.sha256
    }
    foreach ($entry in $trustedHashes.GetEnumerator()) {
        $path = Join-Path $StagePath ($entry.Key.Replace('/', '\'))
        Assert-FileSha256 -LiteralPath $path -ExpectedSha256 $entry.Value -Label "Italian package input $($entry.Key)"
    }
}

function Get-VerifiedNsisCompiler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $RepositoryRoot,
        [string] $CacheRoot
    )

    $lockPath = Join-Path $RepositoryRoot 'packaging\toolchain-lock.json'
    $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
    if (-not $CacheRoot) { $CacheRoot = Join-Path $RepositoryRoot '.cache\nsis' }
    $archive = Join-Path $CacheRoot "nsis-$($lock.nsisVersion).zip"

    New-Item -ItemType Directory -Path $CacheRoot -Force | Out-Null
    if (-not (Test-Path -LiteralPath $archive)) {
        Invoke-WebRequest -Uri $lock.archiveUri -OutFile $archive
    }
    $toolchainRoot = New-ProtectedTempDirectory -Prefix 'paradee-nsis-'
    try {
        $privateArchive = Join-Path $toolchainRoot "nsis-$($lock.nsisVersion).zip"
        Copy-Item -LiteralPath $archive -Destination $privateArchive
        Assert-FileSha256 -LiteralPath $privateArchive -ExpectedSha256 $lock.archiveSha256 -Label "private NSIS $($lock.nsisVersion) archive"
        Expand-Archive -LiteralPath $privateArchive -DestinationPath $toolchainRoot
        $compiler = Join-Path $toolchainRoot ($lock.compilerRelativePath.Replace('/', '\'))
        Assert-FileSha256 -LiteralPath $compiler -ExpectedSha256 $lock.compilerSha256 -Label "NSIS $($lock.nsisVersion) compiler"
        return [pscustomobject]@{
            RootPath = (Resolve-Path -LiteralPath $toolchainRoot).Path
            CompilerPath = (Resolve-Path -LiteralPath $compiler).Path
            CompilerSha256 = $lock.compilerSha256
        }
    } catch {
        if (Test-Path -LiteralPath $toolchainRoot) {
            Remove-Item -LiteralPath $toolchainRoot -Recurse -Force
        }
        throw
    }
}

function New-PrivatePackageStage {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $SourcePath)

    $root = New-ProtectedTempDirectory -Prefix 'paradee-package-'
    $stage = Join-Path $root 'stage'
    Copy-Item -LiteralPath $SourcePath -Destination $stage -Recurse
    return [pscustomobject]@{
        RootPath = (Resolve-Path -LiteralPath $root).Path
        StagePath = (Resolve-Path -LiteralPath $stage).Path
    }
}

function Remove-PrivatePackageStage {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $PackageStage)

    $root = [IO.Path]::GetFullPath([string]$PackageStage.RootPath).TrimEnd('\')
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    if (-not $root.StartsWith($temp + '\paradee-package-', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected package stage path: $root"
    }
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

function Remove-VerifiedNsisToolchain {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Toolchain)

    $root = [IO.Path]::GetFullPath([string]$Toolchain.RootPath).TrimEnd('\')
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    if (-not $root.StartsWith($temp + '\paradee-nsis-', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected NSIS toolchain path: $root"
    }
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
