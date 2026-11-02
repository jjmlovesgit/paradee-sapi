param([string] $Text = 'At 2:15 PM, Paradee reads this sentence privately.', [switch] $FourVoices)

$ErrorActionPreference = 'Stop'
$programFiles64 = if ($env:ProgramW6432) { $env:ProgramW6432 } else { $env:ProgramFiles }
$installDir = Join-Path $programFiles64 'Paradee-SAPI'
$clsid = '{14A9D4B6-B47D-46FB-B319-6067CAFB2AD9}'
$voices = @(@{ Id = 'bm_fable'; Token = 'ParadeeSapiBmFable' })
if ($FourVoices) {
    $voices = @(
        @{ Id = 'af_heart'; Token = 'ParadeeSapiAfHeart' },
        @{ Id = 'bf_isabella'; Token = 'ParadeeSapiBfIsabella' },
        @{ Id = 'am_puck'; Token = 'ParadeeSapiAmPuck' }
    ) + $voices
}
$hklm = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
    [Microsoft.Win32.RegistryHive]::LocalMachine,
    [Microsoft.Win32.RegistryView]::Registry64)
try {
    $com = $hklm.OpenSubKey("SOFTWARE\Classes\CLSID\$clsid\InprocServer32")
    if (-not $com) { throw 'Installed SAPI COM registry key is missing' }
    try {
        $dll = $com.GetValue('')
        if ($dll -ne (Join-Path $installDir 'paradee_sapi_bridge.dll')) { throw "Unexpected COM DLL: $dll" }
    } finally { $com.Dispose() }
    foreach ($item in $voices) {
        $voice = $hklm.OpenSubKey("SOFTWARE\Microsoft\Speech\Voices\Tokens\$($item.Token)")
        $oneCore = $hklm.OpenSubKey("SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens\$($item.Token)")
        if (-not $voice -or -not $oneCore) { throw "Installed SAPI registry key is missing: $($item.Id)" }
        try {
            $assets = $voice.GetValue('AssetsDir')
            if ($assets -ne (Join-Path $installDir 'assets')) { throw "Unexpected assets path: $assets" }
            if ($oneCore.GetValue('AssetsDir') -ne $assets) { throw 'OneCore assets path differs' }
            if ($voice.GetValue('CLSID') -ne $clsid -or $oneCore.GetValue('CLSID') -ne $clsid) {
                throw "Unexpected voice engine: $($item.Id)"
            }
            $attrs = $voice.OpenSubKey('Attributes')
            if (-not $attrs) { throw "Missing voice attributes: $($item.Id)" }
            try {
                if ($attrs.GetValue('VoiceId') -ne $item.Id) { throw "Wrong voice index binding: $($item.Id)" }
            } finally { $attrs.Dispose() }
        } finally { $voice.Dispose(); $oneCore.Dispose() }
    }
} finally { $hklm.Dispose() }

foreach ($name in @('paradee_sapi_bridge.dll','onnxruntime.dll','msvcp140.dll',
                    'msvcp140_1.dll','vcruntime140.dll','vcruntime140_1.dll','assets\paradee_int8.onnx',
                    'assets\espeak-ng.dll','assets\config.json','licenses\eSpeak-NG-GPL-3.0.txt')) {
    if (-not (Test-Path -LiteralPath (Join-Path $installDir $name))) { throw "Missing installed file: $name" }
}
$manifest = Get-Content -LiteralPath (Join-Path $installDir 'payload-manifest.json') -Raw | ConvertFrom-Json
foreach ($file in $manifest.files) {
    $path = Join-Path $installDir ($file.path.Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing payload file: $($file.path)" }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    if ($hash -ne $file.sha256) { throw "Payload hash mismatch: $($file.path)" }
}

Add-Type -AssemblyName System.Speech
$synth = [System.Speech.Synthesis.SpeechSynthesizer]::new()
try {
    $installed = @($synth.GetInstalledVoices() | ForEach-Object { $_.VoiceInfo.Name })
    $hashes = @()
    foreach ($item in $voices) {
        $name = "Paradee $($item.Id)"
        if ($name -notin $installed) { throw "SAPI did not enumerate $name" }
        $stream = [System.IO.MemoryStream]::new()
        try {
            $synth.SelectVoice($name)
            $synth.SetOutputToAudioStream($stream,
                [System.Speech.AudioFormat.SpeechAudioFormatInfo]::new(24000,
                    [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,
                    [System.Speech.AudioFormat.AudioChannel]::Mono))
            $synth.Speak($Text)
            if ($stream.Length -lt 1024) { throw "SAPI returned too little audio: $($stream.Length) bytes" }
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $hashes += [BitConverter]::ToString($sha.ComputeHash($stream.ToArray())) }
            finally { $sha.Dispose() }
            Write-Host "$name rendered $($stream.Length) audio bytes"
        } finally { $stream.Dispose() }
    }
    if ($FourVoices -and @($hashes | Select-Object -Unique).Count -ne 4) { throw 'Voices rendered identical audio' }
    Write-Host "Installed Paradee-SAPI passed: $($manifest.files.Count) files, $($voices.Count) voices, $installDir"
} finally {
    $synth.Dispose()
}
