import glob
import os
import random
import threading
import time
from typing import Callable

import requests

from .audio import Capture, frames_to_wav
from .const import SR
from .log import log
from .messages import msg
from .shell import set_listening
from .sound import beep
from .tts import speak_guarded
from .tts.voicevox_api import AIVIS_URL, VOICEVOX_URL
from .wake import (
    ENROLL_CLIPS,
    ENROLL_MARKER,
    VERIFIER_DIR,
    WAKE_VERIFIER,
    WAKEWORD,
)


def _synth_negatives(neg_dir: str, want: int = 15) -> None:
    """Other voices saying the phrase are ideal verifier negatives, and
    the local TTS engines can produce as many as needed on demand."""
    have = len([f for f in os.listdir(neg_dir) if f.endswith(".wav")])
    if have >= want:
        return
    styles: list[int] = []
    base = ""
    for url in (AIVIS_URL, VOICEVOX_URL):
        try:
            r = requests.get(f"{url}/speakers", timeout=3)
            styles = [st["id"] for sp in r.json() for st in sp["styles"]]
            base = url
            break
        except requests.RequestException:
            continue
    if not base:
        log("enroll", "no TTS engine up; using existing negatives only")
        return
    random.Random(0).shuffle(styles)
    texts = ["ヘイユラ", "ヘイ、ユラ"]
    made = 0
    for sid in styles:
        if have + made >= want:
            break
        try:
            q = requests.post(f"{base}/audio_query",
                              params={"text": texts[made % len(texts)],
                                      "speaker": sid}, timeout=10).json()
            q["outputSamplingRate"] = SR
            q["outputStereo"] = False
            r = requests.post(f"{base}/synthesis", params={"speaker": sid},
                              json=q, timeout=30)
            r.raise_for_status()
            with open(os.path.join(neg_dir, f"synth_{sid}.wav"), "wb") as f:
                f.write(r.content)
            made += 1
        except requests.RequestException as e:
            log("enroll", f"negative synth {sid}: {e}")
    log("enroll", f"negatives ready: {have}+{made}")


def run_enrollment(capture: Capture, cancel: threading.Event,
                   running: Callable[[], bool], rebuild: Callable[[], None]) -> None:
    """Voice registration, guided by Yura's own voice.

    The cancel flag is cleared when the request arrives (see main), not
    here: the loop can dequeue this minutes later.
    """
    pos_dir = os.path.join(VERIFIER_DIR, "positive")
    neg_dir = os.path.join(VERIFIER_DIR, "negative")
    os.makedirs(pos_dir, exist_ok=True)
    os.makedirs(neg_dir, exist_ok=True)
    # Tells the Settings window an enrollment is live; the finally clears
    # it on every exit path so the UI releases right after an abort.
    try:
        open(ENROLL_MARKER, "w").close()
    except OSError:
        pass
    log("enroll", f"starting ({ENROLL_CLIPS} clips)")
    try:
        speak_guarded(msg("enroll_start", n=ENROLL_CLIPS),
                      should_stop=cancel.is_set)
        got = 0
        misses = 0
        stamp = time.strftime("%Y%m%d-%H%M%S")
        while got < ENROLL_CLIPS and running():
            if cancel.is_set() or misses >= 3:
                log("enroll", "aborted")
                beep(330, 0.3)
                return
            beep(880)
            set_listening(True)
            try:
                capture.drain()
                frames = capture.utterance(timeout=8.0)
            finally:
                set_listening(False)
            if not frames or sum(f.size for f in frames) / SR < 0.4:
                misses += 1
                if not cancel.is_set():
                    speak_guarded(msg("enroll_retry"),
                                  should_stop=cancel.is_set)
                continue
            misses = 0
            got += 1
            with open(os.path.join(pos_dir, f"{stamp}_{got:02d}.wav"), "wb") as f:
                f.write(frames_to_wav(frames))
            log("enroll", f"clip {got}/{ENROLL_CLIPS}")
            if got < ENROLL_CLIPS and got % 3 == 0:
                speak_guarded(msg("enroll_more", n=ENROLL_CLIPS - got),
                              should_stop=cancel.is_set)
        if got < ENROLL_CLIPS:
            return
        _synth_negatives(neg_dir)
        log("enroll", "training verifier")
        from openwakeword.custom_verifier_model import train_custom_verifier
        # Upstream iterates these directly, so pass file lists even
        # though its docstring asks for directories.
        train_custom_verifier(
            positive_reference_clips=sorted(glob.glob(os.path.join(pos_dir, "*.wav"))),
            negative_reference_clips=sorted(glob.glob(os.path.join(neg_dir, "*.wav"))),
            output_path=WAKE_VERIFIER,
            model_name=WAKEWORD,
            inference_framework="onnx")
        rebuild()
        log("enroll", f"done, verifier at {WAKE_VERIFIER}")
        speak_guarded(msg("enroll_done"))
    except Exception as e:
        log("enroll", f"failed: {e}")
        try:
            speak_guarded(msg("enroll_fail"))
        except Exception:
            pass
    finally:
        try:
            os.remove(ENROLL_MARKER)
        except OSError:
            pass
