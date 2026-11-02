# Reference voice blend experiment

This is an isolated **Kokoro audition experiment**, separate from the Paradee
SAPI installer and from any student-model training. It ranks existing Kokoro
voices and blends against an authorized speaker's reference recording. A good
match is an empirical result, not a guaranteed clone.

## Reference to prepare

- Prefer 30–60 seconds of clean speech, ideally two or three passages of
  10–20 seconds. Five seconds can support a rough first look.
- One speaker, natural pace, little room echo or background sound, and no
  clipping or music. WAV mono PCM is easiest; common sample rates and stereo
  can be converted locally.
- Save the words spoken as UTF-8 text. We need them to synthesize comparable
  audio. Keep a second passage out of the matching loop for listening review.
- Store the recording outside Git, for example under `.cache/voice-reference/`
  or elsewhere on this desktop. The `.cache/` folder and WAV files are ignored
  by this repository.

Check a recording with:

```powershell
.\.cache\voice-lab-venv\Scripts\python.exe .\experiments\voice-blend\check-reference.py `
  .\.cache\voice-reference\reference.wav `
  --transcript .\.cache\voice-reference\transcript.txt
```

## Prepared local tools

The trial uses the MIT-licensed
[Kokoro Voice Lab](https://github.com/Miceprincipal/Kokoro-Voice-Lab) at commit
`418c0c4ac31adde4da5e4c7fe78bb7889ddebd70`. Its Voice Match view offers
single-voice search, blend optimization, listening previews, and a `.bin`
export. We will judge its ranking by listening to an unused passage; an
acoustic similarity score alone does not establish a good match.

The source tool's README points to `hexgrad/Kokoro-82M` for ONNX and `.bin`
files, but those files are in
[`onnx-community/Kokoro-82M-v1.0-ONNX`](https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX).
`assets-lock.json` pins model revision
`1939ad2a8e416c0acfeecc08a694d14ef25f2231` and SHA-256 for the
177 MB ONNX model, tokenizer/config files, and all 28 English voice bins.
`setup-assets.ps1` downloads and verifies them under `.cache/kokoro-voice-lab`;
it resumes interrupted downloads. `setup-env.ps1` creates an isolated Python
3.12 environment from `requirements-lock.txt` and installs a hash-checked
English spaCy model. Neither script modifies the installed Paradee voices.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\experiments\voice-blend\setup-env.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\experiments\voice-blend\setup-assets.ps1
```

On this desktop, both checks passed and Kokoro rendered a `bm_fable` smoke WAV
at 24 kHz. Voice Lab's GUI import passed. CPU inference is sufficient for the
first match; GPU setup is optional.

## First gate when the reference arrives

1. Check the WAV and transcript; select clean matching and review passages.
2. Open Voice Lab from its isolated Python environment, build fingerprints
   for the 28 English voices, and rank the stock voices against the reference.
3. Audition the top voices and a small set of blends on the matching passage.
4. Play the finalists on the held-out passage. Save a blend recipe and `.bin`
   only if the result is convincingly close to the authorized reference.
5. Decide separately whether the blend justifies Kokoro teacher-data
   generation and Paradee training. No Paradee weight changes are part of
   this gate.
