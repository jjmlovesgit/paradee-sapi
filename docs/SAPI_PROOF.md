# Windows native SAPI proof

This prototype validates `bm_fable` through Windows SAPI on an x64 development
desktop. The current DLL runs Paradee inference **in the calling process**. It
uses local ONNX Runtime and eSpeak NG assets, requires no Python process at
playback, and has no WinHTTP import. It is not yet a clean offline installer.

The COM/SAPI shell was adapted from the MIT-licensed SAPI code in
[`zotero-minimax-tts`](https://github.com/howardLHY/zotero-minimax-tts/tree/main/tools/sapi5);
its license is retained beside the source. The native phoneme conversion
follows Paradee's `web/misaki.js` mapping for British voices. Perceptual
comparison with upstream Misaki output remains a quality gate.

## Build inputs

- Windows x64 and Visual Studio C++ Build Tools with the Windows SDK.
- ONNX Runtime native SDK 1.31.1 in `.cache/ort-native/onnxruntime-win-x64-1.31.1`.
- Cached Paradee v1.2 int8 model and `config.json` in `.cache/huggingface`.
- eSpeak NG DLL and data from the development `.venv` package `espeakng-loader`.
- Python in `.venv` is used only at build time to generate the C++ vocabulary
  table from Paradee's `config.json`.

The build script copies model and runtime assets into ignored `build/`
directories. The model and binary dependencies are not committed to Git.
Pinning downloads, reviewing redistribution licenses, and eliminating Python
from the build setup remain packaging tasks before a laptop install.

## Build and test on the desktop

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-native.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-bridge.ps1
```

Run the standalone renderer to compare its audio with the upstream Python
voice:

```powershell
.\build\native\paradee_native.exe "Paradee can read this text privately on this computer." build\native\bm_fable_native.wav build\native\assets
```

Machine-wide registration requires an elevated PowerShell session. The script
registers both classic SAPI and OneCore tokens; it does not change the Windows
default voice.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register-voice.ps1 -Scope LocalMachine
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-sapi.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\measure-sapi.ps1
```

Without elevation, a per-user token can be used for direct SAPI testing, but
`System.Speech` did not enumerate that token on this machine:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register-voice.ps1 -Scope CurrentUser
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-sapi-direct.ps1
```

Remove the exact tokens and COM registration created by this prototype with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register-voice.ps1 -Scope LocalMachine -Uninstall
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register-voice.ps1 -Scope CurrentUser -Uninstall
```

## Measured result

Development desktop: Windows 11 Home x64, build 26300, AMD Ryzen 9 9950X,
approximately 64 GiB RAM. `Paradee bm_fable` appeared in
`System.Speech.GetInstalledVoices()`, `SelectVoice` completed audible playback,
and SAPI wrote a non-silent WAV with no backend server running. The OneCore
token also enumerated in the OneCore SAPI category. The native DLL's imports
include `onnxruntime.dll` and no `WINHTTP.dll`.

The native DLL, ONNX Runtime DLL, model, and full eSpeak data tree total about
42.8 MiB unpacked. In a short standalone rendering test, the native CLI
reached about 139 MiB peak working set and 179 MiB peak private memory. In a
SAPI PowerShell host, memory rose from about 80 MiB before voice use to about
149 MiB after speech. A sampled peak during playback was about 176 MiB for
the whole host. These are desktop prototype measurements, not laptop results.

The earlier Python/loopback proof used about 421 MiB working set and 1.26 GiB
private committed memory in its warm backend. Its source remains for
comparison, but the current bridge build excludes the HTTP path.

For a provisional same-host comparison with Kokoro-SAPI's quantized model,
fresh PowerShell processes each selected one machine-wide SAPI voice and
rendered the same short sentence to a WAV file. Both started near 74 MiB
working set. Paradee rose to 132.2 MiB after speech (about +58 MiB) and
peaked at 236.1 MiB; Kokoro Michael rose to 307.9 MiB after speech (about
+234 MiB), also its observed peak. The Paradee model file is 8,462,119 bytes
versus Kokoro's quantized 92,361,116-byte model file. This is one cold-process
comparison of working set, not a benchmark of Edge memory or time to first
audio; Kokoro's SAPI engine paces audio writes, so total call duration would
not isolate model loading latency.

## Application compatibility observed

- Classic Windows Speech Properties lists `Paradee bm_fable` and its Preview
  Voice button plays it. The per-user classic SAPI default is Paradee.
- Discord desktop TTS played Microsoft David in the user's test, so Discord
  compatibility has **not** been achieved. The per-user OneCore default is
  David. `Windows.Media.SpeechSynthesis.SpeechSynthesizer.AllVoices` enumerated
  only Microsoft David, Zira, and Mark on this desktop, despite the Paradee
  OneCore registry token. Microsoft's WinRT API permits only Microsoft-signed
  voices. This does not prove which API Discord calls: Chromium's Windows Web
  Speech implementation enumerates SAPI and OneCore tokens through SAPI COM.
  Next isolate Discord's TTS path and test Chromium `speechSynthesis.getVoices()`
  before concluding whether a registry/selection fix is possible. Do not
  switch the OneCore default to Paradee based on the WinRT list.
- In an earlier test, Microsoft Edge's `speechSynthesis.getVoices()` returned
  Microsoft local David, Mark, and Zira plus online Microsoft voices, but no
  Paradee. A local diagnostic HTML page under ignored `build/diagnostics/`
  produced that list. After the Windows reboot, the user showed Edge Read
  Aloud's voice picker listing Paradee `bm_fable` and Kokoro Emma, Heart,
  Michael, and Bella, and reported that Edge can play both engines. Edge
  voice discovery and basic playback therefore pass on this desktop. The
  earlier negative observation was transient or came from a different voice
  enumeration state; its precise cause is unknown. Paradee's punctuation and
  phrasing are still below the desired quality. The user also observed that
  Edge Read Aloud's word highlighting and underline disappeared with the
  original Paradee and Kokoro voices. The 0.1.0 Paradee build emitted no SAPI
  boundary events. A later 0.1.1 desktop test build emits sentence and word
  boundaries, and the user confirmed that Edge restored word highlighting.
  Sentence underlining was not verified. Kokoro's separate behavior still
  requires its own diagnosis.
- Chrome reading mode offered a generic "System text-to-speech voice" but
  played Microsoft David when the OneCore default pointed at the en-GB
  Paradee token. An experimental en-US alias of the same British voice was
  registered machine-wide and made the OneCore default; it enumerated and
  played through SAPI COM, but the user still did not hear or see Paradee in
  Chrome. The alias was removed and the previous David OneCore default was
  restored. Chrome reading-mode compatibility is therefore unproven and the
  registry/default-voice approach did not meet this app gate.

Kokoro-SAPI's README describes Chrome reading mode as a supported use case.
Its installer registers HKLM SAPI and OneCore tokens and sets the user's
OneCore `DefaultTokenId`. On this desktop, Kokoro-SAPI v0.1.0 was installed
with its quantized model and machine-wide registration. Its setup smoke test
spoke Kokoro Heart, and SAPI COM enumerated Kokoro Heart, Bella, Michael, and
Emma from the OneCore category alongside Paradee. After Chrome was fully
restarted and "System text-to-speech voice" was selected in reading mode, the
user heard Microsoft David. Kokoro's engine log showed no new speech call from
Chrome. The pre-test defaults were restored: classic SAPI to Paradee and
OneCore to David; Kokoro remains installed for further comparison. This
control shows the Chrome failure is not yet attributable to a Paradee-only
registration or engine defect. We still need to identify which voice source
this Chrome reading-mode path actually selects on this machine.

Speech Properties listed the Kokoro voices, but none passed its Preview Voice
button in the user's test; `Kokoro Michael (en-US)` reported "This voice cannot
be played." Microsoft and Paradee voices did preview in the same panel.
Kokoro's own setup
test selected a per-user token, so we separately tested the machine-wide
`KokoroMichael` classic SAPI token through `SAPI.SpVoice`; it spoke. Selecting
the same voice through `.NET System.Speech` also spoke. The panel's exact
preview sentence also spoke through direct machine-wide SAPI. Thus the screenshot is
a Speech Properties preview compatibility failure, not evidence that the
machine-wide token or model cannot synthesize. The control panel's specific
failure has not yet been traced. Direct asynchronous `SAPI.SpVoice.Speak`
also completed with both `SPF_ASYNC` and `SPF_ASYNC | SPF_PURGEBEFORESPEAK`,
so asynchronous speaking alone does not reproduce the panel failure.
After a Windows reboot on the same desktop, Speech Properties previewed
Kokoro Michael without the error and the user heard the voice. The earlier
preview failure was therefore transient across the reboot; its immediate
cause remains unknown. Chrome Reading mode was not retested after the reboot.
The temporary Kokoro Heart OneCore default used to prepare that test was
restored to Microsoft David when the user could not run it.

An earlier isolated test setting the OneCore default to Paradee moved Paradee
to the first position in SAPI OneCore token enumeration, while WinRT
`AllVoices` still returned only Microsoft voices. That previous default was
restored after the test. `scripts/set-onecore-default.ps1` remains available
for a reversible OneCore test.

## Remaining gates

- The installed native build now preserves internal commas, semicolons, colons,
  and sentence-final punctuation as model input tokens. It splits longer text
  before the model's 510-phoneme limit rather than silently truncating it.
  After installation, the user reported substantially better Edge Read Aloud
  phrasing on real webpages. Matched-sentence listening still found upstream
  Paradee more fluent than this eSpeak-based native frontend.
- The next quality gate is phoneme parity with upstream Misaki for `bm_fable`.
  Upstream uses its British English lexicon and contextual rules with eSpeak
  only as fallback; the current native engine applies a conversion to eSpeak
  output for every word. The British gold and silver lexicon JSON files in
  the development Misaki package total about 6.5 MB, so a compiled local
  lexicon may preserve a small offline runtime. A direct JSON lookup alone
  would not reproduce context-dependent pronunciation, stress, and number
  handling; compare phoneme strings and audio on representative sentences
  before choosing a native port design.
- The Edge punctuation build initially read `2:00 PM`, `2:15 PM`, and `7:00 PM`
  incorrectly. The follow-up native build normalizes clock times to spoken
  words before phonemization. It was installed at the existing registered DLL
  path, passed a SAPI render of the time examples, and the user reported the
  result was excellent in Edge. Continue testing other time formats and
  numbers on real pages.
- Test cold and warm latency, stop/pause behavior, sentence boundaries, and
  longer text in real applications. Long text now chunks before the 510-phoneme
  limit, but the SAPI bridge still ignores silence actions and some fragment
  controls. Compare matched passages with upstream Paradee before declaring
  reading quality complete.
- The 0.1.1 desktop test bridge calls `ISpTTSEngineSite::AddEvents` for sentence
  and word boundaries. Sentence audio starts are exact; word audio positions
  are estimated because the Paradee ONNX interface returns waveform only.
  `scripts/test-boundaries.ps1` verified seven word positions against the
  source text and distinct audio positions through `System.Speech`. A retest in
  Edge Read Aloud restored word highlighting on the development desktop after
  installing this build. The 0.1.0 laptop installer does not contain this fix;
  0.1.1 laptop retesting and sentence underline behavior remain open.
- Confirm the OneCore token appears and plays in each target Read Aloud picker;
  category enumeration alone does not prove app compatibility.
- The self-contained setup `.exe` now includes license notices and the app-local
  Visual C++ runtime. Desktop uninstall/reinstall passed. The user confirmed
  clean laptop installation, offline speech, Edge playback, and uninstall with
  0.1.0; a clean laptop retest of 0.1.1 and
  upgrade to a newer package remains open.
- Offline laptop speech passed. Inspect speech-path network calls and
  unintended text/audio files separately before making a stronger privacy
  claim.
- Add an x86 engine only if a required 32-bit Windows application needs it.

## Offline setup proof on the development desktop

The 0.1.0 NSIS setup executable is 18,958,575 bytes. It contains the SAPI DLL,
ONNX Runtime, the Paradee model/configuration, eSpeak NG DLL/data, four app-local
Visual C++ runtime DLLs, the installation guide, and third-party notices. The
staged manifest verifies 382 files, and a copy of the staged runtime rendered
speech from a separate folder without relying on the project path.

The visible installer completed after administrator approval. It created
`C:\Program Files\Paradee-SAPI`, registered the classic SAPI and OneCore voice
tokens against that installed path, and added an Installed Apps uninstall entry.
All 382 installed payload files matched the staged manifest. The
`scripts/test-installed.ps1` check selected `Paradee bm_fable` through
`System.Speech` and rendered 220,800 audio bytes. The user then selected it in
Edge Read Aloud and reported that it played and sounded good from the packaged
installation. With Edge closed, silent uninstall removed the voice token,
COM registration, Installed Apps entry, and package directory. Reinstalling
the same setup restored all 382 files and passed the SAPI speech test again.
Upgrade to a newer package remains to be verified.

On November 2, 2026, the user confirmed that installation while offline,
speech while offline, Edge Read Aloud playback, and uninstall all passed on a
clean laptop. This was a user-reported functional test; no laptop memory,
latency, network-call, or unintended-file measurements were recorded.

## Desktop 0.1.1 footprint sample

The installed `C:\Program Files\Paradee-SAPI` directory contains 384 files
totaling 45,862,643 bytes (43.74 MiB). The 0.1.1 setup executable is
18,960,057 bytes (18.08 MiB). On November 2, 2026,
`scripts/measure-sapi.ps1` measured a fresh Windows PowerShell SAPI host twice,
speaking the same two-sentence passage cold and warm in each run. Its working
set was 78.6–78.7 MiB before voice selection, 139.5–139.7 MiB after cold
speech, and 141.6–141.8 MiB after warm speech: roughly 61–63 MiB additional
resident memory after speaking. The warm-speech peak sampled every 20 ms was
237.2 MiB total, roughly 158.5 MiB over the host baseline. The corresponding
private-byte peak was 209.4–209.5 MiB total. These figures include PowerShell,
`System.Speech`, SAPI, synthesis, and audio buffering in one process; they do
not isolate the Paradee model or measure Edge's process footprint. Peaks faster
than the sampling interval may be missed.

## Desktop 0.2.0 four-voice candidate

On November 2, 2026, the 0.2.0 offline installer upgraded the development
desktop from 0.1.1 after Edge was fully closed. `scripts/test-installed.ps1
-FourVoices` verified the installed payload manifest, four classic SAPI and
OneCore tokens, and distinct SAPI audio from each voice. The installed folder
contains 384 files totaling 45,865,493 bytes (43.74 MiB); the setup executable
is 18,960,588 bytes (18.08 MiB). `scripts/measure-sapi.ps1 -AllVoices`
measured a fresh PowerShell SAPI host at 78.7 MiB working set before voice
selection, 142 MiB after warm `bm_fable` speech, and 140.7–141.7 MiB after
switching through the four voices. The sampled warm peak was 236 MiB total.
This supports a shared model session in that host; Edge and laptop memory
remain unmeasured. Edge playback, uninstall/rollback, and clean-laptop
validation remain open.
