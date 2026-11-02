"""Rank Kokoro voices and a small blend grid against a local reference WAV.

Uses the pinned Kokoro Voice Lab synthesis server and its speaker-model
preprocessing. Scores are screening aids; listen to the saved finalists.
"""

import argparse
import hashlib
import json
import subprocess
import sys
from itertools import combinations
from pathlib import Path

import librosa
import numpy as np
import soundfile as sf
from onnxruntime import InferenceSession


SPEAKER_SHA256 = "9fea6516d7ad6bf0a76c7689f5a49b65d330fad6dde96c91bb4435ffbfe056a1"


def speaker_vector(session: InferenceSession, path: Path) -> np.ndarray:
    audio, rate = sf.read(path, dtype="float32", always_2d=True)
    mono = audio.mean(axis=1)
    y = librosa.resample(mono, orig_sr=rate, target_sr=16000) if rate != 16000 else mono
    mel = librosa.feature.melspectrogram(
        y=y, sr=16000, n_fft=512, hop_length=160, win_length=400,
        n_mels=80, fmin=20.0, fmax=8000.0, window="hamming", power=2.0,
    )
    feats = np.log(mel.clip(min=1e-10)).T
    feats -= feats.mean(axis=0, keepdims=True)
    vector = session.run(None, {"feats": feats[np.newaxis].astype(np.float32)})[0][0]
    return vector / np.linalg.norm(vector)


def synthesize(server: subprocess.Popen, voice: Path, text: str, output: Path) -> None:
    request = {"voice": str(voice), "text": text, "out": str(output), "speed": 1.0}
    assert server.stdin is not None and server.stdout is not None
    server.stdin.write(json.dumps(request) + "\n")
    server.stdin.flush()
    response = json.loads(server.stdout.readline())
    if response.get("status") != "ok" or not output.is_file():
        raise RuntimeError(f"Kokoro synthesis failed for {voice.name}: {response}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--transcript", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out = args.out.resolve()
    args.reference = args.reference.resolve()
    args.transcript = args.transcript.resolve()
    root = Path(__file__).resolve().parents[2]
    lab = root / ".cache" / "kokoro-voice-lab"
    speaker_model = lab / "voxceleb_resnet34.onnx"
    if not speaker_model.is_file() or hashlib.sha256(speaker_model.read_bytes()).hexdigest() != SPEAKER_SHA256:
        parser.error("Pinned speaker model is missing or has the wrong SHA-256")
    text = args.transcript.read_text(encoding="utf-8").strip()
    if not text:
        parser.error("Transcript is empty")
    voices = sorted(p for p in (lab / "voices").glob("*.bin") if p.stem.startswith(("af_", "am_", "bf_", "bm_")))
    if len(voices) != 28:
        parser.error(f"Expected 28 English voices, found {len(voices)}")
    args.out.mkdir(parents=True, exist_ok=True)
    session = InferenceSession(str(speaker_model), providers=["CPUExecutionProvider"])
    reference = speaker_vector(session, args.reference)
    server = subprocess.Popen(
        [sys.executable, str(lab / "synth_server.py")], cwd=lab,
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        text=True, encoding="utf-8",
    )
    try:
        assert server.stdout is not None
        ready = json.loads(server.stdout.readline())
        if not ready.get("ready"):
            raise RuntimeError(f"Kokoro server did not start: {ready}")
        results = []
        for i, voice in enumerate(voices, 1):
            output = args.out / f"{voice.stem}.wav"
            synthesize(server, voice, text, output)
            score = float(reference @ speaker_vector(session, output))
            results.append({"name": voice.stem, "score": round(score, 5), "wav": str(output)})
            print(f"{i}/{len(voices)} {voice.stem}: {score:.4f}", flush=True)
        results.sort(key=lambda item: item["score"], reverse=True)

        # Stay within one language/gender voice family for a stable first blend.
        family = results[0]["name"][:2]
        seeds = [item["name"] for item in results if item["name"].startswith(family)][:3]
        blend_dir = args.out / "blend_bins"
        blend_dir.mkdir(exist_ok=True)
        for a, b in combinations(seeds, 2):
            for weight_a in (0.25, 0.5, 0.75):
                weight_b = 1.0 - weight_a
                name = f"{family}_blend_{a}_{b}_{int(weight_a * 100)}"
                voice = blend_dir / f"{name}.bin"
                left = np.fromfile(lab / "voices" / f"{a}.bin", dtype=np.float32)
                right = np.fromfile(lab / "voices" / f"{b}.bin", dtype=np.float32)
                if left.shape != right.shape:
                    raise RuntimeError("Voice tensor shapes differ")
                (weight_a * left + weight_b * right).astype(np.float32).tofile(voice)
                output = args.out / f"{name}.wav"
                synthesize(server, voice, text, output)
                score = float(reference @ speaker_vector(session, output))
                results.append({"name": name, "score": round(score, 5), "wav": str(output),
                                "blend": {a: weight_a, b: weight_b}})
                print(f"blend {a}/{b} {weight_a:.0%}: {score:.4f}", flush=True)
        results.sort(key=lambda item: item["score"], reverse=True)
        report = {"reference": str(args.reference), "transcript": str(args.transcript),
                  "speaker_model_sha256": SPEAKER_SHA256, "results": results}
        (args.out / "ranking.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        print("Top candidates:")
        for item in results[:8]:
            print(f"  {item['score']:.4f}  {item['name']}  {item['wav']}")
    finally:
        server.terminate()
        try:
            server.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server.kill()


if __name__ == "__main__":
    main()
