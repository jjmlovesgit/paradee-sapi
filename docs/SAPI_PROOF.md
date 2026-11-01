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

## Application compatibility observed

- Classic Windows Speech Properties lists `Paradee bm_fable` and its Preview
  Voice button plays it. The per-user classic SAPI default is Paradee.
- Discord desktop TTS played Microsoft David in the user's test, so Discord
  compatibility has **not** been achieved. The per-user OneCore default is
  David. `Windows.Media.SpeechSynthesis.SpeechSynthesizer.AllVoices` enumerated
  only Microsoft David, Zira, and Mark on this desktop, despite the Paradee
  OneCore registry token. This suggests the OneCore token alone does not make
  this SAPI engine available to modern app speech APIs. Do not switch the
  OneCore default to Paradee until that API can instantiate it successfully.

## Remaining gates

- Listen to matched native and upstream `bm_fable` samples and check
  pronunciation and naturalness. eSpeak plus phoneme conversion may differ
  from the upstream Python Misaki path.
- Test cold and warm latency, stop/pause behavior, sentence boundaries, and
  longer text in real applications. The current tokenizer caps a synthesis
  call at 510 phoneme tokens, so long inputs need chunking before acceptance.
- Confirm the OneCore token appears and plays in each target Read Aloud picker;
  category enumeration alone does not prove app compatibility.
- Make a self-contained offline installer, include license notices and any
  required Visual C++ runtime, and test clean install/uninstall on the laptop.
- Disconnect the laptop from the network and verify synthesis plus absence of
  speech-path network calls and unintended text/audio files.
- Add an x86 engine only if a required 32-bit Windows application needs it.
