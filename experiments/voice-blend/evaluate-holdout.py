"""Render finalist voices on text excluded from blend ranking."""

import argparse
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from onnxruntime import InferenceSession


spec = importlib.util.spec_from_file_location("rank_blends", Path(__file__).with_name("rank-blends.py"))
assert spec and spec.loader
rank = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rank)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--transcript", type=Path, required=True)
    parser.add_argument("--ranking", type=Path, required=True)
    args = parser.parse_args()
    lab = Path(__file__).resolve().parents[2] / ".cache" / "kokoro-voice-lab"
    results_dir = args.ranking.resolve().parent
    ranked = json.loads(args.ranking.read_text(encoding="utf-8"))["results"]
    names = list(dict.fromkeys([item["name"] for item in ranked[:4]] + ["af_heart", "bf_alice"]))
    text = args.transcript.read_text(encoding="utf-8").strip()
    session = InferenceSession(str(lab / "voxceleb_resnet34.onnx"), providers=["CPUExecutionProvider"])
    reference = rank.speaker_vector(session, args.reference)
    server = subprocess.Popen(
        [sys.executable, str(lab / "synth_server.py")], cwd=lab,
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        text=True, encoding="utf-8",
    )
    try:
        assert server.stdout is not None
        if not json.loads(server.stdout.readline()).get("ready"):
            raise RuntimeError("Kokoro server did not start")
        heldout = []
        for name in names:
            voice = (results_dir / "blend_bins" / f"{name}.bin") if name.startswith(("af_blend_", "am_blend_", "bf_blend_", "bm_blend_")) else (lab / "voices" / f"{name}.bin")
            output = results_dir / f"holdout_{name}.wav"
            rank.synthesize(server, voice, text, output)
            score = float(np.dot(reference, rank.speaker_vector(session, output)))
            heldout.append({"name": name, "score": round(score, 5), "wav": str(output)})
            print(f"{name}: {score:.4f} -> {output}", flush=True)
        (results_dir / "holdout-ranking.json").write_text(json.dumps(heldout, indent=2), encoding="utf-8")
    finally:
        server.terminate()
        try:
            server.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server.kill()


if __name__ == "__main__":
    main()
