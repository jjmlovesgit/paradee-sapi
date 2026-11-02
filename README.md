# Paradee-SAPI

Paradee-SAPI makes local neural voices available to Windows
applications through SAPI 5 and OneCore voice registration. Speech synthesis
runs on the CPU, on the device, without a browser extension, background server,
or cloud TTS request.

## English voice pack

The four English voices use the Paradee v1.2 model, with one shared model and runtime:

| Voice | Style | Pronunciation |
| --- | --- | --- |
| `Paradee af_heart` | American English | American |
| `Paradee bf_isabella` | British English | British |
| `Paradee am_puck` | American English | American |
| `Paradee bm_fable` | British English | British |

SAPI-compatible applications can select an installed Paradee voice. Microsoft
Edge Read Aloud lists and plays all four voices, with word highlighting. Voice
selection is controlled by each application; registering Paradee does not make
it the default voice in every Windows app.

## Italian voice pack

The separate Italian installer provides `Paradee if_sara` and `Paradee im_nicola`.
Each uses its own Italian student model; the pack shares the SAPI runtime and
Italian eSpeak NG frontend. It can be installed alongside the English pack or
on its own. Both voices play in Edge Read Aloud with word highlighting.

Download the [Italian Windows x64 installer](https://github.com/jjmlovesgit/paradee-sapi/releases/download/v0.2.0-italian-preview.1/Paradee-SAPI-Italian-0.2.0-x64-Setup.exe).
After installing, fully stop Edge, including background `msedge.exe` processes,
and reopen it to refresh the voice list. The two-voice Italian installer passed
clean laptop checks for installation, both Edge voices, offline speech, and
uninstallation. See the [Italian pack guide](docs/ITALIAN_PACK.md).

## English offline installation

Download and run the [Windows x64 setup executable](https://github.com/jjmlovesgit/paradee-sapi/releases/download/v0.2.0/Paradee-SAPI-0.2.0-x64-Setup.exe),
then approve the administrator prompt. The installer registers the four voices
and includes the model, ONNX Runtime, eSpeak NG, and required runtime files.
Playback needs no network connection.
See the [Windows installation guide](docs/INSTALL.md) for selection,
uninstallation, troubleshooting, and compatibility details.

## Size and memory

The English four-voice installer is about **18.08 MiB**; installed files total about
**43.74 MiB**. The int8 model is about **8.5 MB**. Model file size is only one
part of runtime memory use.

On November 2, 2026, a fresh 64-bit Windows PowerShell SAPI host measured about
**78.7 MiB working set before voice selection**, **142 MiB after warm speech**,
and a **236 MiB sampled peak** while speaking. Switching among the four voices
kept working set between **140.7 and 141.7 MiB**. These host-level figures
include PowerShell, SAPI, ONNX Runtime, eSpeak NG, the model, and audio buffers;
they do not isolate model memory or represent Edge's footprint. Peak sampling
was every 20 ms, so brief spikes may be missed. See [the measurement record](docs/SAPI_PROOF.md).

## Build

On Windows, with the pinned models and build dependencies available locally,
build either offline installer with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-installer.ps1 -Version 0.2.0 -FourVoices
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-italian-installer.ps1 -Version 0.2.0
```

The build verifies dependency hashes and produces
the setup executables in `dist`. Each installer is self-contained. The project
currently packages `.exe` installers; it does not build an `.msi`.

## Project details

- [Installation guide](docs/INSTALL.md)
- [Italian pack guide](docs/ITALIAN_PACK.md)
- [Product specification and validation record](docs/SPEC.md)
- [SAPI proof and resource measurements](docs/SAPI_PROOF.md)
- [Third party notices](third_party)

Paradee and its model are published under Apache-2.0. Review the included
third-party notices for the complete dependency license information.
