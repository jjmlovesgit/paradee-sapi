param(
    [string] $Bridge = 'build\sapi5_bridge\paradee_sapi_bridge.dll'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$bridgePath = (Resolve-Path -LiteralPath $Bridge).Path
$classKey = 'Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\CLSID\{14A9D4B6-B47D-46FB-B319-6067CAFB2AD9}'
$logPath = Join-Path ([IO.Path]::GetTempPath()) ('paradee-resource-test-' + [guid]::NewGuid().ToString('N') + '.log')
$previousDebug = $env:PARADEE_SAPI_DEBUG
$previousLog = $env:PARADEE_SAPI_LOG
$env:PARADEE_SAPI_DEBUG = '1'
$env:PARADEE_SAPI_LOG = $logPath
if (Test-Path -LiteralPath $classKey) {
    throw "Temporary COM override already exists: $classKey"
}

$synth = $null
try {
    $inproc = New-Item -Path "$classKey\InprocServer32" -Force
    Set-Item -LiteralPath $inproc.PSPath -Value $bridgePath
    New-ItemProperty -LiteralPath $inproc.PSPath -Name ThreadingModel -Value Both -PropertyType String -Force | Out-Null

    $synth = [System.Speech.Synthesis.SpeechSynthesizer]::new()
    $synth.SelectVoice('Paradee bm_fable')
    $synth.SetOutputToNull()
    $synth.Speak('A short legitimate request still works.')

    $oversized = 'a' * 1048577
    $timer = [Diagnostics.Stopwatch]::StartNew()
    try {
        $synth.Speak($oversized)
    } catch {
        # Some SAPI hosts propagate the engine HRESULT; System.Speech may instead
        # consume it. The engine log below is the authoritative boundary check.
    } finally {
        $timer.Stop()
    }
    if ($timer.Elapsed.TotalSeconds -gt 5) {
        throw "Oversized SAPI request was not rejected promptly: $($timer.Elapsed)"
    }
    $log = Get-Content -LiteralPath $logPath -Raw
    if ($log -notmatch 'Speak textLen=39' -or $log -notmatch 'Speak ok') {
        throw 'Legitimate control request did not complete through the tested engine'
    }
    if ($log -notmatch 'Speak rejected text over limit') {
        throw 'Oversized request did not reach the engine rejection boundary'
    }

    $longText = 'Cancellation remains responsive between inference chunks. ' * 200
    $prompt = $synth.SpeakAsync($longText)
    Start-Sleep -Milliseconds 250
    $cancelTimer = [Diagnostics.Stopwatch]::StartNew()
    $synth.SpeakAsyncCancel($prompt)
    while ($synth.State -ne [System.Speech.Synthesis.SynthesizerState]::Ready -and $cancelTimer.Elapsed.TotalSeconds -lt 10) {
        Start-Sleep -Milliseconds 50
    }
    $cancelTimer.Stop()
    if ($synth.State -ne [System.Speech.Synthesis.SynthesizerState]::Ready) {
        throw 'SAPI cancellation did not complete within 10 seconds'
    }
    Write-Host "Legitimate speech succeeded; 1,048,577-character request was rejected in $([math]::Round($timer.Elapsed.TotalMilliseconds)) ms; cancellation completed in $([math]::Round($cancelTimer.Elapsed.TotalMilliseconds)) ms."
} finally {
    if ($synth) { $synth.Dispose() }
    if (Test-Path -LiteralPath $classKey) {
        Remove-Item -LiteralPath $classKey -Recurse -Force
    }
    if ($null -eq $previousDebug) { Remove-Item Env:PARADEE_SAPI_DEBUG -ErrorAction SilentlyContinue } else { $env:PARADEE_SAPI_DEBUG = $previousDebug }
    if ($null -eq $previousLog) { Remove-Item Env:PARADEE_SAPI_LOG -ErrorAction SilentlyContinue } else { $env:PARADEE_SAPI_LOG = $previousLog }
    if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath -Force }
}
