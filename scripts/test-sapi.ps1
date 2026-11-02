param(
    [string] $Text = 'Paradee is speaking through Windows SAPI.'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$synth = [System.Speech.Synthesis.SpeechSynthesizer]::new()
try {
    $voices = @($synth.GetInstalledVoices() | ForEach-Object { $_.VoiceInfo.Name })
    Write-Host "Installed voice names: $($voices -join ', ')"
    $synth.SelectVoice('Paradee bm_fable')
    $synth.Speak($Text)
    Write-Host 'SAPI playback completed.'
} finally {
    $synth.Dispose()
}
