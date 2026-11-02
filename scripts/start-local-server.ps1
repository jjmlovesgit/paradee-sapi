$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$python = Join-Path $repo '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) { throw "Python environment missing: $python" }
$env:HF_HOME = Join-Path $repo '.cache\huggingface'
$env:HF_HUB_OFFLINE = '1'
$env:PYTHONPATH = Join-Path $repo 'src'
& $python -m paradee_sapi.local_server
