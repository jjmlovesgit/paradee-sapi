$ErrorActionPreference = 'Stop'

function Show-Memory([string] $Phase) {
    $current = Get-Process -Id $PID
    [pscustomobject]@{
        Phase = $Phase
        WorkingSetMiB = [math]::Round($current.WorkingSet64 / 1MB, 1)
        PrivateMiB = [math]::Round($current.PrivateMemorySize64 / 1MB, 1)
    }
}

Add-Type -AssemblyName System.Speech
Show-Memory 'before voice'
$synth = [System.Speech.Synthesis.SpeechSynthesizer]::new()
try {
    $synth.SelectVoice('Paradee bm_fable')
    Show-Memory 'voice selected'
    $synth.Speak('Paradee is speaking through native Windows SAPI with no Python process.')
    Show-Memory 'after speech'
} finally {
    $synth.Dispose()
}
