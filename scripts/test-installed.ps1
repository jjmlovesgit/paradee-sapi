param([string] $Text = 'At 2:15 PM, Paradee reads this sentence privately.')

$ErrorActionPreference = 'Stop'
$programFiles64 = if ($env:ProgramW6432) { $env:ProgramW6432 } else { $env:ProgramFiles }
$installDir = Join-Path $programFiles64 'Paradee-SAPI'
$clsid = '{14A9D4B6-B47D-46FB-B319-6067CAFB2AD9}'
$token = 'ParadeeSapiBmFable'
$hklm = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
    [Microsoft.Win32.RegistryHive]::LocalMachine,
    [Microsoft.Win32.RegistryView]::Registry64)
try {
    $com = $hklm.OpenSubKey("SOFTWARE\Classes\CLSID\$clsid\InprocServer32")
    $voice = $hklm.OpenSubKey("SOFTWARE\Microsoft\Speech\Voices\Tokens\$token")
    $oneCore = $hklm.OpenSubKey("SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens\$token")
    if (-not $com -or -not $voice -or -not $oneCore) { throw 'Installed SAPI registry keys are missing' }
    try {
        $dll = $com.GetValue('')
        $assets = $voice.GetValue('AssetsDir')
        if ($dll -ne (Join-Path $installDir 'paradee_sapi_bridge.dll')) { throw "Unexpected COM DLL: $dll" }
        if ($assets -ne (Join-Path $installDir 'assets')) { throw "Unexpected assets path: $assets" }
        if ($oneCore.GetValue('AssetsDir') -ne $assets) { throw 'OneCore assets path differs' }
    } finally {
        $com.Dispose(); $voice.Dispose(); $oneCore.Dispose()
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
$stream = [System.IO.MemoryStream]::new()
try {
    $synth.SelectVoice('Paradee bm_fable')
    $synth.SetOutputToAudioStream($stream,
        [System.Speech.AudioFormat.SpeechAudioFormatInfo]::new(24000,
            [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,
            [System.Speech.AudioFormat.AudioChannel]::Mono))
    $synth.Speak($Text)
    if ($stream.Length -lt 1024) { throw "SAPI returned too little audio: $($stream.Length) bytes" }
    Write-Host "Installed Paradee-SAPI passed: $($manifest.files.Count) files, $($stream.Length) audio bytes, $installDir"
} finally {
    $synth.Dispose()
    $stream.Dispose()
}
