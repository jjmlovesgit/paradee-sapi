param([string] $Text = 'At 2:15 PM, Paradee reads a short sentence, clearly.')

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dll = Join-Path $repo 'build\package\bridge\paradee_sapi_bridge.dll'
$assets = Join-Path $repo 'build\native\assets'
$clsid = '{14A9D4B6-B47D-46FB-B319-6067CAFB2AD9}'
$comKey = "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\CLSID\$clsid"
$root = 'Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Speech\Voices\Tokens'
$voices = @(
    @{ Id = 'af_heart'; Token = 'ParadeeSapiAfHeart'; Lang = '0409'; Gender = 'Female' },
    @{ Id = 'bf_isabella'; Token = 'ParadeeSapiBfIsabella'; Lang = '0809'; Gender = 'Female' },
    @{ Id = 'am_puck'; Token = 'ParadeeSapiAmPuck'; Lang = '0409'; Gender = 'Male' },
    @{ Id = 'bm_fable'; Token = 'ParadeeSapiBmFable'; Lang = '0809'; Gender = 'Male' }
)
if (-not (Test-Path -LiteralPath $dll)) { throw "Build the bridge first: $dll" }
if (Test-Path -LiteralPath $comKey) { throw "Temporary COM override exists: $comKey" }
foreach ($v in $voices) {
    if (Test-Path -LiteralPath "$root\$($v.Token)") { throw "User token exists: $($v.Token)" }
}

Add-Type -AssemblyName System.Speech
try {
    $inproc = New-Item -Path "$comKey\InprocServer32" -Force
    Set-Item -LiteralPath $inproc.PSPath -Value $dll
    New-ItemProperty -LiteralPath $inproc.PSPath -Name ThreadingModel -Value Both -PropertyType String -Force | Out-Null
    foreach ($v in $voices) {
        $name = "Paradee $($v.Id)"
        $key = "$root\$($v.Token)"
        New-Item -Path "$key\Attributes" -Force | Out-Null
        Set-Item -LiteralPath $key -Value $name
        foreach ($pair in @(@('CLSID', $clsid), @('AssetsDir', $assets), @('VoiceId', $v.Id))) {
            New-ItemProperty -LiteralPath $key -Name $pair[0] -Value $pair[1] -PropertyType String -Force | Out-Null
        }
        foreach ($pair in @(@('Name', $name), @('VoiceName', $name), @('Language', $v.Lang),
                           @('Gender', $v.Gender), @('VoiceId', $v.Id), @('AssetsDir', $assets))) {
            New-ItemProperty -LiteralPath "$key\Attributes" -Name $pair[0] -Value $pair[1] -PropertyType String -Force | Out-Null
        }
    }
    foreach ($v in $voices) {
        $name = "Paradee $($v.Id)"
        $path = Join-Path $repo "build\sapi-$($v.Id).wav"
        $token = New-Object -ComObject SAPI.SpObjectToken
        $token.SetId("HKEY_CURRENT_USER\SOFTWARE\Microsoft\Speech\Voices\Tokens\$($v.Token)", '', $false)
        $voice = New-Object -ComObject SAPI.SpVoice
        $voice.Voice = $token
        $stream = New-Object -ComObject SAPI.SpFileStream
        try {
            $stream.Open($path, 3, $false)
            $voice.AudioOutputStream = $stream
            $voice.Speak($Text, 0) | Out-Null
        } finally { $stream.Close() }
        if ((Get-Item -LiteralPath $path).Length -lt 1024) { throw "Too little audio for $name" }
        Write-Host "$name -> $path"
    }
    $hashes = @($voices | ForEach-Object {
        (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repo "build\sapi-$($_.Id).wav")).Hash
    })
    if (@($hashes | Select-Object -Unique).Count -ne 4) { throw 'Two SAPI voices rendered identical audio' }
    Write-Host 'All four SAPI tokens rendered distinct audio.'
} finally {
    foreach ($v in $voices) {
        $key = "$root\$($v.Token)"
        if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse -Force }
    }
    if (Test-Path -LiteralPath $comKey) { Remove-Item -LiteralPath $comKey -Recurse -Force }
}
