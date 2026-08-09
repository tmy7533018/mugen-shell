import os
import subprocess
import threading
import time

import numpy as np
import sounddevice as sd

from .const import DATA_DIR
from .settings import voice_settings

# Shared with the shell's notification sounds; the Settings voice pickers list files from here.
SOUNDS_DIR = os.path.join(DATA_DIR, "sounds")


def beep(freq: float, dur: float = 0.12, vol: float = 0.2) -> None:
    t = np.linspace(0, dur, int(48000 * dur), dtype=np.float32)
    tone = (vol * np.sin(2 * np.pi * freq * t) * np.hanning(t.size)).astype(np.float32)
    try:
        sd.play(tone, 48000)
    except Exception:
        pass


def cue(kind: str, freq: float, dur: float = 0.12) -> None:
    """User-picked cue sound for this event, falling back to the beep.

    paplay handles the formats the picker lists (ogg/mp3/...) that the
    sounddevice path can't; a fire-and-forget subprocess keeps the turn
    loop from blocking on playback.
    """
    name = str(voice_settings().get(kind, "") or "")
    if name == "none":
        return
    if name:
        # basename: a hand-edited settings.json must not escape SOUNDS_DIR
        path = os.path.join(SOUNDS_DIR, os.path.basename(name))
        if os.path.isfile(path):
            try:
                proc = subprocess.Popen(
                    ["paplay", path],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception:
                beep(freq, dur)
                return
            # paplay exits fast and non-zero when it can't decode, so fall back to the beep only on that.
            def _guard() -> None:
                t0 = time.monotonic()
                rc = proc.wait()
                if rc != 0 and time.monotonic() - t0 < 0.5:
                    beep(freq, dur)
            threading.Thread(target=_guard, daemon=True).start()
            return
    beep(freq, dur)
