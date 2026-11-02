# Working specification

## Product promise

Deliver a high-quality neural voice that runs locally on CPU with a small
complete installation, and make it usable through standard Windows speech
interfaces. Text submitted to the Paradee speech path stays on the device.
The intended settings include personal reading, restricted enterprise
documents, kiosks, ATMs, diagnostic tools, and tablets.

This promise applies to our speech path. A host application may independently
sync or transmit its documents, messages, or telemetry. Each supported
application workflow needs its own privacy and offline validation.

## First milestone: Paradee-SAPI with `bm_fable`

- Source voice: `bm_fable` from the released Paradee v1.2 four-voice int8 model.
- Target: an ordinary Windows laptop using CPU inference.
- Delivery: one offline-capable `.exe` or `.msi` installer with uninstaller.
- Windows interface: register a selectable SAPI voice and implement speech,
  voice selection, rate control, cancellation, and appropriate audio output.
- Runtime: package the model, text normalization/phonemization, inference,
  and all required dependencies. Playback must not require Chrome, a browser
  extension, a cloud TTS service, or a background download.
- Privacy: no speech-path network requests during synthesis; do not retain
  input text or generated audio unless the user deliberately saves output.
- Reliability: meaningful error reporting, repeatable installation and
  uninstallation, and operation after the network is disconnected.

## Cross-application reading requirement

Deliver reading of selected text in browsers and desktop apps through one
installed Windows executable, without a browser extension or native-messaging
host. The executable should provide an explicit global hotkey, capture only
the current selection where the source app permits copying, synthesize it
locally with Paradee, and offer stop and rate controls. Preserve the user's
clipboard when a copy-based fallback is needed. Test on Edge, Discord, and
Word with short and multi-paragraph selections.

SAPI registration remains useful for apps that select SAPI voices. It does
not make Paradee appear in every application's own voice picker. Edge's
built-in Read Aloud picker now lists and plays Paradee on the development
desktop. The planned selected-text reader is a separate user action for apps
that do not select the SAPI voice.

## Acceptance gates

1. **Baseline:** record Windows version, architecture, CPU, RAM, and native
   SAPI behavior on the target laptop. Pin upstream source and model revision.
2. **Engine:** synthesize `bm_fable` locally with the correct British
   phonemization and compare it by ear with the upstream sample.
3. **SAPI:** after installation, enumerate and select the registered voice in
   a simple SAPI test application; read text audibly; test rate, stop, and
   multi-paragraph input without truncation. Check audible pauses and phrasing
   at commas, sentence endings, questions, and paragraph boundaries against
   the upstream `bm_fable` voice.
4. **Offline and privacy:** disconnect the laptop and repeat synthesis. Inspect
   the speech process for network requests and unintended text/audio files.
5. **Resources:** record installer/download size, installed size, idle and
   speaking memory, CPU use, cold-start and warm-start time to first speech,
   and speed on a representative passage. Provisional native-runtime target:
   at most 150 MiB additional resident memory after the first utterance and
   at most 250 MiB peak for representative sentences. Measure the process
   directly for a shared worker, or the increase over the host app baseline
   for an in-process engine. Revisit these limits after native profiling.
6. **Applications:** test Office **Speak** and Excel **Speak Cells** first.
   Edge Read Aloud now discovers and plays Paradee on the development desktop
   and clean laptop. A 0.1.1 desktop test restored Edge word highlighting;
   retain punctuation, long-passage quality, and laptop validation of the new
   boundary events as separate gates. Treat
   Word/Outlook **Read Aloud**, Discord, and Narrator as separate compatibility
   gates because they may use different voice-selection paths.

On November 2, 2026, the user confirmed offline installation, offline speech,
Edge Read Aloud playback, and uninstall on the clean laptop. These close the
functional laptop checks for this test package. Rate/cancellation, resource
measurements, network/file inspection, upgrade, and other app compatibility
remain separate acceptance gates.

