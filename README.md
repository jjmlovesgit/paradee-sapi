# Paradee-SAPI

Paradee-SAPI makes local neural voices available to Windows
applications through SAPI 5 and OneCore voice registration. Speech synthesis
runs on the CPU, on the device, without a browser extension, background server,
or cloud TTS request.

Its compact installers, CPU-only operation, and support for multiple offline
voices make it well suited to small local installations, kiosks, robots,
air-gapped systems, and other deployments where privacy, limited storage, and
independence from cloud speech services matter.

## Download a language pack

| Language | Voices | Offline installer |
| --- | ---: | --- |
| English | 4 | [Download English 0.2.0](https://github.com/jjmlovesgit/paradee-sapi/releases/download/v0.2.0/Paradee-SAPI-0.2.0-x64-Setup.exe) |
| Italian | 2 | [Download Italian 0.2.0](https://github.com/jjmlovesgit/paradee-sapi/releases/download/v0.2.0-italian-preview.1/Paradee-SAPI-Italian-0.2.0-x64-Setup.exe) |

Both installers are self-contained Windows x64 packages. The Italian pack can
be installed alongside the English pack or by itself.

## Accessibility and NVDA

Paradee-SAPI has been tested with [NVDA 2026.3](https://www.nvaccess.org/download-nvda/)
through its 64-bit SAPI 5 synthesizer driver. NVDA discovered all six installed
Paradee voices. Using `Paradee bm_fable`, line and word navigation, continuous
reading, WASAPI audio output, and interruption of speech when the cursor moved
all worked. The user reported that the voice was responsive and sounded very
good during the test.

This is an initial compatibility result rather than formal accessibility
certification. Accelerated speech and extended browser browse-mode testing are
still planned.

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

The two Italian voices each use their own student model, with a shared runtime:

| Voice | Style | Pronunciation |
| --- | --- | --- |
| `Paradee if_sara` | Female Italian | Italian |
| `Paradee im_nicola` | Male Italian | Italian |

The pack shares the SAPI runtime and Italian eSpeak NG frontend. It can be
installed alongside the English pack or on its own. Both voices play in Edge
Read Aloud with word highlighting.

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

## Upstream projects and acknowledgments

Paradee-SAPI is a Windows integration and packaging project built on the work
of these upstream creators:

- **[Paradee by Sahil Mahendrakar](https://github.com/sahilmahendrakar/paradee)**
  provides the tiny neural TTS architecture, training work, and English
  Paradee v1.2 model used by the English voice pack.
- **[MithrilMan on Hugging Face](https://huggingface.co/MithrilMan)** provides
  the teacher-in-the-loop work and Italian student models used for the
  `if_sara` and `im_nicola` Italian voice pack.

Paradee and its model are published under Apache-2.0. Review the included
[third-party notices](third_party/NOTICES.md) for pinned sources, dependency
licenses, and complete attribution details.
