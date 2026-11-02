$ErrorActionPreference = 'Stop'

function Get-Memory([string] $Phase) {
    $current = Get-Process -Id $PID
    [pscustomobject]@{
        Phase = $Phase
        WorkingSetMiB = [math]::Round($current.WorkingSet64 / 1MB, 1)
        PrivateMiB = [math]::Round($current.PrivateMemorySize64 / 1MB, 1)
    }
}

Add-Type -AssemblyName System.Speech
$results = [System.Collections.Generic.List[object]]::new()
$results.Add((Get-Memory 'before voice'))
$synth = [System.Speech.Synthesis.SpeechSynthesizer]::new()
try {
    $synth.SelectVoice('Paradee bm_fable')
    $results.Add((Get-Memory 'voice selected'))
    $text = 'Paradee is speaking through native Windows SAPI with no Python process. ' +
        'It reads another sentence so that memory can be sampled during synthesis.'
    foreach ($pass in @('cold', 'warm')) {
        $peakWorking = 0.0
        $peakPrivate = 0.0
        $null = $synth.SpeakAsync($text)
        do {
            $sample = Get-Memory "$pass speaking"
            $peakWorking = [math]::Max($peakWorking, $sample.WorkingSetMiB)
            $peakPrivate = [math]::Max($peakPrivate, $sample.PrivateMiB)
            Start-Sleep -Milliseconds 20
        } while ($synth.State -ne [System.Speech.Synthesis.SynthesizerState]::Ready)
        $results.Add([pscustomobject]@{
            Phase = "$pass sampled peak"
            WorkingSetMiB = $peakWorking
            PrivateMiB = $peakPrivate
        })
        $results.Add((Get-Memory "after $pass speech"))
    }
} finally {
    $synth.Dispose()
}
$results | Format-Table -AutoSize
