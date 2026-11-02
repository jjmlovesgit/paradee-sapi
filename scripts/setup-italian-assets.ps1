param([switch] $CheckOnly)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$lock = Get-Content (Join-Path $repo 'packaging\italian-voices-lock.json') -Raw | ConvertFrom-Json
$cache = Join-Path $repo '.cache\italian-pack-assets'
$files = @(
    @{ Entry = $lock.model; Target = 'if_sara-model_int8.onnx' },
    @{ Entry = $lock.nicola; Target = 'im_nicola-model_int8.onnx' },
    @{ Entry = $lock.vocab; Target = 'italian-vocab.json' },
    @{ Entry = $lock.license; Target = 'teacher-in-loop-LICENSE' }
)
New-Item -ItemType Directory -Path $cache -Force | Out-Null
foreach ($item in $files) {
    $target = Join-Path $cache $item.Target
    $entry = $item.Entry
    $valid = (Test-Path -LiteralPath $target) -and
        (Get-Item -LiteralPath $target).Length -eq $entry.bytes -and
        (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -eq $entry.sha256
    if ($valid) { Write-Host "Verified $($item.Target)"; continue }
    if ($CheckOnly) { throw "Italian voice asset missing or hash mismatch: $target" }
    $temp = "$target.partial"
    $uri = "https://huggingface.co/$($lock.repository)/resolve/$($lock.revision)/$($entry.path)"
    & curl.exe --fail --location --silent --show-error --retry 3 --retry-delay 2 --continue-at - --output $temp $uri
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $($entry.path)" }
    if ((Get-Item -LiteralPath $temp).Length -ne $entry.bytes -or
        (Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) {
        throw "Downloaded asset failed size or SHA-256 check: $($entry.path)"
    }
    Move-Item -LiteralPath $temp -Destination $target -Force
    Write-Host "Downloaded and verified $($item.Target)"
}
Write-Host 'Pinned Italian voice assets are ready.'
