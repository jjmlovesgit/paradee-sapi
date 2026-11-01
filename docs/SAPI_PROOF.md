# Windows SAPI proof of concept

This prototype validates `bm_fable` through classic Windows SAPI on an x64
Windows desktop. It is **not** the offline installer or size-optimized runtime.
It keeps Paradee loaded in a Python process on `127.0.0.1:5057` and uses a
native SAPI DLL to pass text to that local process and return 24 kHz PCM.
The bridge was adapted from the MIT-licensed SAPI code in
[`zotero-minimax-tts`](https://github.com/howardLHY/zotero-minimax-tts/tree/main/tools/sapi5);
its license is retained beside the source.

## Prerequisites

- Windows x64 and Visual Studio C++ Build Tools with the Windows SDK.
- A `.venv` containing Paradee v1.2, its dependencies, and spaCy's
  `en_core_web_sm` English model.
- Cached Paradee v1.2 int8 model and configuration in `.cache/huggingface`.

The setup scripts will be made reproducible and pinned before laptop testing.
The Python environment and model cache remain outside Git.

## Build and run on the development desktop

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-bridge.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-local-server.ps1
```

Leave the server running in its own terminal. In another terminal, register
the voice. Machine-wide registration requires an elevated PowerShell session.
Per-user registration can be used for direct-token experiments but is not
enumerated by `System.Speech` on this machine.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register-voice.ps1 -Scope LocalMachine
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-sapi.ps1
```

Without elevation, register in the current-user hive and render directly
through SAPI's token API:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register-voice.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-sapi-direct.ps1
```

The direct test succeeded on the development desktop and produced a non-silent
WAV. With machine-wide registration, `System.Speech.GetInstalledVoices()` also
listed `Paradee bm_fable`, and `SelectVoice('Paradee bm_fable')` played speech.
This establishes classic SAPI discovery and synthesis on this machine; Office,
Discord, Narrator, and a clean laptop still need separate checks.

Development baseline: Windows 11 Home x64, build 26300, AMD Ryzen 9 9950X,
approximately 64 GiB RAM. Visual Studio 2022 C++ tools built the bridge DLL
at 231,424 bytes. The existing Python environment is approximately 348 MiB.
After synthesis, the warm Python backend measured approximately 421 MiB
working set and 1.26 GiB private committed memory on this desktop. These are
proof-runtime measurements, not targets for the final package.

Remove exactly the keys created by this proof with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register-voice.ps1 -Scope LocalMachine -Uninstall
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register-voice.ps1 -Scope CurrentUser -Uninstall
```

## Boundaries of the proof

- The bridge accepts only the fixed loopback endpoint and path. It disables
  proxy use. The server binds only to loopback and does not log text or audio.
- A local HTTP server is a temporary implementation choice. All speech bytes
  stay on the device, but the final product may use an in-process engine.
- Synthesis is buffered before SAPI receives audio. Interruption during the
  HTTP request and precise word boundaries are not yet implemented.
- The bridge is x64 only. Some 32-bit apps will require an additional build.
- This prototype registers classic SAPI. OneCore and Narrator/Chromium
  compatibility need separate validation.