The desktop 0.1.1 test installation is 43.74 MiB on disk. Two PowerShell SAPI
host runs found roughly 61–63 MiB additional working set after speech and a
237.2 MiB total sampled warm-speech peak, about 158.5 MiB over the host
baseline. See `docs/SAPI_PROOF.md` for method and limits. Laptop and Edge
resource measurements remain open.

## Implementation sequence

1. Validate the Windows toolchain and dependency packaging on the development
   desktop; use the laptop for clean installation and acceptance testing.
2. Host inference in the SAPI process for the prototype; measure startup,
   cancellation behavior, and total footprint before fixing the final design.
3. Implement SAPI voice registration and minimal synthesis for `bm_fable`.
4. Package an offline installer and uninstaller; verify clean install and
   removal on the laptop.
5. Run the acceptance gates and document the measured results and limitations.
6. Add voice discovery and previews, other Paradee voices, and direct CLI/API
   surfaces for harnesses or non-SAPI devices as later milestones.

## Current evidence and open design choices

Upstream Paradee v1.2 provides four voices in one approximately 8.5 MB int8
ONNX model. The Python runtime has synthesized `bm_fable` locally in this
project's development folder with Hugging Face offline mode enabled. Its
approximately 348 MiB virtual environment shows why the full distribution
footprint must be measured and optimized.

On the development desktop, the native x64 SAPI engine rendered a non-silent
WAV and `System.Speech.GetInstalledVoices()` listed `Paradee bm_fable` after
machine-wide registration. `SelectVoice` completed playback without the
earlier Python server. Classic Windows Speech Properties also listed and
played Paradee. After a Windows reboot, Edge Read Aloud listed and played
Paradee alongside Kokoro voices. Subsequent native builds improved comma and
sentence phrasing and normalized clock times such as `2:00 PM`; the user
reported a good result in Edge. Matched-sentence listening still found the
upstream Misaki phonemizer more fluent, so pronunciation parity remains open.
The user reports that both Paradee and Kokoro voices lose
Edge's word highlighting and underline. A 0.1.1 desktop test build now emits
SAPI sentence boundaries at the exact start of each synthesized sentence and
word boundaries with exact input positions and estimated within-sentence audio
times. A controlled `System.Speech` test received seven distinct word events.
After installing this build, the user confirmed that Edge Read Aloud restored
word highlighting. Sentence underlining was not observed or verified; the
reading app controls that UI. Discord desktop TTS played Microsoft David despite Paradee
being the classic SAPI default; Windows' WinRT speech API enumerated only
Microsoft voices even with a Paradee OneCore token present. WinRT's Microsoft
signature rule does not establish which API Discord uses, so test Chromium
Web Speech voice enumeration before choosing a Discord fix. The native DLL has
no WinHTTP import. The DLL,
ONNX Runtime, int8 model, and eSpeak assets total about 42.8 MiB unpacked.
The SAPI PowerShell host rose from about 80 MiB working set before voice use
to about 149 MiB after speech, with a sampled peak of about 176 MiB. These
figures include the host. Compare native and upstream voice quality by ear,
test long passages and cancellation, and repeat measurements on the laptop.
The earlier Python backend used about 421 MiB working set and 1.26 GiB
private committed memory. A physical network-disconnected test, Office and
other application tests, and an offline installer remain open.

Still to decide: 32-bit application support, packaging format, final
performance thresholds, and the product's public name. The prototype uses
machine-wide classic SAPI plus OneCore tokens and an in-process x64 engine.
Validate these choices against the laptop and target apps before broadening
scope.

## Sources

- [Paradee upstream code and model documentation](https://github.com/sahilmahendrakar/paradee)
- [Microsoft Office Speak](https://support.microsoft.com/en-us/accessibility/office-accessibility/use-the-speak-text-to-speech-feature-to-read-text-aloud)
- [Microsoft Excel Speak Cells](https://support.microsoft.com/en-us/excel/converting-text-to-speech-in-excel)
