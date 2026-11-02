param([string] $Text = ('Buongiorno a tutti. Oggi ' + [char]0x00E8 + ' una bella giornata.'))

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dll = Join-Path $repo 'build\italian\bridge\paradee_sapi_bridge.dll'
$assets = Join-Path $repo 'build\italian\native\assets'
$clsid = '{B17E11A1-9A42-40A6-8DF4-5D0F7DAA3A51}'
$comKey = "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\CLSID\$clsid"
$tokenKey = 'Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Speech\Voices\Tokens\ParadeeSapiIfSara'
if (-not (Test-Path -LiteralPath $dll)) { throw "Build the Italian bridge first: $dll" }
if (Test-Path -LiteralPath $comKey) { throw "Temporary Italian COM override already exists: $comKey" }
if (Test-Path -LiteralPath $tokenKey) { throw 'Temporary Italian voice token already exists' }

Add-Type -AssemblyName System.Speech
try {
    $inproc = New-Item -Path "$comKey\InprocServer32" -Force
    Set-Item -LiteralPath $inproc.PSPath -Value $dll
    New-ItemProperty -LiteralPath $inproc.PSPath -Name ThreadingModel -Value Both -PropertyType String -Force | Out-Null
    New-Item -Path "$tokenKey\Attributes" -Force | Out-Null
    Set-Item -LiteralPath $tokenKey -Value 'Paradee if_sara'
    foreach ($pair in @(@('CLSID',$clsid),@('AssetsDir',$assets),@('VoiceId','if_sara'))) {
        New-ItemProperty -LiteralPath $tokenKey -Name $pair[0] -Value $pair[1] -PropertyType String -Force | Out-Null
    }
    foreach ($pair in @(@('Name','Paradee if_sara'),@('VoiceName','Paradee if_sara'),@('Language','0410'),
                       @('Gender','Female'),@('VoiceId','if_sara'),@('AssetsDir',$assets))) {
        New-ItemProperty -LiteralPath "$tokenKey\Attributes" -Name $pair[0] -Value $pair[1] -PropertyType String -Force | Out-Null
    }

    $voiceToken = New-Object -ComObject SAPI.SpObjectToken
    $voiceToken.SetId('HKEY_CURRENT_USER\SOFTWARE\Microsoft\Speech\Voices\Tokens\ParadeeSapiIfSara', '', $false)
    $voice = New-Object -ComObject SAPI.SpVoice
    $stream = New-Object -ComObject SAPI.SpFileStream
    try {
        $voice.Voice = $voiceToken
        $output = Join-Path $repo 'build\italian\if_sara-sapi.wav'
        $stream.Open($output, 3, $false)
        $voice.AudioOutputStream = $stream
        $voice.Speak($Text, 0) | Out-Null
        $stream.Close()
        $bytes = (Get-Item -LiteralPath $output).Length
        if ($bytes -lt 1024) { throw "SAPI returned too little Italian audio: $bytes bytes" }
        Write-Host "Paradee if_sara rendered $bytes WAV bytes from: $Text"
    } finally { $voice = $null; $voiceToken = $null }
} finally {
    if (Test-Path -LiteralPath $tokenKey) { Remove-Item -LiteralPath $tokenKey -Recurse -Force }
    if (Test-Path -LiteralPath $comKey) { Remove-Item -LiteralPath $comKey -Recurse -Force }
}
