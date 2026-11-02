param(
    [string] $Text = 'First sentence. Next at 2:00 PM.',
    [string] $Bridge = 'build\sapi5_bridge\paradee_sapi_bridge.dll'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$bridgePath = (Resolve-Path -LiteralPath $Bridge).Path
$classKey = 'Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\CLSID\{14A9D4B6-B47D-46FB-B319-6067CAFB2AD9}'
if (Test-Path -LiteralPath $classKey) {
    throw "Temporary COM override already exists: $classKey"
}

$events = [System.Collections.Generic.List[object]]::new()
$outputPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'build\boundary-test.wav'
$synth = $null
try {
    $inproc = New-Item -Path "$classKey\InprocServer32" -Force
    Set-Item -LiteralPath $inproc.PSPath -Value $bridgePath
    New-ItemProperty -LiteralPath $inproc.PSPath -Name ThreadingModel -Value Both -PropertyType String -Force | Out-Null

    $synth = [System.Speech.Synthesis.SpeechSynthesizer]::new()
    $synth.SelectVoice('Paradee bm_fable')
    $synth.Add_SpeakProgress({
        param($sender, $event)
        $events.Add([pscustomobject]@{
            Position = $event.CharacterPosition
            Count = $event.CharacterCount
            Text = $event.Text
            AudioPosition = $event.AudioPosition
        })
    })
    $synth.SetOutputToWaveFile($outputPath)
    $synth.Speak($Text)
    $synth.SetOutputToNull()
} finally {
    if ($synth) { $synth.Dispose() }
    if (Test-Path -LiteralPath $classKey) {
        Remove-Item -LiteralPath $classKey -Recurse -Force
    }
}

$expected = @([regex]::Matches($Text, "[\p{L}\p{N}]+(?:['’][\p{L}\p{N}]+)*"))
if ($events.Count -ne $expected.Count) {
    throw "Expected $($expected.Count) word boundaries; received $($events.Count)."
}
for ($i = 0; $i -lt $events.Count; $i++) {
    $event = $events[$i]
    if ($event.Position -ne $expected[$i].Index -or
        $event.Count -ne $expected[$i].Length) {
        throw "Incorrect boundary for '$($expected[$i].Value)' at index $i."
    }
    $actual = $Text.Substring($event.Position, $event.Count)
    if ($actual -ne $event.Text) {
        throw "Boundary mismatch at $($event.Position): '$actual' != '$($event.Text)'"
    }
}
for ($i = 1; $i -lt $events.Count; $i++) {
    if ($events[$i].AudioPosition -le $events[$i - 1].AudioPosition) {
        throw "Audio boundary times did not advance between '$($events[$i - 1].Text)' and '$($events[$i].Text)'."
    }
}
$events | Format-Table -AutoSize
Write-Host "Verified $($events.Count) word boundaries against input text; audio: $outputPath"
