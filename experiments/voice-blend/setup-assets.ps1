param([switch] $CheckOnly)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'assets-lock.json') -Raw | ConvertFrom-Json
$lab = Join-Path $repoRoot '.cache\kokoro-voice-lab'
$labFull = [IO.Path]::GetFullPath($lab).TrimEnd('\')
if (-not (Test-Path -LiteralPath (Join-Path $lab '.git'))) {
    if ($CheckOnly) { throw "Voice Lab is missing: $lab" }
    git clone https://github.com/Miceprincipal/Kokoro-Voice-Lab.git $lab
    if ($LASTEXITCODE -ne 0) { throw 'Voice Lab clone failed' }
    git -C $lab checkout --detach $lock.source_tool_revision
    if ($LASTEXITCODE -ne 0) { throw 'Pinned Voice Lab revision is unavailable' }
}
$actualRevision = (git -C $lab rev-parse HEAD).Trim()
if ($actualRevision -ne $lock.source_tool_revision) {
    throw "Voice Lab revision mismatch: $actualRevision"
}

foreach ($entry in $lock.files) {
    if ($entry.path -notmatch '^(config\.json|tokenizer(_config)?\.json|onnx/model_uint8\.onnx|voices/(af|am|bf|bm)_[a-z]+\.bin)$') {
        throw "Unexpected asset path in lock file: $($entry.path)"
    }
    if ($entry.sha256 -notmatch '^[0-9a-f]{64}$') { throw "Missing SHA-256: $($entry.path)" }
    $target = [IO.Path]::GetFullPath((Join-Path $lab ($entry.path.Replace('/', '\'))))
    if (-not $target.StartsWith($labFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe asset path: $target"
    }
    $valid = (Test-Path -LiteralPath $target) -and
        (Get-Item -LiteralPath $target).Length -eq $entry.bytes -and
        (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -eq $entry.sha256
    if ($valid) { Write-Host "Verified $($entry.path)"; continue }
    if ($CheckOnly) { throw "Asset missing or hash mismatch: $($entry.path)" }
    $directory = Split-Path -Parent $target
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $temp = "$target.partial"
    $uri = "https://huggingface.co/$($lock.repo)/resolve/$($lock.revision)/$($entry.path)"
    try {
        & curl.exe --fail --location --silent --show-error --retry 3 --retry-delay 2 --continue-at - --output $temp $uri
        if ($LASTEXITCODE -ne 0) { throw "Download failed: $($entry.path)" }
        if ((Get-Item -LiteralPath $temp).Length -ne $entry.bytes -or
            (Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) {
            throw "Download failed hash or size check: $($entry.path)"
        }
        Move-Item -LiteralPath $temp -Destination $target -Force
        Write-Host "Downloaded and verified $($entry.path)"
    } catch {
        Write-Warning "Partial download retained for resume: $temp"
        throw
    }
}
$speaker = $lock.speaker_model
if ($speaker.path -ne 'voxceleb_resnet34.onnx' -or $speaker.sha256 -notmatch '^[0-9a-f]{64}$' -or
    $speaker.repo -ne 'Wespeaker/wespeaker-voxceleb-resnet34' -or
    $speaker.revision -notmatch '^[0-9a-f]{40}$') {
    throw 'Invalid speaker model lock entry'
}
$speakerTarget = Join-Path $lab $speaker.path
$speakerValid = (Test-Path -LiteralPath $speakerTarget) -and
    (Get-Item -LiteralPath $speakerTarget).Length -eq $speaker.bytes -and
    (Get-FileHash -LiteralPath $speakerTarget -Algorithm SHA256).Hash.ToLowerInvariant() -eq $speaker.sha256
if (-not $speakerValid) {
    if ($CheckOnly) { throw "Speaker model missing or hash mismatch: $speakerTarget" }
    $temp = "$speakerTarget.partial"
    $uri = "https://huggingface.co/$($speaker.repo)/resolve/$($speaker.revision)/$($speaker.path)"
    & curl.exe --fail --location --silent --show-error --retry 3 --retry-delay 2 --continue-at - --output $temp $uri
    if ($LASTEXITCODE -ne 0) { throw 'Speaker model download failed' }
    if ((Get-Item -LiteralPath $temp).Length -ne $speaker.bytes -or
        (Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash.ToLowerInvariant() -ne $speaker.sha256) {
        throw 'Speaker model failed hash or size check'
    }
    Move-Item -LiteralPath $temp -Destination $speakerTarget -Force
}
Write-Host "Verified $($speaker.path)"
Write-Host "Kokoro Voice Lab assets ready: $lab"
