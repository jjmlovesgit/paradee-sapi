# Paradee-SAPI

Paradee-SAPI is a proposed offline Windows speech package built around the
[Paradee v1.2](https://github.com/sahilmahendrakar/paradee) CPU text-to-speech
model. Its first voice is `bm_fable`.

The product goal is to make a small, natural-sounding neural voice available
through standard Windows speech interfaces. The intended use includes reading
PII, confidential intellectual property, and regulated text without sending
that text to a speech service.

**Status:** the first SAPI proof is under development on `codex/sapi-proof`.
It uses a native bridge plus a warm, loopback-only Paradee Python process.
There is no offline installer yet. See [the working spec](docs/SPEC.md) and
[proof instructions](docs/SAPI_PROOF.md).

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
samples are intentionally excluded from this repository. The future build
instructions will pin upstream commits and model revisions and provide a fully
offline installation path.

The current proof requires its local process to be running while SAPI clients
speak. That dependency is acceptable for checking compatibility, but the
eventual installer must start the runtime automatically or host it directly.

## Attribution

Paradee is by Sahil Mahendrakar and is published under Apache-2.0. Before
distributing a packaged product, review and include required notices for
Paradee, its model files, the phonemizer, ONNX Runtime, and other dependencies.
