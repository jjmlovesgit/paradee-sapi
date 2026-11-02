"""Inspect a local reference WAV before the Kokoro blend experiment."""

import argparse
from pathlib import Path

import numpy as np
import soundfile as sf


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("wav", type=Path)
    parser.add_argument("--transcript", type=Path)
    args = parser.parse_args()

    if args.wav.suffix.lower() != ".wav":
        parser.error("Please provide a WAV file for this first experiment")
    if not args.wav.is_file():
        parser.error(f"WAV not found: {args.wav}")
    info = sf.info(args.wav)
    duration = info.frames / info.samplerate
    audio, _ = sf.read(args.wav, dtype="float32", always_2d=True)
    peak = float(np.max(np.abs(audio))) if audio.size else 0.0
    clipped = float(np.mean(np.abs(audio) >= 0.999)) if audio.size else 0.0
    rms = float(np.sqrt(np.mean(audio * audio))) if audio.size else 0.0

    print(f"File: {args.wav.resolve()}")
    print(f"Duration: {duration:.1f} seconds")
    print(f"Format: {info.samplerate} Hz, {info.channels} channel(s), {info.subtype}")
    print(f"Peak: {peak:.3f}; RMS: {rms:.3f}; clipped samples: {clipped:.2%}")
    if duration < 5:
        print("Needs more speech: at least 5 seconds for a rough match.")
    elif duration < 30:
        print("Usable for a first pass; 30–60 seconds total is preferred.")
    else:
        print("Duration is sufficient; we can select clean passages for matching and review.")
    if info.channels != 1:
        print("Stereo is acceptable; we will downmix locally before matching.")
    if clipped > 0.001:
        print("Clipping may reduce match quality; a lower recording level would help.")
    if args.transcript:
        if not args.transcript.is_file():
            parser.error(f"Transcript not found: {args.transcript}")
        words = len(args.transcript.read_text(encoding="utf-8").split())
        print(f"Transcript: {words} words")
    else:
        print("Transcript: not supplied; please provide the words spoken in the WAV.")


if __name__ == "__main__":
    main()
