import io
import os
import queue
import threading
import time
import wave
from typing import Callable

import numpy as np
import sounddevice as sd

from .const import CHUNK, SR
from .log import log

PREROLL_S = 0.4                   # audio kept from before speech onset
SILENCE_END_S = 0.9               # this much trailing silence ends a turn
MAX_UTTERANCE_S = 15.0
LISTEN_TIMEOUT_S = 6.0            # wake with no speech -> give up
FOLLOWUP_TIMEOUT_S = 4.0          # post-reply window before returning to idle
VAD_THRESHOLD = 0.35              # silero speech probability
PTT_TAP_S = 0.3                   # shorter hold than this = tap, not push-to-talk


SILERO_VAD = os.environ.get("YURA_SILERO_VAD", "")


def silero_path() -> str:
    """Where to load silero_vad.onnx from.

    Endpointing needs it even with the wake word off, so taking it from inside
    openWakeWord would pin that dependency forever. A manual install has no
    standalone copy, so fall back to the one openWakeWord downloads.
    """
    if SILERO_VAD:
        return SILERO_VAD
    import openwakeword
    return os.path.join(os.path.dirname(openwakeword.__file__),
                        "resources", "models", "silero_vad.onnx")


class SileroVAD:
    """Thin wrapper over silero_vad.onnx, the model openWakeWord also ships."""

    def __init__(self):
        import onnxruntime as ort
        path = silero_path()
        opts = ort.SessionOptions()
        opts.inter_op_num_threads = 1
        opts.intra_op_num_threads = 1
        self.session = ort.InferenceSession(
            path, sess_options=opts, providers=["CPUExecutionProvider"])
        self.reset()

    def reset(self) -> None:
        self._h = np.zeros((2, 1, 64), dtype=np.float32)
        self._c = np.zeros((2, 1, 64), dtype=np.float32)

    def prob(self, frame_i16: np.ndarray) -> float:
        audio = (frame_i16.astype(np.float32) / 32768.0)[None, :]
        out, self._h, self._c = self.session.run(
            None, {"input": audio, "h": self._h, "c": self._c,
                   "sr": np.array(SR, dtype=np.int64)})
        return float(out[0][-1])


def frames_to_wav(frames: list[np.ndarray]) -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(np.concatenate(frames).tobytes())
    return buf.getvalue()


class Capture:
    """Owns the mic stream and turns it into endpointed utterances."""

    def __init__(self, running: Callable[[], bool], cancel: threading.Event):
        self.queue: queue.Queue[np.ndarray] = queue.Queue(maxsize=64)
        self._vad: SileroVAD | None = None
        self._vad_lock = threading.Lock()
        self._running = running
        self._cancel = cancel

    @property
    def vad(self) -> SileroVAD:
        with self._vad_lock:
            if self._vad is None:
                self._vad = SileroVAD()
            return self._vad

    def prewarm(self) -> None:
        """Start building the VAD now: it costs ~320 ms and ~90 MB of RSS.

        Idling without the wake word never touches it, which is most of why
        that mode is cheap. The queue holds 5 s, so a turn that starts before
        the session is ready waits for it without losing a frame.
        """
        threading.Thread(target=lambda: self.vad, daemon=True).start()

    def stream(self) -> sd.InputStream:
        return sd.InputStream(samplerate=SR, channels=1, dtype="int16",
                              blocksize=CHUNK, callback=self._on_audio)

    def _on_audio(self, indata, frames, t, status):
        if status:
            log("audio", str(status))
        try:
            self.queue.put_nowait(indata[:, 0].copy())
        except queue.Full:
            pass  # better to drop mic frames than to stall the stream

    def drain(self) -> None:
        while not self.queue.empty():
            try:
                self.queue.get_nowait()
            except queue.Empty:
                break

    def utterance(self, timeout: float = LISTEN_TIMEOUT_S,
                  held: Callable[[], bool] | None = None) -> list[np.ndarray] | None:
        """Collect frames until trailing silence. None = no speech at all.

        `held` reports whether the push-to-talk key is still down: while it is,
        every frame is kept and the release ends the utterance.
        """
        self.vad.reset()
        frames: list[np.ndarray] = []
        preroll: list[np.ndarray] = []
        speech_started = False
        silence_run = 0.0
        started = time.time()
        frame_s = CHUNK / SR
        # The confirmation beep rides the first frames of capture and a pure
        # tone can cross the VAD threshold, so hold onset detection until it
        # has passed (frames still preroll).
        beep_guard = int(0.25 / frame_s)
        seen = 0
        hold_started = started if (held is not None and held()) else None
        heard_speech = False

        while self._running():
            if self._cancel.is_set():
                log("listen", "cancelled")
                return None
            frame = self.queue.get()
            p = self.vad.prob(frame)
            seen += 1
            if hold_started is not None:
                preroll.append(frame)
                if len(preroll) > int(PREROLL_S / frame_s):
                    preroll.pop(0)
                if held():
                    heard_speech = heard_speech or p >= VAD_THRESHOLD
                    if not speech_started:
                        speech_started = True
                        frames = preroll[:]
                    else:
                        frames.append(frame)
                    if time.time() - started > MAX_UTTERANCE_S:
                        break
                    continue
                if time.time() - hold_started >= PTT_TAP_S:
                    if not heard_speech:
                        log("listen", "ptt release, no speech")
                        return None
                    log("listen", "ptt release")
                    break
                log("listen", "ptt tap, falling back to vad")
                hold_started = None
                speech_started = False
                frames = []
                started = time.time()
                seen = 0
                continue
            if not speech_started:
                preroll.append(frame)
                if len(preroll) > int(PREROLL_S / frame_s):
                    preroll.pop(0)
                if p >= VAD_THRESHOLD and seen > beep_guard:
                    speech_started = True
                    frames = preroll[:]
                elif time.time() - started > timeout:
                    return None
                continue
            frames.append(frame)
            silence_run = 0.0 if p >= VAD_THRESHOLD else silence_run + frame_s
            if silence_run >= SILENCE_END_S:
                break
            if time.time() - started > MAX_UTTERANCE_S:
                break
        return frames
