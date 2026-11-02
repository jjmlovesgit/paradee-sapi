# Paradee-SAPI

Paradee-SAPI is a proposed offline Windows speech package built around the
[Paradee v1.2](https://github.com/sahilmahendrakar/paradee) CPU text-to-speech
model. Its first voice is `bm_fable`.

The product goal is to make a small, natural-sounding neural voice available
through standard Windows speech interfaces. The intended use includes reading
PII, confidential intellectual property, and regulated text without sending
that text to a speech service.

**Status:** the native x64 SAPI proof works on the Windows development desktop.
`Paradee bm_fable` appears in the installed voice list and speaks through
`System.Speech` and Microsoft Edge Read Aloud. The engine runs ONNX Runtime and
eSpeak NG inside the calling process, with no Python server at playback.
Classic SAPI and OneCore voice tokens are registered. Edge lists and plays
`Paradee bm_fable`; punctuation and phrasing quality remain an open release gate.
An offline x64 setup `.exe` can now be built from local cached runtime assets.
It installed and passed SAPI and Edge Read Aloud playback on the development
desktop, and uninstall/reinstall passed there. On a clean laptop, the user
confirmed offline installation, offline speech, Edge Read Aloud playback, and
uninstall. See the
[installation guide](docs/INSTALL.md), [working spec](docs/SPEC.md), and
[proof instructions](docs/SAPI_PROOF.md).

The current single-voice test build is `0.1.1`. It emits SAPI word and sentence
boundary events; the user confirmed that Edge Read Aloud restored **word
highlighting** with it. The clean laptop passed the `0.1.0` build; the new
`0.1.1` package is published for retesting.

The [next milestone](docs/SPEC.md#next-milestone-all-four-released-voices) is
to expose all four voices already in the model through one shared runtime.
The four-voice installer is a separate planned version; this download still
registers only `bm_fable`.

An unreleased `0.2.0` four-voice candidate can be built locally with
`scripts\build-installer.ps1 -Version 0.2.0 -FourVoices`. A desktop upgrade,
installed SAPI checks, and Edge playback of all four voices passed. Uninstall,
rollback, and clean-laptop checks remain before it replaces the published test
download.

## Memory and installed size

The four-voice `0.2.0` desktop candidate installs to about **43.74 MiB**; its
offline setup executable is about **18.08 MiB**. The Paradee int8 model itself
is about **8.5 MB**, but that is not the memory footprint of the working SAPI
host.

On November 2, 2026, a fresh 64-bit Windows PowerShell SAPI host measured about
**78.7 MiB working set before voice selection**, **142 MiB after warm speech**,
and a **236 MiB sampled peak** while speaking. Switching among all four voices
kept working set between **140.7 and 141.7 MiB**. These figures include
PowerShell, SAPI, ONNX Runtime, eSpeak NG, the model, and audio buffers in the
same process. They do not isolate the model or measure Edge's memory use. Peak
sampling was every 20 ms, so very brief spikes may be missed. See
[`docs/SAPI_PROOF.md`](docs/SAPI_PROOF.md) for the measurement details.

## Current test download

This is a **private prerelease for testing**, not a production release. Sign in
to GitHub as a user with access to this repository, then download the
[Windows x64 installer](https://github.com/jjmlovesgit/paradee-sapi/releases/download/0.1.1-test/Paradee-SAPI-0.1.1-x64-Setup.exe)
and [SHA-256 checksum file](https://github.com/jjmlovesgit/paradee-sapi/releases/download/0.1.1-test/SHA256SUMS-0.1.1.txt).
The [release page](https://github.com/jjmlovesgit/paradee-sapi/releases/tag/0.1.1-test)
also lists both files under **Assets**. A browser that is not signed in to the
private repository may show 404.

1. On the laptop, verify the downloaded installer in PowerShell with
   `Get-FileHash .\Paradee-SAPI-0.1.1-x64-Setup.exe -Algorithm SHA256`. The
   expected SHA-256 is
   `ee1708f7f087fd52634d03ca53548afc84dea8e061f568eb283d102f2e937ead`.
2. Disconnect the laptop from the network, run the installer, and approve the
   Windows administrator prompt. Installation must finish without downloading
   anything.
3. While still offline, open Windows Speech Properties, choose
   **Paradee bm_fable** on the **Text to Speech** tab, and use **Preview Voice**.
4. Reconnect, restart Edge, open a page, start **Read Aloud**, and select
   **Paradee bm_fable** in Voice options. Check commas, questions, and clock
   times such as `2:00 PM` and `2:15 PM`.
5. Confirm Edge word highlighting follows Paradee speech. Close Edge and
   uninstall from **Settings → Apps → Installed apps**. Confirm the voice
   disappears; run the same installer again if you want to keep it.

Record any missing voice, failed playback, reboot requirement, or installer
error. The full [installation guide](docs/INSTALL.md) has troubleshooting and
current compatibility limits.

## Build the offline installer

On the Windows build desktop, with the pinned Paradee model, ONNX Runtime SDK,
eSpeak NG wheel, Visual Studio C++ tools, and build-time Python dependencies
already cached, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-installer.ps1
```

The script verifies the locked runtime hashes, stages the playback assets and
license notices, and creates `dist\Paradee-SAPI-0.1.0-x64-Setup.exe` by default. It uses a
checksum-verified portable NSIS compiler if one is not already cached. The
installer itself is self-contained and does not download anything. It is an
`.exe` setup package; an `.msi` is not built yet. To build the desktop
boundary-event test version, pass `-Version 0.1.1` to the build script, then
run `scripts\test-boundaries.ps1` to verify SAPI word positions and timing.

## Milestone 1

Install `bm_fable` as a selectable SAPI voice on a Windows laptop and confirm
that a SAPI-compatible app can speak through it while the laptop is offline.
Measure the complete installed size, CPU and memory use, time to first speech,
and voice quality. Office and other app compatibility are explicit test gates.

## Upstream engine smoke test

The upstream Paradee v1.2 Python package has synthesized a `bm_fable` WAV on
Windows with Hugging Face offline mode enabled. The development environment
occupied about 348 MiB, while the int8 model is about 8.5 MB. That development
environment is not the proposed install package.

The local virtual environment, model cache, cloned upstream source, and audio
samples are intentionally excluded from this repository. The installer build
recipe pins the model revision and runtime file hashes; these assets are
bundled into the offline setup executable.

The current proof loads inference into the SAPI client process. Its runtime
assets total about 42.8 MiB unpacked on this desktop. Voice quality comparison,
laptop resource measurements, upgrade testing, and broader app compatibility
remain open.

## Attribution

Paradee is by Sahil Mahendrakar and is published under Apache-2.0. Before
distributing a packaged product, review and include required notices for
Paradee, its model files, the phonemizer, ONNX Runtime, and other dependencies.
