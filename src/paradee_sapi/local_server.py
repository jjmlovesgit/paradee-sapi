"""Warm local Paradee backend for the SAPI proof of concept.

The server binds only to loopback and never writes text or audio to disk.
"""

from __future__ import annotations

import io
import json
import math
import threading
import wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import numpy as np
from paradee import Paradee, SAMPLE_RATE


HOST = "127.0.0.1"
PORT = 5057
MAX_REQUEST_BYTES = 32_768
MAX_TEXT_CHARS = 5_000
SYNTH_LOCK = threading.Lock()


def to_wav(text: str, speed: float, engine: Paradee) -> bytes:
    with SYNTH_LOCK:
        audio = engine(text, speed=speed, voice="bm_fable")
    pcm = (np.clip(audio, -1, 1) * 32767).astype("<i2")
    output = io.BytesIO()
    with wave.open(output, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(pcm.tobytes())
    return output.getvalue()


def make_handler(engine: Paradee) -> type[BaseHTTPRequestHandler]:
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format: str, *args: object) -> None:
            # Do not log request text or generated audio.
            pass

        def do_GET(self) -> None:
            if self.path != "/health":
                self.send_error(404)
                return
            body = b'{"status":"ok","voice":"bm_fable"}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self) -> None:
            if self.path != "/v1/speech":
                self.send_error(404)
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if length <= 0 or length > MAX_REQUEST_BYTES:
                    raise ValueError("request size")
                data = json.loads(self.rfile.read(length))
                text = data.get("input")
                voice = data.get("voice")
                speed = float(data.get("speed", 1.0))
                if not isinstance(text, str) or not 0 < len(text) <= MAX_TEXT_CHARS:
                    raise ValueError("text")
                if voice != "bm_fable" or not math.isfinite(speed) or not 0.5 <= speed <= 2.0:
                    raise ValueError("voice or speed")
            except (ValueError, TypeError, json.JSONDecodeError):
                self.send_error(400)
                return

            try:
                body = to_wav(text, speed, engine)
            except Exception as exc:
                print(f"Synthesis failed: {type(exc).__name__}", flush=True)
                self.send_error(500)
                return
            self.send_response(200)
            self.send_header("Content-Type", "audio/wav")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    return Handler


def main() -> None:
    engine = Paradee(version="1.2", quantized=True, threads=1)
    engine.g2p(british=True)  # Warm Misaki before accepting SAPI requests.
    server = ThreadingHTTPServer((HOST, PORT), make_handler(engine))
    print(f"Paradee bm_fable ready at http://{HOST}:{PORT}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
