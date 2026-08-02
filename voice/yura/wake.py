import os
import time
import wave

import numpy as np

from .const import DATA_DIR, SR
from .log import log

BUNDLED_WAKEWORD = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "models", "hey_yura.onnx")
WAKEWORD = os.environ.get("YURA_WAKEWORD") or (
    BUNDLED_WAKEWORD if os.path.exists(BUNDLED_WAKEWORD) else "hey_jarvis")
WAKE_THRESHOLD = float(os.environ.get("YURA_WAKE_THRESHOLD", "0.5"))
# Consecutive frames that must clear the threshold. Real utterances hold a
# plateau across several 80 ms frames; media speech tends to spike on one.
WAKE_PATIENCE = int(os.environ.get("YURA_WAKE_PATIENCE", "2"))
# The wake model is confidently wrong on out-of-domain mechanical noise
# (washing machines scored 0.7-0.9); a trigger only counts if the VAD saw
# something speech-like in the last second.
WAKE_VAD_GATE = float(os.environ.get("YURA_WAKE_VAD_GATE", "0.3"))
# Per-user model that re-scores a wake as "was this the owner's voice" — the
# only defense against another *human* voice (a phone video) saying the phrase.
# Enrollment (POST /enroll) trains it; dormant until the file exists.
VERIFIER_DIR = os.path.join(DATA_DIR, "verifier")
WAKE_VERIFIER = os.path.expanduser(os.environ.get(
    "YURA_VERIFIER", os.path.join(VERIFIER_DIR, "hey_yura_verifier.pkl")))
WAKE_VERIFIER_THRESHOLD = float(os.environ.get("YURA_VERIFIER_THRESHOLD", "0.4"))
ENROLL_CLIPS = int(os.environ.get("YURA_ENROLL_CLIPS", "10"))
# The Settings window lives in another process and can only watch the
# filesystem, so this marker exists while an enrollment is running.
ENROLL_MARKER = os.path.join(VERIFIER_DIR, ".enrolling")
# Every wake archives its preceding audio for retraining, ring-capped.
WAKE_DUMP_DIR = os.path.join(DATA_DIR, "wake-debug")
WAKE_DUMP_KEEP = 100


def dump_wake_audio(frames, score: float) -> None:
    try:
        os.makedirs(WAKE_DUMP_DIR, exist_ok=True)
        name = time.strftime("%Y%m%d-%H%M%S") + f"-{score:.2f}.wav"
        with wave.open(os.path.join(WAKE_DUMP_DIR, name), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(np.concatenate(list(frames)).tobytes())
        for old in sorted(os.listdir(WAKE_DUMP_DIR))[:-WAKE_DUMP_KEEP]:
            os.remove(os.path.join(WAKE_DUMP_DIR, old))
    except Exception as e:
        log("dump", str(e))


class WakeDetector:
    """openWakeWord plus the per-user verifier, rebuilt after an enrollment."""

    def __init__(self):
        self.build()

    def build(self) -> None:
        from openwakeword.model import Model as WakeModel

        verifier_kw = {}
        if os.path.exists(WAKE_VERIFIER):
            # openWakeWord keys the verifier by the model name (a path's
            # basename stem), not the wakeword path we loaded it from.
            model_key = os.path.splitext(os.path.basename(WAKEWORD))[0]
            verifier_kw = {
                "custom_verifier_models": {model_key: WAKE_VERIFIER},
                "custom_verifier_threshold": WAKE_VERIFIER_THRESHOLD,
            }
            log("verifier", f"speaker verifier on ({WAKE_VERIFIER})")
        try:
            self.model = WakeModel(wakeword_models=[WAKEWORD],
                                   inference_framework="onnx", **verifier_kw)
        except Exception:
            # First run on a fresh machine: fetch the bundled models.
            import openwakeword.utils
            openwakeword.utils.download_models()
            self.model = WakeModel(wakeword_models=[WAKEWORD],
                                   inference_framework="onnx", **verifier_kw)
        self.name = list(self.model.models.keys())[0]

    def predict(self, frame: np.ndarray) -> float:
        return self.model.predict(frame)[self.name]

    def reset(self) -> None:
        self.model.reset()
