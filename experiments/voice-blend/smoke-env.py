import librosa  # noqa: F401
import numpy  # noqa: F401
import onnxruntime  # noqa: F401
import scipy  # noqa: F401
import sklearn  # noqa: F401
import soundfile  # noqa: F401
import tkinter  # noqa: F401
from misaki import en


assert en.G2P(trf=False, british=True, fallback=None)("A clear voice.")[0]
print("Voice Lab dependencies and G2P OK")
