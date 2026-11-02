$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$venv = Join-Path $repoRoot '.cache\voice-lab-venv'
$python = Join-Path $venv 'Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    py -3.12 -m venv $venv
    if ($LASTEXITCODE -ne 0) { throw 'Python 3.12 virtual environment creation failed' }
}
& $python -m pip install -r (Join-Path $PSScriptRoot 'requirements-lock.txt')
if ($LASTEXITCODE -ne 0) { throw 'Voice Lab dependency installation failed' }
$modelWheel = Join-Path $repoRoot '.cache\en_core_web_sm-3.8.0-py3-none-any.whl'
$modelHash = '1932429db727d4bff3deed6b34cfc05df17794f4a52eeb26cf8928f7c1a0fb85'
if (-not (Test-Path -LiteralPath $modelWheel) -or
    (Get-FileHash -LiteralPath $modelWheel -Algorithm SHA256).Hash.ToLowerInvariant() -ne $modelHash) {
    $uri = 'https://github.com/explosion/spacy-models/releases/download/en_core_web_sm-3.8.0/en_core_web_sm-3.8.0-py3-none-any.whl'
    & curl.exe --fail --location --silent --show-error --retry 3 --output $modelWheel $uri
    if ($LASTEXITCODE -ne 0) { throw 'spaCy English model download failed' }
}
if ((Get-FileHash -LiteralPath $modelWheel -Algorithm SHA256).Hash.ToLowerInvariant() -ne $modelHash) {
    throw 'spaCy English model hash mismatch'
}
& $python -m pip install $modelWheel
if ($LASTEXITCODE -ne 0) { throw 'spaCy English model installation failed' }
& $python (Join-Path $PSScriptRoot 'smoke-env.py')
if ($LASTEXITCODE -ne 0) { throw 'Voice Lab dependency import failed' }
