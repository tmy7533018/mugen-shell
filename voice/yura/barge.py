"""Interrupting a spoken reply by talking over it.

The mic is already clean during playback — PipeWire's echo-cancel module owns
that, and yurad records from its output — so this only has to decide when the
sound arriving is the user starting to talk rather than room noise.

The frames that triggered it are kept and handed to the next capture. Stopping
alone would leave the user having to repeat themselves; the words they cut in
with are the question.
"""

import os
import queue
import threading

import numpy as np

from .const import CHUNK, SR
from .log import log
from .settings import voice_float, voice_settings
from .wake import dump_audio

# Above the capture threshold (0.35): a false trigger here costs the user the
# rest of a sentence, while a missed one just means they say it again.
BARGE_VAD_THRESHOLD = float(os.environ.get("YURA_BARGE_VAD", "0.5"))
# Speech has to hold for this long. A cough, a keyboard clack or a door is
# loud but brief, and every one of them used to be a plausible stop signal.
# The echo canceller also breaks down on loud passages, and that residual
# measured 0.24 s at its longest — under 0.3 s it read as someone talking.
BARGE_HOLD_S = float(os.environ.get("YURA_BARGE_HOLD", "0.6"))
# Audio kept from before the trigger, so the first syllables survive the
# handover to capture. Has to stay ahead of the hold, or the words that
# triggered it are already out of the buffer.
BARGE_PREROLL_S = 1.1


def enabled() -> bool:
    return bool(voice_settings().get("bargeIn", False))


class BargeMonitor:
    """Watches the mic while Yura speaks; `triggered` once the user cuts in."""

    def __init__(self, capture, vad):
        self._capture = capture
        self._vad = vad
        self._thread: threading.Thread | None = None
        self._stop = threading.Event()
        self.triggered = False
        self.frames: list[np.ndarray] = []

    def start(self) -> None:
        if self._thread is not None:
            return
        self.triggered = False
        self.frames = []
        self._stop.clear()
        self._vad.reset()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self) -> list[np.ndarray] | None:
        """Ends the watch; returns the audio to seed capture with, if any."""
        if self._thread is None:
            return None
        self._stop.set()
        self._thread.join(timeout=1.0)
        self._thread = None
        return self.frames if self.triggered else None

    def _run(self) -> None:
        frame_s = CHUNK / SR
        preroll: list[np.ndarray] = []
        max_preroll = int(BARGE_PREROLL_S / frame_s)
        speech_run = 0.0
        threshold = voice_float("bargeVad", BARGE_VAD_THRESHOLD, 0.1, 0.95)
        hold = voice_float("bargeHold", BARGE_HOLD_S, 0.1, 2.0)

        while not self._stop.is_set():
            try:
                frame = self._capture.queue.get(timeout=0.1)
            except queue.Empty:
                continue
            preroll.append(frame)
            if len(preroll) > max_preroll:
                preroll.pop(0)
            if self._vad.prob(frame) >= threshold:
                speech_run += frame_s
            else:
                speech_run = 0.0
            if speech_run >= hold:
                self.frames = preroll[:]
                self.triggered = True
                log("barge", f"interrupted after {speech_run:.2f}s of speech")
                # False triggers are only arguable with the audio in hand, and
                # a bad one is invisible otherwise — the reply just stops.
                dump_audio(self.frames, "barge")
                return


class NullMonitor:
    """Stands in when barge-in is off, so the turn code has no branch."""

    triggered = False

    def start(self) -> None:
        pass

    def stop(self) -> list[np.ndarray] | None:
        return None
