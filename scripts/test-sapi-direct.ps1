param(
    [string] $Text = 'Paradee is speaking through the SAPI engine.',
    [string] $OutputPath = 'build\sapi_direct.wav'
)

$ErrorActionPreference = 'Stop'
$tokenId = 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Speech\Voices\Tokens\ParadeeSapiBmFable'
$token = New-Object -ComObject SAPI.SpObjectToken
$token.SetId($tokenId, '', $false)
$voice = New-Object -ComObject SAPI.SpVoice
$voice.Voice = $token
$stream = New-Object -ComObject SAPI.SpFileStream
$fullPath = [IO.Path]::GetFullPath($OutputPath)
$directory = Split-Path -Parent $fullPath
New-Item -ItemType Directory -Path $directory -Force | Out-Null
try {
    $stream.Open($fullPath, 3, $false)
    $voice.AudioOutputStream = $stream
    $voice.Speak($Text, 0) | Out-Null
} finally {
    $stream.Close()
}
Write-Host "SAPI rendered $fullPath"
