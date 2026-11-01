param([switch] $Restore)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$backup = Join-Path $repo '.cache\onecore-default-before-paradee.txt'
$key = 'Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Speech_OneCore\Voices'
$token = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens\ParadeeSapiBmFable'
$tokenKey = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens\ParadeeSapiBmFable'

if ($Restore) {
    if (-not (Test-Path -LiteralPath $backup)) { throw "No saved default at $backup" }
    $previous = Get-Content -LiteralPath $backup -Raw
    if (-not $previous) { throw 'Saved default is empty; refusing to change registry.' }
    Set-ItemProperty -LiteralPath $key -Name DefaultTokenId -Value $previous
    Write-Host "Restored OneCore default: $previous"
    return
}

if (-not (Test-Path -LiteralPath $tokenKey)) { throw "Paradee OneCore token missing: $tokenKey" }
$current = (Get-ItemProperty -LiteralPath $key -Name DefaultTokenId).DefaultTokenId
if ($current -eq $token) { Write-Host 'Paradee is already the OneCore default.'; return }
if (Test-Path -LiteralPath $backup) {
    $saved = Get-Content -LiteralPath $backup -Raw
    if ($saved -ne $current) { throw "Saved default differs from current default; inspect $backup before proceeding." }
} else {
    New-Item -ItemType Directory -Path (Split-Path $backup) -Force | Out-Null
    Set-Content -LiteralPath $backup -Value $current -NoNewline
}
Set-ItemProperty -LiteralPath $key -Name DefaultTokenId -Value $token
Write-Host "OneCore default: $token"
Write-Host "Restore with: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\set-onecore-default.ps1 -Restore"
